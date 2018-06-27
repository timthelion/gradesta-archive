package main

import (
	"log"

	pb "./pb"
)

func are_pending_changes_for_service() bool {
	return (len(pending_changes_for_service.Cells) > 0) || (len(pending_changes_for_service.InView) > 0) || (pending_changes_for_service.Index != nil) || (pending_changes_for_service.OnDiskState != nil)
}

func are_pending_changes_for_clients() bool {
	return len(pending_changes_for_clients.Clients) > 0 || len(pending_changes_for_clients.Selections) > 0 || (pending_changes_for_clients.ServiceState != nil)
}

func stage_full_sync() {
	if state.ServiceState != nil {
		pending_changes_for_clients.ServiceState = &pb.ServiceState{
			Index:             state.ServiceState.Index,
			OnDiskState:       state.ServiceState.OnDiskState,
			Metadata:          state.ServiceState.Metadata,
			CellTemplate:      state.ServiceState.CellTemplate,
			ServiceStateModes: state.ServiceState.ServiceStateModes,
		}
	}
	pending_changes_for_clients.Manager = state.Manager
	for selection_id, selection := range state.Selections {
		if pending_changes_for_clients.Selections == nil {
			pending_changes_for_clients.Selections = map[string]*pb.Selection{}
		}
		pending_changes_for_clients.Selections[selection_id] = &pb.Selection{
			Name:    selection.Name,
			Clients: selection.Clients,
		}
	}
}

func customize_for_client(client_id string, pending *pb.ClientState) (*pb.ClientState, bool) {
	changed := false
	pss := pending.ServiceState
	if pss != nil &&
		(pss.Index != nil ||
			pss.OnDiskState != nil ||
			(pss.Round != nil && *pss.Round.ClientOfOrigin == client_id) ||
			len(pss.Log) > 0 ||
			pss.Metadata != nil ||
			pss.CellTemplate != nil ||
			len(pss.ServiceStateModes) > 0 ||
			len(pss.UserIndexes) > 0) {
		changed = true
	}
	in_view := map[string]bool{}
	pending_selections := map[string]*pb.Selection{}
	for selection_id, selection := range pending.Selections {
		status, ex := state.Selections[selection_id].Clients[client_id]
		if ex && status != pb.Selection_NONE {
			log.Println(ex, client_id, status, state.Selections[selection_id].Clients, "šščščšškjfldslkfjdskfjdslkjfdslkjfdskljf;;;;;")
			for _, cursor := range selection.Cursors {
				for cell_id, visible := range cursor.InView {
					if visible {
						in_view[cell_id] = true
					}
				}
			}
			pending_selections[selection_id] = selection
			if pending.Selections != nil {
				_, exists := pending.Selections[selection_id]
				if exists {
					changed = true
				}
			}
		}
	}
	log.Println(pending_selections, "íé")
	pending_cells := map[string]*pb.CellRuntime{}
	for cell_id, _ := range in_view {
		pending_cells[cell_id] = state.ServiceState.Cells[cell_id]
	}
	var pending_round *pb.Round = nil
	if pss != nil {
		pending_round = pss.Round
		if pss.Round == nil || *pss.Round.ClientOfOrigin != client_id {
			pending_round = nil
		}
	}

	fc := &pb.ClientState{
		Clients:    pending.Clients,
		Manager:    pending.Manager,
		Selections: pending_selections,
	}
	fc.ServiceState = &pb.ServiceState{
		Cells: pending_cells,
		Round: pending_round,
	}
	if pss != nil {
		fc.ServiceState.Index = pss.Index
		fc.ServiceState.OnDiskState = pss.OnDiskState
		fc.ServiceState.Log = pss.Log
		fc.ServiceState.Metadata = pss.Metadata
		fc.ServiceState.CellTemplate = pss.CellTemplate
		fc.ServiceState.ServiceStateModes = pss.ServiceStateModes
		fc.ServiceState.UserIndexes = pss.UserIndexes
	}

	return fc, changed
}
