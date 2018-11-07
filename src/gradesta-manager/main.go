package main

import (
	"flag"
	"log"
	"os"
	"time"

	zmq "github.com/pebbe/zmq4"

	pb "./pb"
)

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
	listen_for_clients()
	log_and_redirect_service_ptr := flag.String("-log-and-redirect-service", "", "Log service messages to json files and redirect sockets to the given manager.")
	log_and_redirect_clients_ptr := flag.String("-log-and-redirect-clients", "", "Log client messages to json files and redirect sockets to the given manager.")
	flag.Parse()
	if *log_and_redirect_service_ptr != "" {
		log_and_redirect_service(*log_and_redirect_service_ptr)
	} else if *log_and_redirect_clients_ptr != "" {
		log_and_redirect_clients(*log_and_redirect_clients_ptr)
	} else {
		main_loop()
	}
}

func main_loop() {
	// Send protocol defaults to service
	log.Println("Sending protocol defaults")
	state = &default_state
	ss := state.ServiceState
	send_to_service(ss)
	merge_service_state_changes(recv_from_service(), ss)
	log.Println("Received protocol defaults")
	//////////////////////////////////////////////////////////
	// Listen loop                                          //
	//////////////////////////////////////////////////////////
	{
		poller := zmq.NewPoller()
		ms := service_sock
		cs := clients_sock
		poller.Add(ms, zmq.POLLIN)
		poller.Add(cs, zmq.POLLIN)
		time.Sleep(20 * time.Millisecond) // Please kill me
		for {
			sockets, _ := poller.Poll(-1)
			if len(sockets) == 0 {
				log.Println("Polling.")
			}
			for _, socket := range sockets {
				switch s := socket.Socket; s {
				case ms: // from service
					log.Println("Received message from service")
					m := recv_from_service()
					merge_new_state_from_service(m)
					update_view()
					log.Println("Pending changes for clients are: ", pending_changes_for_clients)
					send_pending_changes_to_clients()
				case cs: // from clients
					log.Println("Received message from client (Or a self-generated client initialization message.)")
					m := recv_from_clients()
					log.Println(m)
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
						merge_from_clients(m, pending_changes_for_clients)
						merge_from_clients(m, state)
						log.Println("Updating view")
						update_view()
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
