package main

import (
	deque "github.com/gammazero/deque"

	pb "./pb"
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
