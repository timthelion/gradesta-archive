package main

import (
	"log"
	//"fmt"

	"github.com/golang/protobuf/proto"
	zmq "github.com/pebbe/zmq4"

	pb "./pb"
)

var clients_sock_path = "inproc://clients.gradesock"
var clients_sock *zmq.Socket

var service_sock_path = "ipc://service.gradesock"
var service_sock *zmq.Socket

var directories = []string{"clients"}

var client_socks = map[string]*zmq.Socket{}

func initialize_sockets() {
	var err error
	if service_sock, err = zmq.NewSocket(zmq.PAIR); err != nil {
		log.Fatalf("failed to create socket %s", err.Error())
	}
	if err = service_sock.Connect(service_sock_path); err != nil {
		log.Fatalf("Failed to connect to socket %s %s", service_sock_path, err.Error())
	}
	if clients_sock, err = zmq.NewSocket(zmq.PAIR); err != nil {
		log.Fatalf("failed to create socket %s", err.Error())
	}
	if err = clients_sock.Bind(clients_sock_path); err != nil {
		log.Fatalf("Failed to connect to socket %s %s", clients_sock_path, err.Error())
	}
}

func send_pending_changes_to_service() {
	if are_pending_changes_for_service() {
		send_to_service(pending_changes_for_service)
	}
	pending_changes_for_service = &pb.ServiceState{}
}

func send_to_service(ss *pb.ServiceState) {
	frame, err := proto.Marshal(ss)
	if err != nil {
		log.Fatalf("Error marshaling service state %s", err)
	}
	service_sock.SendBytes(frame, 0)
}

func recv_from_service() *pb.ServiceState {
	frame, err := service_sock.RecvBytes(0)
	if err != nil {
		log.Fatalf("Error reading message from service", err)
	}
	nss := new(pb.ServiceState)
	if err := proto.Unmarshal(frame, nss); err != nil {
		log.Fatalf("Error unmarshaling message from service %s", err)
	}
	return nss
}

func send_pending_changes_to_clients() {
	if are_pending_changes_for_clients() {
		log.Println("Sending pending changes to clients")
		send_to_clients(pending_changes_for_clients)
	}
	pending_changes_for_clients = &pb.ClientState{}
}

func send_to_clients(cs *pb.ClientState) {
	frame, err := proto.Marshal(cs)
	if err != nil {
		log.Fatalf("Error marshaling notification %s", err)
	}
	log.Println("Starting sendbytes to clients")
	for client_id, client_sock := range client_socks {
		// customized_notification TODO
		log.Println("Sending notification to client.", client_id)
		client_sock.SendBytes(frame, 0)
	}
}

func recv_from_clients() *pb.ClientState {
	frame, err := clients_sock.RecvBytes(0)
	if err != nil {
		log.Fatalf("Error reading message from clients %s", err)
	}
	ncs := new(pb.ClientState)
	if err := proto.Unmarshal(frame, ncs); err != nil {
		log.Fatalf("Error unmarshaling message from service %s", err)
	}
	return ncs
}
