package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"

	zmq "github.com/pebbe/zmq4"

	pb "../pb"
)

var sub_managers = []string{"gradesta-notifications-manager", "gradesta-client-manager"}

var (
	pending_changes_for_service *pb.ServiceState
	pending_changes_for_clients *pb.ClientState
	state                       *pb.ClientState
)

func main() {
	// Initialize directories
	for _, dir := range directories {
		if err := os.Mkdir(dir, os.ModePerm); os.IsNotExist(err) {
			log.Fatal(err)
		}
	}
	initialize_sockets()
	// Launch submanagers
	for _, sub_manager := range sub_managers {
		process := exec.Command(sub_manager)
		e := process.Start()
		if e != nil {
			log.Fatalf("Error initializing %s\n\n%s", sub_manager, e)
		}
	}
	// Send protocol defaults to service
	state := &default_state
	ss := state.ServiceState
	send_to_service(ss)
	merge_new_state_from_service(recv_from_service(), ss)
	//////////////////////////////////////////////////////////
	// Getting the cells seen by the default index selection//
	//////////////////////////////////////////////////////////
	{
		state.Selections = map[string]*pb.Selection{}
		state.Selections["index"] = get_default_selection(ss.Index)
		update_view()
	}
	for _, cr := range state.ServiceState.Cells {
		//fmt.Println(cell_id)
		fmt.Println(string(cr.Cell.Data))
	}
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
			sockets, _ := poller.Poll(-1)
			for _, socket := range sockets {
				switch s := socket.Socket; s {
				case ms: // from service
					m := recv_from_service()
					pending_changes_for_clients = &pb.ClientState{
						ServiceState: m,
					}
					merge_new_state_from_service(m, state.ServiceState)
					update_view()
					send_pending_changes_to_clients()
				case cs: // from clients
					m := recv_from_clients()
					conflicts := check_for_conflicts(m)
					if conflicts != nil {
						send_to_clients(conflicts)
					} else {
						if m.ServiceState != nil {
							pending_changes_for_service = m.ServiceState
						}
						merge_from_clients(m, state)
						update_view()
						if are_pending_changes_for_service() {
							send_pending_changes_to_service()
						} else if are_pending_changes_for_clients() {
							send_pending_changes_to_clients()
						}
					}
				}
			}
		}
	}
}
