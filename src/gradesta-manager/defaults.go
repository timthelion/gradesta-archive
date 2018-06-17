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
			Round: &pb.Round{Request: &one},

			CellTemplate: &pb.CellRuntime{
				Cell: &pb.Cell{
					Encoding: pb.Encoding_UTF8.Enum(),
					Mime:     &text_plain,
				},
				UpdateCount: &one,
				ClickCount:  &one,
				Deleted:     &falsev,

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
