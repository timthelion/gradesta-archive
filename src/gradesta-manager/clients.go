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

	pb "./pb"
)

func listen_for_clients() {
	clients_socket, err := zmq.NewSocket(zmq.PAIR)
	if err != nil {
		log.Fatal(err)
	}
	if err = clients_socket.Connect("inproc://clients.gradesock"); err != nil {
		log.Fatal(err)
	}

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
								client_socket.SendBytes(frame, 0)
								log.Println("Intro frame sent.")
								for {
									frame, err := client_socket.RecvBytes(0)
									if err != nil {
										log.Println("Error reading frame from client ", ev.Name, err)
										return
									}
									ncs := new(pb.ClientState)
									err = proto.Unmarshal(frame, ncs)
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
