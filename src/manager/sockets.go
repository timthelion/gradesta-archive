package main

import (
	"log"
	//"fmt"

	"github.com/golang/protobuf/proto"
	zmq "github.com/pebbe/zmq4"

	pb "./pb"
)

var service_sock = "ipc://service.gradesock"
var manager_sock = "ipc://manager.gradesock"
var clients_sock = "ipc://manager/clients.gradesock"
var notifications_sock = "ipc://manager/notifications.gradesock"

var directories = []string{"manager", "clients"}

var socket_types = map[string]zmq.Type{
	service_sock:       zmq.PUSH,
	manager_sock:       zmq.PULL,
	clients_sock:       zmq.PULL,
	notifications_sock: zmq.PUSH,
}

var sockets = map[string]*zmq.Socket{}

func send_to_service(ss *pb.ServiceState) {
	frame, err := proto.Marshal(ss)
	if err != nil {
		log.Fatalf("Error marshaling service state", err)
	}
	sockets[service_sock].SendBytes(frame, 0)
	//fmt.Println("Sending")
	//fmt.Println(ss)
}

func recv_from_service() *pb.ServiceState {
	frame, err := sockets[manager_sock].RecvBytes(0)
	if err != nil {
		log.Fatalf("Error reading message from service", err)
	}
	nss := new(pb.ServiceState)
	if err := proto.Unmarshal(frame, nss); err != nil {
		log.Fatalf("Error unmarshaling message from service", err)
	}
	//fmt.Println("Recv")
	//fmt.Println()
	return nss
}

func send_to_clients(cs *pb.ClientState) {
	frame, err := proto.Marshal(cs)
	if err != nil {
		log.Fatalf("Error marshaling notification", err)
	}
	sockets[notifications_sock].SendBytes(frame, 0)
	//fmt.Println("Sending")
	//fmt.Println(ss)
}

func recv_from_clients() *pb.ClientState {
	frame, err := sockets[clients_sock].RecvBytes(0)
	if err != nil {
		log.Fatalf("Error reading message from clients", err)
	}
	ncs := new(pb.ClientState)
	if err := proto.Unmarshal(frame, ncs); err != nil {
		log.Fatalf("Error unmarshaling message from service", err)
	}
	//fmt.Println("Recv")
	//fmt.Println()
	return ncs
}
