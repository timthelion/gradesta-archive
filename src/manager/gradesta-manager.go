package main

import (
	//"fmt"
	"log"
	"math"
	"os"
	"os/exec"

	pb "./pb"
	deque "github.com/gammazero/deque"
	"github.com/golang/protobuf/proto"
	zmq "github.com/pebbe/zmq4"
)

var directories = []string{"manager", "clients"}

var service_sock = "ipc://service.gradesock"
var manager_sock = "ipc://manager.gradesock"
var clients_sock = "ipc://manager/clients.gradesock"
var notifications_sock = "ipc://manager/notifications.gradesock"

var socket_types = map[string]zmq.Type{
	service_sock:       zmq.PUSH,
	manager_sock:       zmq.PULL,
	clients_sock:       zmq.PULL,
	notifications_sock: zmq.PUSH,
}

var sockets = map[string]*zmq.Socket{}

var sub_managers = []string{"gradesta-notifications-manager", "gradesta-client-manager"}

func send_to_service(ss *pb.ServiceState) {
	frame, err := proto.Marshal(ss)
	if err != nil {
		log.Fatalf("Error marshaling service state", err)
	}
	sockets[service_sock].SendBytes(frame, 0)
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
	return nss
}

func merge_modes32(nm map[uint32]pb.Mode, om map[uint32]pb.Mode) {
	for k, v := range nm {
		om[k] = v
	}
}

func merge_modes64(nm map[uint64]pb.Mode, om map[uint64]pb.Mode) {
	for k, v := range nm {
		om[k] = v
	}
}

func merge_links(nl map[uint64]*pb.Links, ol map[uint64]*pb.Links) {
	for k, v := range nl {
		ol[k] = v
	}
}

func merge_cells(nc *pb.Cell, oc *pb.Cell) {
	if nc.Data != nil {
		oc.Data = nc.Data
	}
	if nc.Encoding != nil {
		oc.Encoding = nc.Encoding
	}
	if nc.Mime != nil {
		oc.Mime = nc.Mime
	}
	merge_links(nc.Forth, oc.Forth)
	merge_links(nc.Back, oc.Back)
	for k, v := range nc.Tags {
		if v {
			oc.Tags[k] = true
		} else {
			delete(oc.Tags, k)
		}
	}
	for k, v := range nc.Coords {
		if math.IsNaN(v) {
			delete(oc.Coords, k)
		} else {
			oc.Coords[k] = v
		}
	}
}

func merge_cell_runtimes(ncr *pb.CellRuntime, ocr *pb.CellRuntime) {
	merge_cells(ncr.Cell, ocr.Cell)
	if ncr.EditCount != nil {
		ocr.EditCount = ncr.EditCount
	}
	if ncr.ClickCount != nil {
		ocr.ClickCount = ncr.ClickCount
	}
	if ncr.Deleted != nil {
		ocr.Deleted = ncr.Deleted
	}
	merge_modes32(ncr.CellRuntimeModes, ocr.CellRuntimeModes)
	merge_modes32(ncr.CellModes, ocr.CellModes)
	merge_modes64(ncr.ForLinkModes, ocr.ForLinkModes)
	merge_modes64(ncr.BackLinkModes, ocr.BackLinkModes)
	ocr.SupportedEncodings = append(ocr.SupportedEncodings, ncr.SupportedEncodings...)
}

func merge_new_state_from_service(nss *pb.ServiceState, ss *pb.ServiceState) {
	if nss.Index != nil {
		ss.Index = nss.Index
	}
	if nss.OnDiskState != nil {
		ss.OnDiskState = nss.OnDiskState
	}
	for time, msg := range nss.Log {
		ss.Log[time] = msg
	}
	if nss.Metadata != nil {
		ss.Metadata = nss.Metadata
	}
	if nss.CellTemplate != nil {
		if ss.CellTemplate != nil {
			merge_cell_runtimes(nss.CellTemplate, ss.CellTemplate)
		} else {
			ss.CellTemplate = nss.CellTemplate
		}
	}
	for field, mode := range nss.ServiceStateModes {
		ss.ServiceStateModes[field] = mode
	}
	for cell_id, cell_runtime := range nss.Cells {
		merge_cell_runtimes(cell_runtime, ss.Cells[cell_id])
	}
}

var (
	index = "index"
	one   = 1
)

type placedNonTerminal struct {
	cell_id string
	uint32  symbol
}

func evaluate_loses(state *pb.ClientState) map[string]bool {
	needed := map[string]bool{}
	for _, selection := range state.Selections {
		for _, cursor := range selection {
			los := cursor.Los
			if state[cursor.Cell] {
				var ents deque.Deque // exposed non-terminals
				ents.PushBack(placedNonTerminal{cursor.Cell, 0})
				for ents.Len() > 0 {
					nt := ents.PopFront()
					cell_runtime := state.Cells[nt.cell_id]
					for _, symbol_index := range los.ProductionRules[nt.symbol].Symbols {
						symbol := los.Symbols[symbol_index]
						var direction map[uint64]pb.Links
						if symbol.Direction {
							direction = cell_runtime.Cell.Forth
						} else {
							direction = cell_runtime.Cell.Back
						}
						links, ok := direction[symbol.Dimension]
						if ok {
							for _, link := range links {
								if link.Mime == "." && link.Path == "." {
									_, have_cell := state.Cells[link.CellId]
									if have_cell {
										ents.PushBack(placedNonTerminal{})
									} else {
										needed[link.CellId] = true
									}
								}
							}
						}
					}
				}
			} else {
				needed[cursor.cell] = true
			}
		}
	}
	return needed
}

func update_view(state *pb.ClientState) {
	for {
		newly_in_view := evaluate_loses(state)
		if len(newly_in_view) == 0 {
			return
		}
		new_view := state.ServiceState{in_view: newly_in_view}
		send_to_service(new_view)
	}
}

func main() {
	// Initialize directories
	for _, dir := range directories {
		if err := os.Mkdir(dir, os.ModePerm); os.IsNotExist(err) {
			log.Fatal(err)
		}
	}
	// Initialize sockets
	for socket_path, socket_type := range socket_types {
		socket, _ := zmq.NewSocket(socket_type)
		err := socket.Connect(socket_path)
		if err != nil {
			log.Fatalf("Error initializing socket %s\n%s", socket_path, err)
		}
		defer socket.Close()
		sockets[socket_path] = socket
	}
	// Launch submanagers
	for _, sub_manager := range sub_managers {
		process := exec.Command(sub_manager)
		process.Start()
	}
	// Send protocol defaults to service
	state := &pb.ClientState{
		ServiceState: &pb.ServiceState{
			OnDiskState: pb.ServiceState_READ_ONLY.Enum(),
			ServiceStateModes: map[uint32]pb.Mode{
				1: pb.Mode_READ_WRITE,
				2: pb.Mode_READ_WRITE,
				3: pb.Mode_READ_ONLY,
				4: pb.Mode_READ_WRITE,
				5: pb.Mode_READ_WRITE,
				6: pb.Mode_READ_ONLY,
				7: pb.Mode_READ_ONLY,
				8: pb.Mode_READ_ONLY,
			},
			CurrentRound: &pb.Round{Request: &one},
		},
	}
	ss := state.ServiceState
	send_to_service(ss)
	merge_new_state_from_service(recv_from_service(), ss)
	//////////////////////////////////////////////////////////
	// Getting the cells seen by the default index selection//
	//////////////////////////////////////////////////////////
	{
		// https://stackoverflow.com/questions/30716354/how-do-i-do-a-literal-int64-in-go#30716481
		state.Selections["index"] = &pb.Selection{ // of course, struct literals can be addressed, because golang doesn't just suck, it's inconsistent as well.
			Name:        &index, // golang sucks
			UpdateCount: &one,   // golang sucks
			Clients: map[string]pb.Selection_Status{
				"manager": pb.Selection_PRIMARY,
			},
			Cursors: []pb.Cursor{&pb.Cursor{ // Golang also sucks, because arrays and struct literalls basically look the same. So confusing.
				Name: &index, // golang sucks
				Cell: ss.Index,
				Los: &pb.LineOfSight{
					Vars: []uint64{1000, 0},
					States: []pb.LOSState{
						&pb.LOSState{
							Forth: map[uint64]*pb.Condition{
								Requirements: []pb.Condition_Requirement{
									pb.Condition_UNIQUE,
								},
								Var:       0,
								ContTrue:  0,
								ContFalse: -1,
							},
						},
					},
				},
			},
			},
		}
		update_view(state)
	}
}
