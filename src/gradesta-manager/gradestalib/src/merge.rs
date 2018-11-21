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
/// ..defaults::blank_cell_runtime()
/// };
/// let mut old = gradesta::CellRuntime{
///  update_count: 2,
///  click_count: Some(1),
///  creation_id: Some(String::from("foo")),
///  cell_runtime_modes: hashmap!{
///   1 => defaults::ro_mode(),
///   2 => defaults::ro_mode()
///  },
/// ..defaults::blank_cell_runtime()
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
/// ..defaults::blank_cell_runtime()
/// };
///
/// assert_eq!(old, expected);
/// ```
pub fn merge_cell_runtimes(input: &gradesta::CellRuntime, old: &mut gradesta::CellRuntime) {

 old.update_count = input.update_count;

 set_if_some![input, old,
  cell,
  click_count,
  deleted,
  creation_id];

 merge_value_maps![input, old,
  cell_runtime_modes,
  cell_modes,
  link_modes,
  for_link_modes,
  back_link_modes];
}

/// # Merge actor metadata
/// ```
/// # extern crate gradestalib;
/// # use gradestalib::merge::merge_actor_metadata;
/// # use gradestalib::gradesta;
/// # use gradestalib::defaults;
///
/// let input = gradesta::ActorMetadata {
///  name: Some(String::from("Bob")),
///  ..defaults::blank_actor_metadata()
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
/// # use gradestalib::defaults;
///
/// let input = gradesta::ServiceState {
///  cells: hashmap!{
///   String::from("id-abc") => gradesta::CellRuntime {
///      update_count: 2,
///      ..defaults::blank_cell_runtime()
///    }
///  },
///  index: Some(String::from("foo")),
///  round: Some(defaults::blank_round()),
///  ..defaults::blank_service_state()
/// };
///
/// let mut old = gradesta::ServiceState {
///  cells: hashmap!{
///   String::from("id-abc") => gradesta::CellRuntime {
///      update_count: 1,
///      ..defaults::blank_cell_runtime()
///    },
///   String::from("id-efg") => gradesta::CellRuntime {
///      update_count: 1,
///      ..defaults::blank_cell_runtime()
///    }
///  },
///  index: Some(String::from("bar")),
///  ..defaults::blank_service_state()
/// };
///
/// merge_service_states(&input, &mut old);
///
/// let expected = gradesta::ServiceState {
///  cells: hashmap!{
///   String::from("id-abc") => gradesta::CellRuntime {
///      update_count: 2,
///      ..defaults::blank_cell_runtime()
///    },
///   String::from("id-efg") => gradesta::CellRuntime {
///      update_count: 1,
///      ..defaults::blank_cell_runtime()
///    }
///  },
///  index: Some(String::from("foo")),
///  ..defaults::blank_service_state()
/// };
///
/// assert_eq!(old, expected);
/// ```
pub fn merge_service_states(input: &gradesta::ServiceState, old: &mut gradesta::ServiceState) {
 set_if_some![input, old,
  index,
  on_disk_state,
  user_public_key
 ];
 merge_value_maps![input, old,
  log,
  requested_user_attrs,
  user_attrs,
  service_state_modes
 ];
 for (cell_id, cell_runtime) in input.cells.clone() {
  let mut ins = false;
  match old.cells.get_mut(&cell_id) {
   Some(mut old_cell_runtime) => {
    merge_cell_runtimes(&cell_runtime, &mut old_cell_runtime);
   },
   None => {
    ins = true;
   }
  }
  if ins {
    old.cells.insert(cell_id, cell_runtime);
  }
 }
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
 if let Some(metadata) = input.metadata.clone() {
  if let Some(ref mut old_metadata) = old.metadata {
   merge_actor_metadata(&metadata, old_metadata);
  } else {
   old.metadata = input.metadata.clone();
  }
 }
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
/// # use gradestalib::defaults;
///
/// let input = gradesta::Selection {
///  name: Some(String::from("Lary")),
///  update_count: 3,
///  clients: hashmap!{
///   String::from("client-abc") => gradesta::selection::Status::Primary as i32
///  },
///  cursors: hashmap!{
///   String::from("id-abc") => gradesta::Cursor {
///      walk_tree: Some(String::from("xyz")),
///      ..Default::default()
///    }
///  },
///  ..Default::default()
/// };
///
/// let mut old = gradesta::Selection {
///  update_count: 2,
///  cursors: hashmap!{
///   String::from("id-abc") => gradesta::Cursor {
///      walk_tree: Some(String::from("lmnop")),
///      ..Default::default()
///    },
///   String::from("id-efg") => gradesta::Cursor {
///      walk_tree: Some(String::from("abc")),
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
///  cursors: hashmap!{
///   String::from("id-abc") => gradesta::Cursor {
///      walk_tree: Some(String::from("xyz")),
///      ..Default::default()
///    },
///   String::from("id-efg") => gradesta::Cursor {
///      walk_tree: Some(String::from("abc")),
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
 for (cell_id, cursor) in input.cursors.clone() {
  let mut ins = false;
  match old.cursors.get_mut(&cell_id) {
   Some(mut old_cursor) => {
    merge_cursors(&cursor, &mut old_cursor);
   },
   None => {
    ins = true;
   }
  }
  if ins {
    old.cursors.insert(cell_id, cursor);
  }
 }
}


pub fn merge_cursors(input: &gradesta::Cursor, old: &mut gradesta::Cursor) {
 set_if_some![input, old,
  walk_tree,
  cursor,
  code_completions,
  order,
  deleted
 ];
 merge_value_maps![input, old,
  var_overrides,
  selections,
  placed_symbols
 ];
}
