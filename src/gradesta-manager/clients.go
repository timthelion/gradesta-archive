package main

import (
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/fsnotify/fsnotify"
	"github.com/golang/protobuf/proto"
	zmq "github.com/pebbe/zmq4"

	pb "./pb"
)

func listen_for_clients() {
	log.Println("Listening for client connections.")
	clients_socket, err := zmq.NewSocket(zmq.PAIR)
	if err != nil {
		log.Fatal(err)
	}
	if err = clients_socket.Connect("inproc://clients.gradesock"); err != nil {
		log.Fatal(err)
	}

	clients_socket_chan := make(chan []byte)
	go func() {
		for {
			frame := <-clients_socket_chan
			clients_socket.SendBytes(frame, 0)
		}
	}()

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
					log.Println(ev.Name)
					if len(path_components) == 2 {
						watcher.Add(ev.Name)
					} else if len(path_components) == 3 {
						log.Println("Seems like we have a new client.")
						if path_components[2] == "client.gradesock" {
							go func() {
								log.Println("Connecting to ", ev.Name)
								client_socket, _ := zmq.NewSocket(zmq.PAIR)
								client_socket.Connect(fmt.Sprintf("ipc://%s", ev.Name))
								client_socks[path_components[1]] = client_socket
								defer client_socket.Close()
								intro_msg := pb.ClientState{
									Clients: map[string]*pb.Client{
										path_components[1]: &pb.Client{
											Status: pb.Client_INITIALIZING.Enum(),
										},
									},
									ServiceState: &pb.ServiceState{
										Round: &pb.Round{
											FullSync: &truev,
										},
									},
								}
								frame, _ := proto.Marshal(&intro_msg)
								clients_socket_chan <- frame
								log.Println("Intro frame sent.")
								for {
									frame, err := client_socket.RecvBytes(0)
									if err != nil {
										log.Println("Error reading frame from client ", ev.Name, err)
										return
									}
									log.Println("Forwarding message from client.")
									clients_socket_chan <- frame
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
}
