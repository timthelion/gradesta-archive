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
								client_socket, _ := zmq.NewSocket(zmq.PAIR)
								client_socket_path := fmt.Sprintf("ipc://%s", ev.Name)
								client_socket.Connect(client_socket_path)
								log.Println("Connected to ", client_socket_path)
								internal_outgoing_socket, _ := zmq.NewSocket(zmq.PAIR)
								internal_outgoing_socket.Bind(fmt.Sprintf("inproc://%s", ev.Name))
								internal_outgoing_socket1, _ := zmq.NewSocket(zmq.PAIR)
								internal_outgoing_socket1.Connect(fmt.Sprintf("inproc://%s", ev.Name))
								client_id := path_components[1]
								client_socks[client_id] = internal_outgoing_socket1
								defer client_socket.Close()
								defer internal_outgoing_socket.Close()
								intro_msg := pb.ClientState{
									Clients: map[string]*pb.Client{
										client_id: &pb.Client{
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
								poller := zmq.NewPoller()
								poller.Add(client_socket, zmq.POLLIN)
								poller.Add(internal_outgoing_socket, zmq.POLLIN)
								time.Sleep(20 * time.Millisecond) //Please kill me
								for {
									log.Println("Polling interally for client messages.")
									sockets, _ := poller.Poll(-1)
									for _, socket := range sockets {
										switch s := socket.Socket; s {
										case client_socket:
											frame, err := client_socket.RecvBytes(0)
											if err != nil {
												log.Println("Error reading frame from client ", ev.Name, err)
												return
											}
											log.Println("Forwarding message from client to main loop.")
											clients_socket_chan <- frame
											log.Println("Message sent.")
										case internal_outgoing_socket:
											log.Println("Reading outgoing message for client", client_id)
											frame, err := internal_outgoing_socket.RecvBytes(0)
											if err != nil {
												log.Println("Error reading internally sent frame for client ", ev.Name, err)
												return
											}
											log.Println("ůSending notification to client", client_id)
											client_socket.SendBytes(frame, 0)
										}
									}
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
