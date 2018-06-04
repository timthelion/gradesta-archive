package main

import (
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/fsnotify/fsnotify"
	"github.com/golang/protobuf/proto"
	zmq "github.com/pebbe/zmq4"

	pb "../pb"
)

var clients_sock_path = "ipc://manager/clients.gradesock"
var notifications_sock_path = "ipc://manager/new_clients.gradesock"

func main() {
	log.SetPrefix("gradetsa-client-manager ")
	log.Println("Launching client manager.")
	clients_socket, _ := zmq.NewSocket(zmq.PAIR)
	clients_socket.Connect(clients_sock_path)
	defer clients_socket.Close()

	notifications_socket, _ := zmq.NewSocket(zmq.PAIR)
	notifications_socket.Bind(notifications_sock_path)
	defer notifications_socket.Close()

	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		log.Fatal(err)
	}

	go func() {
		for {
			select {
			case ev := <-watcher.Events:
				if ev.Op == fsnotify.Create {
					path_components := strings.Split(ev.Name, string(os.PathSeparator))
					if len(path_components) == 2 {
						watcher.Add(ev.Name)
					} else if len(path_components) == 3 {
						log.Println("Seems like we have a new client.")
						if path_components[2] == "manager.gradesock" {
							go func() {
								log.Println("Connecting to ", ev.Name)
								client_socket, _ := zmq.NewSocket(zmq.PAIR)
								client_socket.Connect(fmt.Sprintf("ipc://%s", ev.Name))
								defer client_socket.Close()
								intro_msg := pb.ClientState{
									Clients: map[string]*pb.Client{
										path_components[1]: &pb.Client{
											Status: pb.Client_INITIALIZING.Enum(),
										},
									},
								}
								frame, _ := proto.Marshal(&intro_msg)
								notifications_socket.SendBytes(frame, 0)
								log.Println("Intro frame sent.")
								for {
									frame, err := client_socket.RecvBytes(0)
									if err != nil {
										log.Println("Error reading frame from client ", ev.Name, err)
										return
									}
									log.Println("Forwarding message from client.")
									clients_socket.SendBytes(frame, 0)
									log.Println("Message sent.")
								}
							}()
						}
					}
				}
				log.Println("event:", ev)
			case err := <-watcher.Errors:
				log.Println("error:", err)
			}
		}
	}()

	err = watcher.Add("clients")
	if err != nil {
		log.Fatal(err)
	}
	time.Sleep(100 * time.Second)
}
