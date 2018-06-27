package main

import (
	"fmt"
	"log"

	pb "./pb"
)

func make_error(round *pb.Round, error string) *pb.ClientState {
	log.Println("Warning: error merging states.", error)
	rval := &pb.ClientState{
		ServiceState: &pb.ServiceState{
			Round: round,
		},
	}
	rval.ServiceState.Round.Errors = &error
	return rval
}

func check_for_conflicts(changes *pb.ClientState) *pb.ClientState {
	if changes.ServiceState != nil && changes.ServiceState.Cells != nil {
		for cell_id, cell_runtime := range changes.ServiceState.Cells {
			current_cell_state, exists := state.ServiceState.Cells[cell_id]
			if exists && (cell_runtime.UpdateCount == nil || *cell_runtime.UpdateCount != *current_cell_state.UpdateCount+1) {
				return make_error(changes.ServiceState.Round, fmt.Sprintf("Edit conflict on cell '%s' someone else edited that cell before you.", cell_id))
			}
		}
	}
	for selection_id, selection := range changes.Selections {
		selection_state, exists := state.Selections[selection_id]
		if selection.UpdateCount == nil {
			log.Println("Invalid message! Selection has no update count!")
			return nil
		}
		if exists && *selection.UpdateCount != *selection_state.UpdateCount+1 {
			if changes.ServiceState.Round == nil {
				log.Println("Invalid message! No round received from client!")
				return nil
			}
			return make_error(changes.ServiceState.Round, fmt.Sprintf("Edit conflict on selection '%s' someone else updated that selection before you.", selection_id))
		}
	}
	return nil
}
