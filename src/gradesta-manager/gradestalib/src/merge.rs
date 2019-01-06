use gradesta;
use std::hash::Hash;
use std::collections::HashMap;

/// # Merge input map into another HashMap
/// ```
/// # #[macro_use] extern crate maplit;
/// # extern crate gradestalib;
/// # use gradestalib::merge::merge_map;
///
/// let input = hashmap!{
///   "foo" => "bar",
///   "bin" => "baz",
/// };
///
/// let mut old = hashmap!{
///   "foo" => "lol",
///   "ma" =>  "pa",
/// };
///
/// merge_map(&input, &mut old);
///
/// let result = hashmap!{
///   "foo" => "bar",
///   "bin" => "baz",
///   "ma"  => "pa",
/// };
///
/// assert_eq!(old, result);
/// ```
pub fn merge_map<A: Hash + Eq + Clone, B: Clone>(input: &HashMap<A, B>, old: &mut HashMap<A, B>) {
 for (key, value) in input.iter() {
  old.insert(key.clone(), value.clone());
 }
}

pub fn merge_object_map<A: Hash + Eq + Clone, B: Clone> (
 input: &HashMap<A, B>,
 old: &mut HashMap<A, B>,
 merge_fn: fn(*const B, *mut B),
 should_delete: fn(*const B) -> bool ) {
 for (key, obj) in input.clone() {
  let mut ins = false;
  if should_delete(&obj) {
   old.remove(&key);
  } else {
   match old.get_mut(&key) {
    Some(mut old_obj) => {
     merge_fn(&obj, old_obj);
    },
    None => {
     ins = true;
    }
   }
   if ins {
     old.insert(key, obj);
   }
  }
 }
}

macro_rules! set_if_some {
 ($input:ident, $old:ident, $( $x:ident ),* ) => {
   $(
    if let Some($x) = &$input.$x {
     $old.$x = Some($x.clone());
    }
   )*
 }
}

macro_rules! merge_value_maps {
 ($input:ident, $old:ident, $( $x:ident ),* ) => {
   $(
    merge_map(&$input.$x, &mut $old.$x);
   )*
 }
}

macro_rules! merge_objects {
 ($input:ident, $old:ident, $field:ident, $merge_fn:ident ) => {
  if let Some(field) = $input.$field.clone() {
   if let Some(ref mut old_field) = $old.$field {
    $merge_fn(&field, old_field);
   } else {
    $old.$field = $input.$field.clone();
   }
  }
 }
}

/// # Merge Cells
///
/// ```
/// # #[macro_use] extern crate maplit;
/// # extern crate gradestalib;
/// # use gradestalib::merge::merge_cells;
/// # use gradestalib::gradesta;
/// # use gradestalib::defaults;
///
/// let input = gradesta::Cell{
///  data: hashmap!{ 0 => vec!(1) },
///  mime: Some(String::from("txt")),
/// ..Default::default()
/// };
/// let mut old = gradesta::Cell{
///  data: hashmap!{ 0 => vec!(2), 1 => vec!(3) },
/// ..Default::default()
/// };
///
/// merge_cells(&input, &mut old);
///
/// let expected = gradesta::Cell{
///  data: hashmap!{ 0 => vec!(1), 1 => vec!(3) },
///  mime: Some(String::from("txt")),
/// ..Default::default()
/// };
///
/// assert_eq!(old, expected);
/// ```
pub fn merge_cells(input: &gradesta::Cell, old: &mut gradesta::Cell) {
 set_if_some![input, old,
  mime,
  encoding
 ];

 merge_value_maps![input, old,
  data,
  links,
  coords,
  tags
 ];
 // TODO clear empty links, tags, and coords
}


/*
/// # Merge set of updates into cell runtime
///
/// ```
/// # #[macro_use] extern crate maplit;
/// # extern crate gradestalib;
/// # use gradestalib::merge::merge_cell_runtimes;
/// # use gradestalib::gradesta;
/// # use gradestalib::defaults;
///
/// let input = gradesta::CellRuntime{
///  update_count: 3,
///  click_count: Some(2),
///  cell_runtime_modes: hashmap!{
///   2 => defaults::rw_mode(),
///   3 => defaults::rw_mode()
///  },
/// ..Default::default()
/// };
/// let mut old = gradesta::CellRuntime{
///  update_count: 2,
///  click_count: Some(1),
///  creation_id: Some(String::from("foo")),
///  cell_runtime_modes: hashmap!{
///   1 => defaults::ro_mode(),
///   2 => defaults::ro_mode()
///  },
/// ..Default::default()
/// };
///
/// merge_cell_runtimes(&input, &mut old);
///
/// let expected = gradesta::CellRuntime{
///  update_count: 3,
///  click_count: Some(2),
///  creation_id: Some(String::from("foo")),
///  cell_runtime_modes: hashmap!{
///   1 => defaults::ro_mode(),
///   2 => defaults::rw_mode(),
///   3 => defaults::rw_mode()
///  },
/// ..Default::default()
/// };
///
/// assert_eq!(old, expected);
/// ```
pub fn merge_cell_runtimes(input: &gradesta::CellRuntime, old: &mut gradesta::CellRuntime) {

 old.update_count = input.update_count;

 set_if_some![input, old,
  click_count,
  deleted,
  creation_id
 ];

 merge_value_maps![input, old,
  cell_runtime_modes,
  cell_modes,
  link_modes,
  link_direction_modes
 ];

 merge_objects!(input, old, cell, merge_cells);
}

/// # Merge actor metadata
/// ```
/// # extern crate gradestalib;
/// # use gradestalib::merge::merge_actor_metadata;
/// # use gradestalib::gradesta;
///
/// let input = gradesta::ActorMetadata {
///  name: Some(String::from("Bob")),
///  ..Default::default()
/// };
///
/// let mut old = gradesta::ActorMetadata {
///  name: Some(String::from("Alice")),
///  source_url: Some(String::from("gitlab.com/example/cool-service")),
///  privacy_policy: Some(String::from("Lol, privacy is so 20th century."))
/// };
///
/// merge_actor_metadata(&input, &mut old);
///
/// let expected = gradesta::ActorMetadata {
///  name: Some(String::from("Bob")),
///  source_url: Some(String::from("gitlab.com/example/cool-service")),
///  privacy_policy: Some(String::from("Lol, privacy is so 20th century."))
/// };
///
/// assert_eq!(old, expected);
///
pub fn merge_actor_metadata(input: &gradesta::ActorMetadata, old: &mut gradesta::ActorMetadata) {
 set_if_some![input, old,
  name,
  source_url,
  privacy_policy];
}

/// # Merge service states
///
/// Merges all but the following fields which are never sent by the service.
///
///  - new_cells
///  - in_view
///  - round
///
/// ```
/// # #[macro_use] extern crate maplit;
/// # extern crate gradestalib;
/// # use gradestalib::merge::merge_service_states;
/// # use gradestalib::gradesta;
///
/// let input = gradesta::ServiceState {
///  cells: hashmap!{
///   String::from("id-abc") => gradesta::CellRuntime {
///      update_count: 2,
///      ..Default::default()
///    }
///  },
///  index: Some(String::from("foo")),
///  round: Some(Default::default()),
///  ..Default::default()
/// };
///
/// let mut old = gradesta::ServiceState {
///  cells: hashmap!{
///   String::from("id-abc") => gradesta::CellRuntime {
///      update_count: 1,
///      ..Default::default()
///    },
///   String::from("id-efg") => gradesta::CellRuntime {
///      update_count: 1,
///      ..Default::default()
///    }
///  },
///  index: Some(String::from("bar")),
///  ..Default::default()
/// };
///
/// merge_service_states(&input, &mut old);
///
/// let expected = gradesta::ServiceState {
///  cells: hashmap!{
///   String::from("id-abc") => gradesta::CellRuntime {
///      update_count: 2,
///      ..Default::default()
///    },
///   String::from("id-efg") => gradesta::CellRuntime {
///      update_count: 1,
///      ..Default::default()
///    }
///  },
///  index: Some(String::from("foo")),
///  ..Default::default()
/// };
///
/// assert_eq!(old, expected);
/// ```
pub fn merge_service_states(input: &gradesta::ServiceState, old: &mut gradesta::ServiceState) {
 set_if_some![input, old,
  on_disk_state
 ];
 merge_value_maps![input, old,
  log,
  service_state_modes
 ];
 merge_objects!(input, old, service_metadata, merge_actor_metadata);
}

/// #Merge Clients
///
/// ```
/// # extern crate gradestalib;
/// # use gradestalib::merge::merge_clients;
/// # use gradestalib::gradesta;
///
/// let input = gradesta::Client {
///  status: Some(gradesta::client::Status::Normal as i32),
///  metadata: Some(gradesta::ActorMetadata {
///   name: Some(String::from("Henry")),
///   ..Default::default()
///  }),
///  ..Default::default()
/// };
/// let mut old = gradesta::Client {
///  status: Some(gradesta::client::Status::Initializing as i32),
///  metadata: Some(gradesta::ActorMetadata {
///   source_url: Some(String::from("example.com/src")),
///   ..Default::default()
///  }),
///  ..Default::default()
/// };
///
/// merge_clients(&input, &mut old);
///
/// let expected = gradesta::Client {
///  status: Some(gradesta::client::Status::Normal as i32),
///  metadata: Some(gradesta::ActorMetadata {
///   name: Some(String::from("Henry")),
///   source_url: Some(String::from("example.com/src")),
///   ..Default::default()
///  }),
//   ..Default::default()
/// };
///
/// assert_eq!(old, expected);
/// ```
pub fn merge_clients(input: &gradesta::Client, old: &mut gradesta::Client) {
 set_if_some!(input, old,
  status
 );
 merge_objects!(input, old, metadata, merge_actor_metadata);
}

/// #Merge Managers
///
/// ```
/// # extern crate gradestalib;
/// # use gradestalib::merge::merge_managers;
/// # use gradestalib::gradesta;
/// let input = gradesta::Manager {
///  metadata: Some(gradesta::ActorMetadata {
///   name: Some(String::from("Henry")),
///   ..Default::default()
///  })
/// };
/// let mut old = gradesta::Manager {
///  metadata: Some(gradesta::ActorMetadata {
///   source_url: Some(String::from("example.com/src")),
///   ..Default::default()
///  })
/// };
///
/// merge_managers(&input, &mut old);
///
/// let expected = gradesta::Manager {
///  metadata: Some(gradesta::ActorMetadata {
///   name: Some(String::from("Henry")),
///   source_url: Some(String::from("example.com/src")),
///   ..Default::default()
///  })
/// };
///
/// assert_eq!(old, expected);
/// ```
pub fn merge_managers(input: &gradesta::Manager, old: &mut gradesta::Manager) {
 if let Some(metadata) = input.metadata.clone() {
  if let Some(ref mut old_metadata) = old.metadata {
   merge_actor_metadata(&metadata, old_metadata);
  } else {
   old.metadata = input.metadata.clone();
  }
 }
}

/// # Merge selections
///
/// ```
/// # #[macro_use] extern crate maplit;
/// # extern crate gradestalib;
/// # use gradestalib::merge::merge_selections;
/// # use gradestalib::gradesta;
///
/// let input = gradesta::Selection {
///  name: Some(String::from("Lary")),
///  update_count: 3,
///  clients: hashmap!{
///   String::from("client-abc") => gradesta::selection::Status::Primary as i32
///  },
///  cursors: {
///   gradesta::Cursor {
///      walk_tree: Some(gradesta::WalkTreeInstance{
///        walk_tree: Some(String::from("xyz")),
///        ..Default::default()
///       }),
///      ..Default::default()
///    }
///  },
///  ..Default::default()
/// };
///
/// let mut old = gradesta::Selection {
///  update_count: 2,
///  cursors: {
///   gradesta::Cursor {
///      walk_tree: Some(gradesta::WalkTreeInstance{
///        walk_tree: Some(String::from("lmnop")),
///        ..Default::default()
///       }),
///      ..Default::default()
///    },
///   gradesta::Cursor {
///      walk_tree: Some(gradesta::WalkTreeInstance{
///        walk_tree: Some(String::from("abc")),
///        ..Default::default()
///       }),
///      ..Default::default()
///    }
///  },
///  ..Default::default()
/// };
///
/// merge_selections(&input, &mut old);
///
/// let expected = gradesta::Selection {
///  name: Some(String::from("Lary")),
///  update_count: 3,
///  clients: hashmap!{
///   String::from("client-abc") => gradesta::selection::Status::Primary as i32
///  },
///  cursors: {
///   gradesta::Cursor {
///      walk_tree: Some(gradesta::WalkTreeInstance{
///        walk_tree: Some(String::from("xyz")),
///        ..Default::default()
///       }),
///      ..Default::default()
///    },
///   gradesta::Cursor {
///      walk_tree: Some(gradesta::WalkTreeInstance{
///        walk_tree: Some(String::from("abc")),
///        ..Default::default()
///       }),
///      ..Default::default()
///    }
///  },
///  ..Default::default()
/// };
///
/// assert_eq!(old, expected);
/// ```
pub fn merge_selections(input: &gradesta::Selection, old: &mut gradesta::Selection) {
 old.update_count = input.update_count;

 set_if_some![input, old,
  name
 ];
 merge_value_maps![input, old,
  clients
 ];
 if input.cursors.len() > 0 {
    let mut merged_cursor = old.cursors[0].clone();
    merge_cursors(&input.cursors[0], &mut merged_cursor);
    input.cursors[0] = merged_cursor;
    old.cursors = input.cursors;
 }
}


/// # Merge cursors
///
/// ```
/// # #[macro_use] extern crate maplit;
/// # extern crate gradestalib;
/// # use gradestalib::merge::merge_cursors;
/// # use gradestalib::gradesta;
///
/// let input = gradesta::Cursor {
///  walk_tree: Some(gradesta::WalkTreeInstance{
///   walk_tree: Some(String::from("xyz")),
///   ..Default::default()
///  }),
///  selections: hashmap!{
///   3 => 0,
///   4 => 3 
///  },
///  ..Default::default()
/// };
///
/// let mut old = gradesta::Cursor {
///  walk_tree: Some(gradesta::WalkTreeInstance{
///   walk_tree: Some(String::from("lmnop")),
///   ..Default::default()
///  }),
///  selections: hashmap!{
///   3 => 4,
///  },
///  ..Default::default()
/// };
///
/// merge_cursors(&input, &mut old);
///
/// let expected = gradesta::Cursor {
///  walk_tree: Some(gradesta::WalkTreeInstance{
///   walk_tree: Some(String::from("xyz")),
///   ..Default::default()
///  }),
///  selections: hashmap!{
///   4 => 3 
///  },
///  ..Default::default()
/// };
///
/// assert_eq!(old, expected);
/// ```
pub fn merge_cursors(input: &gradesta::Cursor, old: &mut gradesta::Cursor) {
 set_if_some![input, old,
  walk_tree,
  cursor,
  code_completions,
  deleted
 ];
 merge_value_maps![input, old,
  selections
 ];
 // Remove empty selections
 let mut empty: Vec<u64> = Vec::new();
 for (k, v) in old.selections.iter() {
  if *v == 0 {
   empty.push(*k);
  }
 }
 for v in empty {
  old.selections.remove(&v);
 }
}


/// # Merge manager states
///
/// ```
/// # #[macro_use] extern crate maplit;
/// # extern crate gradestalib;
/// # use gradestalib::merge::merge_manager_states;
/// # use gradestalib::gradesta;
///
/// let input = gradesta::ManagerState{
///  ..Default::default()
/// };
///
/// let mut old = gradesta::ManagerState{
///  ..Default::default()
/// };
///
/// let expected = gradesta::ManagerState{
///  ..Default::default()
/// };
///
/// merge_manager_states(&input, &mut old);
///
/// assert_eq!(old, expected);
/// ```
pub fn merge_manager_states(input: &gradesta::ManagerState, old: &mut gradesta::ManagerState) {
 for (client_id, client) in input.clients.iter() {
 } 
 merge_objects!(input, old, manager, merge_managers);
 set_if_some![input, old,
  identity_challenge,
  user_signature
 ];
 old.capcha_servers.append(&mut input.capcha_servers.clone());
}
*/
