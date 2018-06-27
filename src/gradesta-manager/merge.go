package main

import (
	//	"log"
	//	"math"

	pb "./pb"
)

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

/*
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
*/
func merge_cell_runtimes(ncr *pb.CellRuntime, ocr *pb.CellRuntime) {
	if ncr.Cell != nil {
		ocr.Cell = ncr.Cell
	}
	if ncr.UpdateCount != nil {
		ocr.UpdateCount = ncr.UpdateCount
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

func merge_new_state_from_service(nss *pb.ServiceState) {
	merge_service_state_changes(nss, state.ServiceState)
	if pending_changes_for_clients.ServiceState == nil {
		pending_changes_for_clients.ServiceState = &pb.ServiceState{}
	}
	merge_service_state_changes(nss, pending_changes_for_clients.ServiceState)
}

func merge_service_state_changes(nss *pb.ServiceState, ss *pb.ServiceState) {
	if nss.Index != nil {
		ss.Index = nss.Index
	}
	if nss.Round != nil {
		ss.Round = nss.Round
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
	if ss.ServiceStateModes == nil {
		ss.ServiceStateModes = map[uint32]pb.Mode{}
	}
	for field, mode := range nss.ServiceStateModes {
		ss.ServiceStateModes[field] = mode
	}
	for cell_id, cell_runtime := range nss.Cells {
		old_cell, e := ss.Cells[cell_id]
		if e {
			merge_cell_runtimes(cell_runtime, old_cell)
		} else {
			if ss.Cells == nil {
				ss.Cells = map[string]*pb.CellRuntime{}
			}
			ss.Cells[cell_id] = cell_runtime
		}
	}
}

func merge_from_clients(ncs *pb.ClientState, ocs *pb.ClientState) {
	for client_id, client := range ncs.Clients {
		if ocs.Clients == nil {
			ocs.Clients = map[string]*pb.Client{}
		}
		ocs.Clients[client_id] = client
	}
	for selection_id, selection := range ncs.Selections {
		old_selection, exists := ocs.Selections[selection_id]
		if exists {
			if selection.Name != nil {
				old_selection.Name = selection.Name
			}
			old_selection.UpdateCount = selection.UpdateCount
			for client_id, status := range selection.Clients {
				old_selection.Clients[client_id] = status
			}
			for center, cursor := range selection.Cursors {
				if cursor.Deleted != nil && *cursor.Deleted {
					delete(old_selection.Cursors, center)
				} else {
					old_selection.Cursors[center] = cursor
				}
			}
		} else {
			if ocs.Selections == nil {
				ocs.Selections = map[string]*pb.Selection{}
			}
			ocs.Selections[selection_id] = selection
		}
	}
}
