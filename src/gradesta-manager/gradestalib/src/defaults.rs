use gradesta;
use std::collections::HashMap;


pub fn blank_cell_runtime() -> gradesta::CellRuntime {
 gradesta::CellRuntime {
  cell: None,
  update_count: None,
  click_count: None,
  deleted: None,
  creation_id: None,
  cell_runtime_modes: HashMap::new(),
  cell_modes: HashMap::new(),
  link_modes: HashMap::new(),
  for_link_modes: HashMap::new(),
  back_link_modes: HashMap::new(),
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
  dynamic: false,
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
