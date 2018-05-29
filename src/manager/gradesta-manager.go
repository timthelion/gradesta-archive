package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"

	deque "github.com/gammazero/deque"
	zmq "github.com/pebbe/zmq4"

	pb "./pb"
)

var sub_managers = []string{"gradesta-notifications-manager", "gradesta-client-manager"}

// literals that can be used as &literal
// https://stackoverflow.com/questions/30716354/how-do-i-do-a-literal-int64-in-go#30716481
var (
	index             = "index"
	text_plain        = "text/plain"
	zero       uint64 = 0
	zero32     uint32 = 0
	one        uint64 = 1
	falsev            = false
	truev             = true
)

type placedNonTerminal struct {
	cell_id string
	symbol  uint32
	vars    []uint64
}

func evaluate_loses(state *pb.ClientState) map[string]bool {
	needed := map[string]bool{}
	scanned := map[string]bool{}
	for _, selection := range state.Selections {
		for _, cursor := range selection.Cursors {
			los := cursor.Los
			_, have_cell := state.ServiceState.Cells[*cursor.Cell]
			if have_cell {
				var ents deque.Deque // exposed non-terminals
				ents.PushBack(placedNonTerminal{*cursor.Cell, 0, los.Vars})
				for ents.Len() > 0 {
					nt := ents.PopFront().(placedNonTerminal)
					cell_runtime := state.ServiceState.Cells[nt.cell_id]
					for _, symbol_index := range los.ProductionRules[nt.symbol].Symbols {
						var symbol *pb.Symbol
						symbol = los.Symbols[symbol_index]
						vars := make([]uint64, len(nt.vars))
						if symbol.Var != nil {
							copy(vars, nt.vars)
							vars[*symbol.Var] = vars[*symbol.Var] - 1
							if vars[*symbol.Var] == 0 {
								continue
							}
						}
						var direction map[uint64]*pb.Links
						if symbol.Direction != nil && *symbol.Direction {
							direction = cell_runtime.Cell.Forth
						} else {
							direction = cell_runtime.Cell.Back
						}

						links, ok := direction[*symbol.Dimension]
						if ok {
							for _, link := range links.Links {
								if (link.Mime == nil || *link.Mime == ".") && (link.Path == nil || *link.Path == ".") {
									_, have_cell := state.ServiceState.Cells[*link.CellId]
									if symbol.Relabel == nil || !*symbol.Relabel {
										_, already := scanned[*link.CellId]
										if already {
											continue
										}
									}
									scanned[*link.CellId] = true
									if have_cell {
										ents.PushBack(placedNonTerminal{*link.CellId, symbol_index, vars})
									} else {
										needed[*link.CellId] = true
									}
								}
							}
						}
					}
				}
			} else {
				needed[*cursor.Cell] = true
			}
		}
	}
	changes_to_view := map[string]bool{}
	for k, _ := range state.ServiceState.InView {
		_, e := needed[k]
		if !e {
			changes_to_view[k] = false
		}
	}
	for k, _ := range needed {
		_, e := state.ServiceState.InView[k]
		if !e {
			changes_to_view[k] = true
		}
	}
	return changes_to_view
}

func update_view(state *pb.ClientState) {
	for {
		changes_to_view := evaluate_loses(state)
		if len(changes_to_view) == 0 {
			return
		}
		new_view := &pb.ServiceState{InView: changes_to_view}
		send_to_service(new_view)
		merge_new_state_from_service(recv_from_service(), state.ServiceState)
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

			CellTemplate: &pb.CellRuntime{
				Cell: &pb.Cell{
					Encoding: pb.Encoding_UTF8.Enum(),
					Mime:     &text_plain,
				},
				EditCount:  &one,
				ClickCount: &one,
				Deleted:    &falsev,

				CellRuntimeModes: map[uint32]pb.Mode{
					1:  pb.Mode_READ_WRITE,
					2:  pb.Mode_READ_WRITE,
					3:  pb.Mode_READ_ONLY,
					4:  pb.Mode_READ_WRITE,
					5:  pb.Mode_READ_ONLY,
					6:  pb.Mode_READ_ONLY,
					7:  pb.Mode_READ_ONLY,
					8:  pb.Mode_READ_ONLY,
					9:  pb.Mode_READ_ONLY,
					10: pb.Mode_READ_ONLY,
				},
				CellModes: map[uint32]pb.Mode{
					1:   pb.Mode_READ_WRITE,
					2:   pb.Mode_READ_ONLY,
					3:   pb.Mode_READ_ONLY,
					4:   pb.Mode_READ_WRITE,
					5:   pb.Mode_READ_WRITE,
					6:   pb.Mode_READ_ONLY,
					200: pb.Mode_READ_ONLY,
				},
				ForLinkModes: map[uint64]pb.Mode{
					0: pb.Mode_READ_WRITE,
					1: pb.Mode_READ_WRITE,
				},
				BackLinkModes: map[uint64]pb.Mode{
					0: pb.Mode_READ_WRITE,
					1: pb.Mode_READ_WRITE,
				},
				SupportedEncodings: []pb.Encoding{pb.Encoding_UTF8},
			},
		},
	}
	ss := state.ServiceState
	send_to_service(ss)
	merge_new_state_from_service(recv_from_service(), ss)
	//////////////////////////////////////////////////////////
	// Getting the cells seen by the default index selection//
	//////////////////////////////////////////////////////////
	{
		state.Selections = map[string]*pb.Selection{}
		state.Selections["index"] = &pb.Selection{ // of course, struct literals can be addressed, because golang doesn't just suck, it's inconsistent as well.
			Name:        &index, // golang sucks
			UpdateCount: &one,   // golang sucks
			Clients: map[string]pb.Selection_Status{
				"manager": pb.Selection_PRIMARY,
			},
			Cursors: []*pb.Cursor{&pb.Cursor{ // Golang also sucks, because arrays and struct literalls basically look the same. So confusing.
				Name: &index, // golang sucks
				Cell: ss.Index,
				Los: &pb.LineOfSight{
					Vars: []uint64{1000},
					Symbols: []*pb.Symbol{
						&pb.Symbol{},
						&pb.Symbol{
							Direction: &falsev,
							Dimension: &zero,
							Var:       &zero32,
							Relabel:   &falsev,
						},
						&pb.Symbol{
							Direction: &truev,
							Dimension: &zero,
							Var:       &zero32,
							Relabel:   &falsev,
						},
					},
					ProductionRules: map[uint32]*pb.RHS{
						0: &pb.RHS{Symbols: []uint32{1, 2}},
						1: &pb.RHS{Symbols: []uint32{1}},
						2: &pb.RHS{Symbols: []uint32{2}},
					},
				},
			}},
		}
		update_view(state)
	}
	for _, cr := range state.ServiceState.Cells {
		//fmt.Println(cell_id)
		fmt.Println(string(cr.Cell.Data))
	}
}
