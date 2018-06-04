package main

import (
	"log"

	deque "github.com/gammazero/deque"

	pb "../pb"
)

type placedNonTerminal struct {
	cell_id string
	symbol  uint32
	vars    []uint64
}

func evaluate_loses() bool {
	needed := map[string]bool{}
	scanned := map[string]bool{}
	if pending_changes_for_clients.Selections == nil {
		pending_changes_for_clients.Selections = map[string]*pb.Selection{}
	}
	for selection_id, selection := range state.Selections {
		if pending_changes_for_clients.Selections[selection_id] == nil {
			pending_changes_for_clients.Selections[selection_id] = &pb.Selection{}
		}
		pending_changes_for_clients.Selections[selection_id].Cursors = []*pb.Cursor{}
		for _, cursor := range selection.Cursors {
			pending_cursor := &pb.Cursor{}
			pending_cursor.Los = &pb.LineOfSight{}
			pending_changes_for_clients.Selections[selection_id].Cursors = append(pending_changes_for_clients.Selections[selection_id].Cursors, pending_cursor)
			los := cursor.Los
			_, have_cell := state.ServiceState.Cells[*cursor.Cell]
			if have_cell {
				log.Println(cursor)
				var ents deque.Deque // exposed non-terminals

				if pending_cursor.Los.InView == nil {
					pending_cursor.Los.InView = map[string]bool{}
				}
				pending_cursor.Los.InView[*cursor.Cell] = true
				ents.PushBack(placedNonTerminal{*cursor.Cell, 0, los.Vars})
				for ents.Len() > 0 {
					nt := ents.PopFront().(placedNonTerminal)
					cell_runtime := state.ServiceState.Cells[nt.cell_id]
					if los.ProductionRules == nil {
						log.Fatalf("No production rules set in los %s.", los)
					}
					for _, symbol_index := range los.ProductionRules[nt.symbol].Symbols {
						var symbol *pb.Symbol
						symbol = los.Symbols[symbol_index]
						vars := make([]uint64, len(nt.vars))
						if symbol.Var != nil {
							copy(vars, nt.vars)
							if vars[*symbol.Var] == 0 {
								continue
							}
							vars[*symbol.Var] = vars[*symbol.Var] - 1
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
									pending_cursor.Los.InView[*link.CellId] = true
									if have_cell {
										pnt := placedNonTerminal{*link.CellId, symbol_index, vars}
										log.Println("Placed non-terminal:", pnt)
										ents.PushBack(pnt)
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
	pending_changes_for_service.InView = changes_to_view
	return len(changes_to_view) > 0
}

func update_view() {
	for {
		if !evaluate_loses() {
			log.Println("Done updating view.")
			return
		}
		log.Println("Sending pending changes in view to service.", pending_changes_for_service)
		send_pending_changes_to_service()
		merge_new_state_from_service(recv_from_service())
	}
}
