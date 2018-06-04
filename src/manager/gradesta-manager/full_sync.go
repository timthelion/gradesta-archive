package main

import (
	pb "../pb"
)

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
