package main

import (
	"log"
	//"fmt"

	"github.com/golang/protobuf/proto"
	zmq "github.com/pebbe/zmq4"

	pb "../pb"
)

var service_sock = "ipc://service.gradesock"
var manager_sock = "ipc://manager.gradesock"
var clients_sock = "ipc://manager/clients.gradesock"
var notifications_sock = "ipc://manager/notifications.gradesock"

var directories = []string{"manager", "clients"}

const (
	BIND    = iota
	CONNECT = iota
)

type SocketParams struct {
	stype zmq.Type
	role  uint32
	addr  string
}

var socket_params = []*SocketParams{
	&SocketParams{
		addr:  service_sock,
		stype: zmq.PUSH,
		role:  CONNECT,
	},
	&SocketParams{
		addr:  manager_sock,
		stype: zmq.PULL,
		role:  BIND,
	},
	&SocketParams{
		addr:  clients_sock,
		stype: zmq.PULL,
		role:  BIND,
	},
	&SocketParams{
		addr:  notifications_sock,
		stype: zmq.PUSH,
		role:  BIND,
	},
}

var sockets = map[string]*zmq.Socket{}

func initialize_sockets() {
	for _, socket_param := range socket_params {
		socket, _ := zmq.NewSocket(socket_param.stype)
        var err error
		if socket_param.role == CONNECT {
			err = socket.Connect(socket_param.addr)
		} else {
			err = socket.Bind(socket_param.addr)
		}
		if err != nil {
			log.Fatalf("Error initializing socket %s\n%s", socket_param.addr, err)
		}
		defer socket.Close()
		sockets[socket_param.addr] = socket
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

func send_pending_changes_to_clients() {
	if are_pending_changes_for_clients() {
		send_to_clients(pending_changes_for_clients)
	}
	pending_changes_for_clients = &pb.ClientState{}
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
