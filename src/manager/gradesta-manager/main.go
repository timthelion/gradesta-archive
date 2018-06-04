package main

import (
	"log"
	"os"
	"os/exec"
	"time"

	zmq "github.com/pebbe/zmq4"

	pb "../pb"
)

var sub_managers = []string{"gradesta-notifications-manager", "gradesta-client-manager"}

var (
	pending_changes_for_service = &pb.ServiceState{}
	pending_changes_for_clients = &pb.ClientState{}
	state                       *pb.ClientState
)

func main() {
	log.SetPrefix("gradesta-manager ")
	defer log.Println("Sutting down. Bye!")
	// Initialize directories
	for _, dir := range directories {
		if err := os.Mkdir(dir, os.ModePerm); os.IsNotExist(err) {
			log.Fatal(err)
		}
	}
	log.Println("Initializing sockets.")
	initialize_sockets()
	// Launch submanagers
	log.Println("Launching sububmanagers.")
	for _, sub_manager := range sub_managers {
		process := exec.Command(sub_manager)
		process.Stdout = os.Stdout
		process.Stderr = os.Stderr
		e := process.Start()
		if e != nil {
			log.Fatalf("Error initializing %s\n\n%s", sub_manager, e)
		}
		log.Println(sub_manager, "launched.")
		defer process.Process.Kill()
	}
	// Send protocol defaults to service
	log.Println("Sending protocol defaults")
	state = &default_state
	ss := state.ServiceState
	send_to_service(ss)
	merge_service_state_changes(recv_from_service(), ss)
	log.Println("Revceived protocol defaults")
	//////////////////////////////////////////////////////////
	// Listen loop                                          //
	//////////////////////////////////////////////////////////
	{
		poller := zmq.NewPoller()
		ms := sockets[manager_sock]
		cs := sockets[clients_sock]
		poller.Add(ms, zmq.POLLIN)
		poller.Add(cs, zmq.POLLIN)
		for {
			sockets, _ := poller.Poll(2000 * time.Millisecond)
			if len(sockets) == 0 {
				log.Println("Polling.")
				send_to_clients(state)
			}
			for _, socket := range sockets {
				switch s := socket.Socket; s {
				case ms: // from service
					log.Println("Revceived message from service")
					m := recv_from_service()
					merge_new_state_from_service(m)
					update_view()
					log.Println("Pending changes for clients are: ", pending_changes_for_clients)
					send_pending_changes_to_clients()
				case cs: // from clients
					log.Println("Revceived message from client")
					m := recv_from_clients()
					log.Println("Checking for merge conflicts")
					conflicts := check_for_conflicts(m)
					if conflicts != nil {
						send_to_clients(conflicts)
					} else {
						if m.ServiceState != nil {
							pending_changes_for_service = m.ServiceState
							if m.ServiceState.Round != nil && m.ServiceState.Round.FullSync != nil && *m.ServiceState.Round.FullSync {
								stage_full_sync()
							}
						}
						merge_from_clients(m, state)
						log.Println("Updating view")
						update_view()
						log.Println("Pending changes for clients are: ", pending_changes_for_clients)
						if are_pending_changes_for_service() {
							send_pending_changes_to_service()
						} else if are_pending_changes_for_clients() {
							log.Println("Sending result to clients")
							send_pending_changes_to_clients()
							log.Println("Sent")
						}
					}
				}
			}
		}
	}
}
