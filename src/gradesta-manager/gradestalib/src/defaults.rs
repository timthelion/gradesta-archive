use gradesta;
use std::collections::HashMap;


pub fn blank_cell_runtime() -> gradesta::CellRuntime {
 gradesta::CellRuntime {
  ..Default::default()
 }
}

pub fn blank_actor_metadata() -> gradesta::ActorMetadata {
 gradesta::ActorMetadata {
  name: None,
  source_url: None,
  privacy_policy: None,
 }
}

pub fn blank_round() -> gradesta::Round{
 Default::default()
}

pub fn blank_service_state() -> gradesta::ServiceState {
 Default::default()
}

pub fn blank_client() -> gradesta::Client {
 gradesta::Client {
  status: None,
  metadata: None,
 }
}

pub fn blank_manager() -> gradesta::Manager {
 gradesta::Manager {
  metadata: None
 }
}

pub fn blank_mode() -> gradesta::Mode {
 Default::default()
}

pub fn blank_cell() -> gradesta::Cell {
 Default::default()
}

pub fn blank_link() -> gradesta::Link {
 Default::default()
}

pub fn blank_placed_symbol() -> gradesta::PlacedSymbol {
 Default::default()
}

pub fn blank_placed_symbols() -> gradesta::PlacedSymbols {
 gradesta::PlacedSymbols {
  in_view: None,
  placed_symbols: Vec::new()
 }
}

pub fn blank_op() -> gradesta::Op {
 Default::default()
}

pub fn blank_cursor() -> gradesta::Cursor{
 Default::default()
}

pub fn blank_selection() -> gradesta::Selection {
 Default::default()
}

pub fn blank_symbol() -> gradesta::Symbol {
 gradesta::Symbol {
  direction: false,
  dimension: 0,
  ops: Vec::new(),
  uroborus: None,
  children: Vec::new(),
  wanted: None,
 }
}

pub fn blank_walk_tree() -> gradesta::WalkTree {
 Default::default()
}

pub fn blank_client_state() -> gradesta::ClientState {
 gradesta::ClientState {
  service_state: None,
  clients: HashMap::new(),
  manager: None,
  selections: HashMap::new(),
  walk_trees: HashMap::new(),
  identity_challenge: None,
  user_signature: None,
  capcha_servers: Vec::new(),
 }
}

pub fn rw_mode() -> gradesta::Mode {
 gradesta::Mode {
  read: Some(true),
  write: Some(true),
  ..blank_mode()
 }
}

pub fn ro_mode() -> gradesta::Mode {
 gradesta::Mode {
  read: Some(true),
  ..blank_mode()
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
   4 => blank_mode(),
   5 => rw_mode(),
   6 => rw_mode(),
   200 => blank_mode()
  },
  link_modes: hashmap! {
   1 => blank_mode(),
   2 => blank_mode(),
   3 => rw_mode()
  },
  for_link_modes: hashmap! {
   0 => rw_mode(),
   1 => rw_mode()
  },
  back_link_modes: hashmap! {
   0 => rw_mode(),
   1 => rw_mode()
  },
  ..blank_cell_runtime()
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
   10 => blank_mode(),
   11 => blank_mode(),
   12 => blank_mode(),
   13 => ro_mode()
  },
  ..blank_service_state()
 }
}
