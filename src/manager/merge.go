package main

import (
	"math"
	//"fmt"

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

func merge_cell_runtimes(ncr *pb.CellRuntime, ocr *pb.CellRuntime) {
	merge_cells(ncr.Cell, ocr.Cell)
	if ncr.EditCount != nil {
		ocr.EditCount = ncr.EditCount
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

func merge_new_state_from_service(nss *pb.ServiceState, ss *pb.ServiceState) {
	if nss.Index != nil {
		ss.Index = nss.Index
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
