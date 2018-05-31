package main

import (
	//pb "../pb"
)

func are_pending_changes_for_service() bool {
	return (len(pending_changes_for_service.Cells) > 0) || (len(pending_changes_for_service.InView) > 0) || (pending_changes_for_service.Index != nil) || (pending_changes_for_service.OnDiskState != nil)
}

func are_pending_changes_for_clients() bool {
	return len(pending_changes_for_clients.Clients) > 0 || len(pending_changes_for_clients.Selections) > 0 || (pending_changes_for_clients.ServiceState != nil)
}
