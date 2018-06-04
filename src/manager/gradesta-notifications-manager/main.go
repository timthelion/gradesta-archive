package main

import (
	"fmt"
	"log"
	"os"
	//	"time"

	"github.com/golang/protobuf/proto"
	zmq "github.com/pebbe/zmq4"

	pb "../pb"
)

var (
	client_socks            = map[string]*zmq.Socket{}
	notifications_sock_path = "ipc://manager/notifications.gradesock"
	new_clients_sock_path   = "ipc://manager/new_clients.gradesock"
)

func main() {
	log.SetPrefix("gradesta-notifications-manager ")
	log.Println("Launching notification manager.")
	defer log.Println("Goodbye!")
	notifications_sock, _ := zmq.NewSocket(zmq.PAIR)
	if err := notifications_sock.Connect(notifications_sock_path); err != nil {
		log.Fatalf("Error connecting to %s. %s", notifications_sock_path, err)
	}
	defer notifications_sock.Close()
	new_clients_sock, _ := zmq.NewSocket(zmq.PAIR)
	new_clients_sock.Connect(new_clients_sock_path)
	defer new_clients_sock.Close()
	poller := zmq.NewPoller()
	poller.Add(notifications_sock, zmq.POLLIN)
	poller.Add(new_clients_sock, zmq.POLLIN)
	for {
		var (
			frame []byte
			err   error
		)
		log.Println("Polling for new notifications.")
		sockets, err := poller.Poll(-1)
		if err != nil {
			log.Println("Polling error: ", err)
			continue
		}
		if len(sockets) == 0 {
			log.Println("No new messages.")
		}
		for _, socket := range sockets {
			switch s := socket.Socket; s {
			case new_clients_sock:
				log.Println("Reading new-client notification.")
				frame, err = new_clients_sock.RecvBytes(0)
				log.Println("New client notification received.")
				if err != nil {
					log.Fatalf("Error reading notification", err)
				}
				notification := new(pb.ClientState)
				if err := proto.Unmarshal(frame, notification); err != nil {
					log.Fatalf("Error unmarshaling notification", err)
				}
				log.Println("Notification parsed.", notification)
				// Initialize new clients
				for client_id, client := range notification.Clients {
					client_sock, exists := client_socks[client_id]
					if !exists && *client.Status == pb.Client_INITIALIZING {
						client_sock, _ = zmq.NewSocket(zmq.PAIR)
						client_socks[client_id] = client_sock
						socket_path := fmt.Sprintf("ipc://clients%c%s%cclient.gradesock", os.PathSeparator, client_id, os.PathSeparator)
						log.Printf("Connecting to new client %s on socket %s.\n", client_id, socket_path)
						client_sock.Connect(socket_path)
						log.Println("Sending intro frame.")
						client_sock.SendBytes(frame, 0)
						log.Println("Sent intro frame.")
					} else if !exists {
						log.Fatalf("Refered to non-existant client in clients map %s. \n%s", client_id, client)
					}
				}

			case notifications_sock:
				log.Println("Reading notification from manager.")
				frame, err = notifications_sock.RecvBytes(0)
				log.Println("Notification received from manager.")
				if err != nil {
					log.Fatalf("Error reading notification", err)
				}
				notification := new(pb.ClientState)
				if err := proto.Unmarshal(frame, notification); err != nil {
					log.Fatalf("Error unmarshaling notification", err)
				}
				// send to existing clients
				log.Println("Sending notification to clients.")
				for _, client_sock := range client_socks {
					// customized_notification TODO
					log.Println("Sending notification to client.", client_sock)
					client_sock.SendBytes(frame, 0)
				}

			}
		}
	}
}
