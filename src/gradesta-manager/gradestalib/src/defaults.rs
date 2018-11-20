use gradesta;
use std::collections::HashMap;


pub fn blank_cell_runtime() -> gradesta::CellRuntime {
 gradesta::CellRuntime {
  ..default::Default()
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
 gradesta::Round {
  client_of_origin: None,
  errors: None,
  request: None,
  full_sync: None,
 }
}

pub fn blank_service_state() -> gradesta::ServiceState {
 gradesta::ServiceState {
  cells: HashMap::new(),
  new_cells: Vec::new(),
  in_view: HashMap::new(),
  index: None,
  on_disk_state: None,
  round: None,
  log: HashMap::new(),
  metadata: None,
  cell_template: None,
  user_public_key: None,
  requested_user_attrs: HashMap::new(),
  user_attrs: HashMap::new(),
  service_state_modes: HashMap::new(),
 }
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
 gradesta::Mode {
  read: false,
  write: false,
  executable: false,
  dynamic: None,
  emulated: None
 }
}

pub fn blank_cell() -> gradesta::Cell {
 gradesta::Cell {
  data: None,
  encoding: None,
  mime: None,
  tags: Vec::new(),
  forth: HashMap::new(),
  back: HashMap::new(),
  coords: HashMap::new()
 }
}

pub fn blank_link() -> gradesta::Link {
 gradesta::Link {
  service_id: None,
  path: None,
  cell_id: String::from(""),
 }
}

pub fn blank_placed_symbol() -> gradesta::PlacedSymbol {
 gradesta::PlacedSymbol {
  vars: Vec::new(),
  symbol_id: None
 }
}

pub fn blank_placed_symbols() -> gradesta::PlacedSymbols {
 gradesta::PlacedSymbols {
  in_view: None,
  placed_symbols: Vec::new()
 }
}

pub fn blank_op() -> gradesta::Op {
 gradesta::Op {
  index: None,
  op: None,
  checks: HashMap::new()
 }
}

pub fn blank_cursor() -> gradesta::Cursor{
 gradesta::Cursor {
  los: None,
  var_overrides: HashMap::new(),
  selections: HashMap::new(),
  cursor: None,
  code_completions: None,
  order: None,
  deleted: None,
  placed_symbols: HashMap::new()
 }
}

pub fn blank_selection() -> gradesta::Selection {
 gradesta::Selection {
  name: None,
  update_count: None,
  clients: HashMap::new(),
  cursors: HashMap::new()
 }
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
 gradesta::WalkTree {
  symbols: Vec::new(),
  vars: Vec::new(),
  deleted: None
 }
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
  read: true,
  write: true,
  ..blank_mode()
 }
}

pub fn ro_mode() -> gradesta::Mode {
 gradesta::Mode {
  read: true,
  ..blank_mode()
 }
}

pub fn default_cell_runtime_template() -> gradesta::CellRuntime {
 gradesta::CellRuntime {
  update_count: Some(0),
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
  on_disk_state: gradesta::service_state::on_disk_state::SAVED,
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
