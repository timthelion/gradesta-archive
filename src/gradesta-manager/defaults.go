package main

import (
	pb "./pb"
	"reflect"
	"strconv"
	"strings"
)

var (
	serviceStateType = reflect.TypeOf(pb.ServiceState{})
	cellRuntimeType  = reflect.TypeOf(pb.CellRuntime{})
	cellType         = reflect.TypeOf(pb.Cell{})
	linkType         = reflect.TypeOf(pb.Link{})
)

func fid(field_name string, rtype reflect.Type) uint32 { // Get a protobuf field id
	field, _ := rtype.FieldByName(field_name)
	field_id, _ := strconv.Atoi(strings.Split(field.Tag.Get("protobuf"), ",")[1])
	return uint32(field_id)
}

func ss_fid(field_name string) uint32 { //ServiceState field id
	return fid(field_name, serviceStateType)
}

func cr_fid(field_name string) uint32 { //CellRuntime field id
	return fid(field_name, cellRuntimeType)
}

func c_fid(field_name string) uint32 { //Cell field id
	return fid(field_name, cellType)
}

func l_fid(field_name string) uint32 { //Link field id
	return fid(field_name, linkType)
}

var (
	default_state = pb.ClientState{
		ServiceState: &pb.ServiceState{
			OnDiskState: pb.ServiceState_READ_ONLY.Enum(),
			ServiceStateModes: map[uint32]*pb.Mode{
				ss_fid("Cells"):              &pb.Mode{Read: &truev, Write: &truev},
				ss_fid("NewCells"):           &pb.Mode{Read: &truev, Write: &truev},
				ss_fid("InView"):             &pb.Mode{Read: &truev, Write: &falsev},
				ss_fid("Index"):              &pb.Mode{Read: &truev, Write: &truev},
				ss_fid("OnDiskState"):        &pb.Mode{Read: &truev, Write: &truev},
				ss_fid("Round"):              &pb.Mode{Read: &truev, Write: &falsev},
				ss_fid("Log"):                &pb.Mode{Read: &truev, Write: &falsev},
				ss_fid("Metadata"):           &pb.Mode{Read: &truev, Write: &falsev},
				ss_fid("CellTemplate"):       &pb.Mode{Read: &truev, Write: &falsev},
				ss_fid("IdentityChallenge"):  &pb.Mode{Read: &truev, Write: &falsev},
				ss_fid("UserPublicKey"):      &pb.Mode{Read: &truev, Write: &falsev},
				ss_fid("UserSignature"):      &pb.Mode{Read: &truev, Write: &falsev},
				ss_fid("CapchaServers"):      &pb.Mode{Read: &truev, Write: &falsev},
				ss_fid("RequestedUserAttrs"): &pb.Mode{Read: &truev, Write: &falsev},
				ss_fid("UserAttrs"):          &pb.Mode{Read: &truev, Write: &falsev},
				ss_fid("ServiceStateModes"):  &pb.Mode{Read: &truev, Write: &falsev},
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

				CellRuntimeModes: map[uint32]*pb.Mode{
					cr_fid("Cell"):               &pb.Mode{Read: &truev, Write: &truev},
					cr_fid("UpdateCount"):        &pb.Mode{Read: &truev, Write: &truev},
					cr_fid("ClickCount"):         &pb.Mode{Read: &truev, Write: &falsev},
					cr_fid("Deleted"):            &pb.Mode{Read: &truev, Write: &truev},
					cr_fid("CreationId"):         &pb.Mode{Read: &truev, Write: &falsev},
					cr_fid("CellRuntimeModes"):   &pb.Mode{Read: &truev, Write: &falsev},
					cr_fid("CellModes"):          &pb.Mode{Read: &truev, Write: &falsev},
					cr_fid("ForLinkModes"):       &pb.Mode{Read: &truev, Write: &falsev},
					cr_fid("BackLinkModes"):      &pb.Mode{Read: &truev, Write: &falsev},
					cr_fid("SupportedEncodings"): &pb.Mode{Read: &truev, Write: &falsev},
				},
				CellModes: map[uint32]*pb.Mode{
					c_fid("Data"):     &pb.Mode{Read: &truev, Write: &truev},
					c_fid("Encoding"): &pb.Mode{Read: &truev, Write: &falsev},
					c_fid("Mime"):     &pb.Mode{Read: &truev, Write: &falsev},
					c_fid("Forth"):    &pb.Mode{Read: &truev, Write: &truev},
					c_fid("Back"):     &pb.Mode{Read: &truev, Write: &truev},
					c_fid("Tags"):     &pb.Mode{Read: &truev, Write: &falsev},
					c_fid("Coords"):   &pb.Mode{Read: &truev, Write: &falsev},
				},
				LinkModes: map[uint32]*pb.Mode{
					l_fid("ServiceId"): &pb.Mode{Read: &truev, Write: &falsev},
					l_fid("Path"):      &pb.Mode{Read: &truev, Write: &falsev},
					l_fid("CellId"):    &pb.Mode{Read: &truev, Write: &truev},
				},
				ForLinkModes: map[uint64]*pb.Mode{
					0: &pb.Mode{Read: &truev, Write: &truev},
					1: &pb.Mode{Read: &truev, Write: &truev},
				},
				BackLinkModes: map[uint64]*pb.Mode{
					0: &pb.Mode{Read: &truev, Write: &truev},
					1: &pb.Mode{Read: &truev, Write: &truev},
				},
				SupportedEncodings: []pb.Encoding{pb.Encoding_UTF8},
			},
		},
	}
)
