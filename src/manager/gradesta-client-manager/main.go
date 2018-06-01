package main

import (
	"log"
	"os"
	"strings"
	"time"

	"github.com/fsnotify/fsnotify"
	zmq "github.com/pebbe/zmq4"
)

var clients_sock_path = "ipc://manager/clients.gradesock"
var notifications_sock_path = "ipc://manager/notifications.gradesock"

func main() {
	clients_socket, _ := zmq.NewSocket(zmq.PUSH)
	clients_socket.Connect(clients_sock_path)
	defer clients_socket.Close()

	notifications_socket, _ := zmq.NewSocket(zmq.PUSH)
	notifications_socket.Connect(notifications_sock_path)
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
						if path_components[2] == "manager.gradesock" {
							go func() {
								client_socket, _ := zmq.NewSocket(zmq.PULL)
								client_socket.Connect(ev.Name)
								defer client_socket.Close()
								notifications_socket.SendBytes([]byte{}, 0)
								for {
									frame, err := client_socket.RecvBytes(0)
									if err != nil {
										log.Fatalf("Error reading frame from client ", ev.Name, err)
									}
									clients_socket.SendBytes(frame, 0)
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
