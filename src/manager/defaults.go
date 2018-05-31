package main

import (
	pb "./pb"
)

var (
	default_state = pb.ClientState{
		ServiceState: &pb.ServiceState{
			OnDiskState: pb.ServiceState_READ_ONLY.Enum(),
			ServiceStateModes: map[uint32]pb.Mode{
				1: pb.Mode_READ_WRITE,
				2: pb.Mode_READ_WRITE,
				3: pb.Mode_READ_ONLY,
				4: pb.Mode_READ_WRITE,
				5: pb.Mode_READ_WRITE,
				6: pb.Mode_READ_ONLY,
				7: pb.Mode_READ_ONLY,
				8: pb.Mode_READ_ONLY,
			},
			CurrentRound: &pb.Round{Request: &one},

			CellTemplate: &pb.CellRuntime{
				Cell: &pb.Cell{
					Encoding: pb.Encoding_UTF8.Enum(),
					Mime:     &text_plain,
				},
				UpdateCount:  &one,
				ClickCount: &one,
				Deleted:    &falsev,

				CellRuntimeModes: map[uint32]pb.Mode{
					1:  pb.Mode_READ_WRITE,
					2:  pb.Mode_READ_WRITE,
					3:  pb.Mode_READ_ONLY,
					4:  pb.Mode_READ_WRITE,
					5:  pb.Mode_READ_ONLY,
					6:  pb.Mode_READ_ONLY,
					7:  pb.Mode_READ_ONLY,
					8:  pb.Mode_READ_ONLY,
					9:  pb.Mode_READ_ONLY,
					10: pb.Mode_READ_ONLY,
				},
				CellModes: map[uint32]pb.Mode{
					1:   pb.Mode_READ_WRITE,
					2:   pb.Mode_READ_ONLY,
					3:   pb.Mode_READ_ONLY,
					4:   pb.Mode_READ_WRITE,
					5:   pb.Mode_READ_WRITE,
					6:   pb.Mode_READ_ONLY,
					200: pb.Mode_READ_ONLY,
				},
				ForLinkModes: map[uint64]pb.Mode{
					0: pb.Mode_READ_WRITE,
					1: pb.Mode_READ_WRITE,
				},
				BackLinkModes: map[uint64]pb.Mode{
					0: pb.Mode_READ_WRITE,
					1: pb.Mode_READ_WRITE,
				},
				SupportedEncodings: []pb.Encoding{pb.Encoding_UTF8},
			},
		},
	}
)

func get_default_selection(index *string) *pb.Selection {
	return &pb.Selection{ // of course, struct literals can be addressed, because golang doesn't just suck, it's inconsistent as well.
		Name:        &indexv, // golang sucks
		UpdateCount: &one,    // golang sucks
		Clients: map[string]pb.Selection_Status{
			"manager": pb.Selection_PRIMARY,
		},
		Cursors: []*pb.Cursor{&pb.Cursor{ // Golang also sucks, because arrays and struct literalls basically look the same. So confusing.
			Name: &indexv, // golang sucks
			Cell: index,
			Los: &pb.LineOfSight{
				Vars: []uint64{1000},
				Symbols: []*pb.Symbol{
					&pb.Symbol{},
					&pb.Symbol{
						Direction: &falsev,
						Dimension: &zero,
						Var:       &zero32,
						Relabel:   &falsev,
					},
					&pb.Symbol{
						Direction: &truev,
						Dimension: &zero,
						Var:       &zero32,
						Relabel:   &falsev,
					},
				},
				ProductionRules: map[uint32]*pb.RHS{
					0: &pb.RHS{Symbols: []uint32{1, 2}},
					1: &pb.RHS{Symbols: []uint32{1}},
					2: &pb.RHS{Symbols: []uint32{2}},
				},
			},
		}},
	}
}
