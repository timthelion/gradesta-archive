package main

import (
	"log"

	deque "github.com/gammazero/deque"

	pb "./pb"
)

var (
	global_max_length    uint64 = 10000000
	evaluated_selections        = map[string]uint64{}
)

type placedNonTerminal struct {
	cell_id    string
	symbol     int32
	vars       map[uint32]uint64
	generation uint64
}

func evaluate_loses() bool {
	needed := map[string]bool{}
	if pending_changes_for_clients.Selections == nil {
		pending_changes_for_clients.Selections = map[string]*pb.Selection{}
	}
	for selection_id, selection := range state.Selections {
		prev_update_count, ex := evaluated_selections[selection_id]
		if ex && prev_update_count == *selection.UpdateCount {
			continue
		}
		if pending_changes_for_clients.Selections[selection_id] == nil {
			pending_changes_for_clients.Selections[selection_id] = &pb.Selection{}
		}
		pending_selection := pending_changes_for_clients.Selections[selection_id]
		if selection.MaxLength == nil {
			selection.MaxLength = &global_max_length
		}
		if pending_selection.Cursors == nil {
			pending_selection.Cursors = map[string]*pb.Cursor{}
		}
		for center_id, cursor := range selection.Cursors {
			scanned := map[string]bool{}
			_, have_cell := state.ServiceState.Cells[center_id]
			if have_cell {
				var ents deque.Deque // exposed non-terminals
				if pending_selection.Cursors[center_id] == nil {
					pending_selection.Cursors[center_id] = &pb.Cursor{}
				}
				pending_cursor := pending_selection.Cursors[center_id]
				if pending_cursor.InView == nil {
					pending_cursor.InView = map[string]bool{}
				}
				pending_cursor.InView[center_id] = true
				if cursor.StartSymbol == nil {
					log.Println("Warning, no start symbol set for cursor.")
					continue
				}
				ents.PushBack(placedNonTerminal{center_id, *cursor.StartSymbol, selection.Vars, 0})
				for ents.Len() > 0 {
					nt := ents.PopFront().(placedNonTerminal)
					cell_runtime := state.ServiceState.Cells[nt.cell_id]
					log.Println(cell_runtime, "ůůů", selection_id, ";;;;;")
					if selection.ProductionRules == nil {
						log.Fatalf("No production rules set in selection %s.", selection)
					}
					for _, symbol_index := range selection.ProductionRules[nt.symbol].Symbols {
						var symbol *pb.Symbol
						symbol = selection.Symbols[symbol_index]
						vars := map[uint32]uint64{}
						if symbol.Var != nil {
							log.Println(vars)
							for k, v := range nt.vars {
								vars[k] = v
							}
							if vars[*symbol.Var] == 0 {
								continue
							}
							vars[*symbol.Var] = vars[*symbol.Var] - 1
						} else {
							log.Println("Warning, production rule variable not set.")
							continue
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
									pending_cursor.InView[*link.CellId] = true
									if have_cell {
										pnt := placedNonTerminal{*link.CellId, symbol_index, vars, nt.generation + 1}
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
				state.Selections[selection_id].Cursors[center_id].InView = pending_cursor.InView
			} else {
				needed[center_id] = true
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
			for selection_id, selection := range state.Selections {
				evaluated_selections[selection_id] = *selection.UpdateCount
			}
			log.Println("Done updating view.")
			return
		}
		log.Println("Sending pending changes in view to service.", pending_changes_for_service)
		send_pending_changes_to_service()
		merge_new_state_from_service(recv_from_service())
	}
}
