use gradesta;
use std::collections::HashMap;

pub fn no_access_mode() -> gradesta::Mode {
  Default::default()
}

pub fn rw_mode() -> gradesta::Mode {
 gradesta::Mode {
  read: Some(true),
  write: Some(true),
  ..Default::default()
 }
}

pub fn ro_mode() -> gradesta::Mode {
 gradesta::Mode {
  read: Some(true),
  ..Default::default()
 }
}

pub fn default_cell_runtime_template() -> gradesta::CellRuntime {
 gradesta::CellRuntime {
  update_count: 0,
  click_count: Some(0),
  deleted: Some(false),
  cell_runtime_modes: hashmap! {
   1 => rw_mode(),
   2 => rw_mode(),
   3 => rw_mode(),
   4 => rw_mode(),
   5 => rw_mode(),
   6 => ro_mode(),
   7 => ro_mode(),
   8 => ro_mode(),
   9 => ro_mode(),
   10 => ro_mode()
  },
  cell_modes: hashmap! {
   1 => rw_mode(),
   2 => ro_mode(),
   3 => ro_mode(),
   4 => no_access_mode(),
   5 => rw_mode(),
   6 => rw_mode(),
   200 => no_access_mode()
  },
  link_modes: hashmap! {
   1 => no_access_mode(),
   2 => no_access_mode(),
   3 => rw_mode(),
   4 => no_access_mode()
  },
  link_direction_modes: hashmap! {
   1 => rw_mode(),
   -1 => rw_mode(),
   2 => rw_mode(),
   -2 => rw_mode()
  },
  ..Default::default()
 }
}

pub fn default_service_state() -> gradesta::ServiceState{
 gradesta::ServiceState {
  on_disk_state: Some(gradesta::service_state::OnDiskState::Saved as i32),
  cell_template: Some(default_cell_runtime_template()),
  service_state_modes: hashmap! {
   1 => rw_mode(),
   2 => rw_mode(),
   4 => ro_mode(),
   5 => ro_mode(),
   7 => ro_mode(),
   8 => ro_mode(),
   9 => ro_mode(),
   10 => no_access_mode(),
   11 => no_access_mode(),
   12 => no_access_mode(),
   13 => ro_mode()
  },
  ..Default::default()
 }
}
