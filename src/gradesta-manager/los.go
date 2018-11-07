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

type Walker func(needed map[string]bool)

type TreeWalker struct {
	walk Walker
}

type PlacedNonTerminal struct {
	string
	*pb.PlacedSymbol
}

func walk(center_id string, cursor pb.Cursor, pending_selection pb.Selection, needed map[string]bool) {
	scanned := map[string]bool{}
	_, have_cell := state.ServiceState.Cells[center_id]
	if have_cell {
		var ents deque.Deque // exposed non-terminals
		if pending_selection.Cursors[center_id] == nil {
			pending_selection.Cursors[center_id] = &pb.Cursor{}
		}
		pending_cursor := pending_selection.Cursors[center_id]
		if pending_cursor.PlacedSymbols == nil {
			pending_cursor.PlacedSymbols = map[string]*pb.PlacedSymbols{}
		}
        walk_tree := state.WalkTrees[*cursor.Los]
		newly_placed_symbol := &pb.PlacedSymbol{
			SymbolId: &zero32,
			Vars:     walk_tree.Vars,
		}
		if pending_cursor.PlacedSymbols[center_id] == nil {
			pending_cursor.PlacedSymbols[center_id] = &pb.PlacedSymbols{}
		}
		pending_cursor.PlacedSymbols[center_id].InView = &truev
		pending_cursor.PlacedSymbols[center_id].PlacedSymbols = append(pending_cursor.PlacedSymbols[center_id].PlacedSymbols, newly_placed_symbol)
		ents.PushBack(PlacedNonTerminal{center_id, newly_placed_symbol})
		for ents.Len() > 0 {
			cell_id, placed_symbol := ents.PopFront().(PlacedNonTerminal)
			cell_runtime := state.ServiceState.Cells[cell_id]
			for child_index := range walk_tree.Symbols[placed_symbol.SymbolId].Children {
            place_child(child_index, cell_id, placed_symbol, cell_runtime)
						}
		}
		state.Selections[selection_id].Cursors[center_id].InView = pending_cursor.InView
	} else {
		needed[center_id] = true
	}
}

func place_child() {
	child_symbol = walk_tree.Symbols[symbol_index]
				child_vars := make([]uint64, len(walk_tree.Vars))
				for _, op := child_symbol.Ops{
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
								// log.Println("Placed non-terminal:", pnt)
								ents.PushBack(pnt)
							} else {
								needed[*link.CellId] = true
							}
						}
					}
				}

}

func (t *TreeWalker) evaluate_loses() bool {
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
		if pending_selection.Cursors == nil {
			pending_selection.Cursors = map[string]*pb.Cursor{}
		}
		for center_id, cursor := range selection.Cursors {
			if cursor.Deleted != nil && *cursor.Deleted {
				continue
			}
			t.walk(center_id, cursor, pending_selection, needed)
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
		send_pending_changes_to_service()
		merge_new_state_from_service(recv_from_service())
	}
}
