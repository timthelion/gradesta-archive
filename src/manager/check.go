package main

import (
    "fmt"

	pb "./pb"
)

func make_error(round *pb.Round,error string) *pb.ClientState {
			rval := &pb.ClientState{
				ServiceState: &pb.ServiceState{
					CurrentRound: round,
				},
			}
			rval.ServiceState.CurrentRound.Errors = &error
            return rval

}

func check_for_conflicts(changes *pb.ClientState) *pb.ClientState {
	for cell_id, cell_runtime := range changes.ServiceState.Cells {
		current_cell_state, exists := state.ServiceState.Cells[cell_id]
		if exists && *cell_runtime.UpdateCount == *current_cell_state.UpdateCount+1 {
            return make_error(changes.ServiceState.CurrentRound, fmt.Sprintf("Edit conflict on cell '%s' someone else edited that cell before you.", cell_id))
		}
	}
    for selection_id, selection := range changes.Selections {
		selection_state, exists := state.Selections[selection_id]
		if exists && *selection.UpdateCount == *selection_state.UpdateCount+1 {
            return make_error(changes.ServiceState.CurrentRound, fmt.Sprintf("Edit conflict on selection '%s' someone else updated that selection before you.", selection_id))
        }
    }
	return nil
}
