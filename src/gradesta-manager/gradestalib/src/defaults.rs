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

pub const blank_actor_metadata: gradesta::ActorMetadata = gradesta::ActorMetadata {
 name: None,
 source_url: None,
 privacy_policy: None,
};

pub const blank_round: gradesta::Round = gradesta::Round {
 client_of_origin: None,
 errors: None,
 request: None,
 full_sync: None,
};

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
  identity_challenge: None,
  user_public_key: None,
  user_signature: None,
  capcha_servers: Vec::new(),
  requested_user_attrs: HashMap::new(),
  user_attrs: HashMap::new(),
  service_state_modes: HashMap::new(),
 }
}
