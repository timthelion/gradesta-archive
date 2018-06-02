package main

import (
	"fmt"
	"log"
	"os"

	"github.com/golang/protobuf/proto"
	zmq "github.com/pebbe/zmq4"

	pb "../pb"
)

var (
	client_socks            = map[string]*zmq.Socket{}
	notifications_sock_path = "ipc://manager/notifications.gradesock"
)

func main() {
	notifications_sock, _ := zmq.NewSocket(zmq.PULL)
	notifications_sock.Connect(notifications_sock_path)
	defer notifications_sock.Close()
	for {
		frame, err := notifications_sock.RecvBytes(0)
		if err != nil {
			log.Fatalf("Error reading notification", err)
		}
		notification := new(pb.ClientState)
		if err := proto.Unmarshal(frame, notification); err != nil {
			log.Fatalf("Error unmarshaling notification", err)
		}
		func() {
			// Initialize new clients
			for client_id, client := range notification.Clients {
				client_sock, exists := client_socks[client_id]
				if !exists && client.Status == pb.Client_INITIALIZING.Enum() {
					client_sock, _ = zmq.NewSocket(zmq.PUSH)
					client_socks[client_id] = client_sock
					client_sock.Connect(fmt.Sprintf("clients%c%s%cclient.gradesock", os.PathSeparator, client_id, os.PathSeparator))
					client_sock.SendBytes(frame, 0)
					return
				} else if !exists {
					log.Fatalf("Refered to non-existant client in clients map.")
				}
			}
			// send to existing clients
			for _, client_sock := range client_socks {
				// customized_notification TODO
				client_sock.SendBytes(frame, 0)
			}
		}()
	}
}
