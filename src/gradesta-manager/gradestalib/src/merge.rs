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
/// # use gradestalib::merge::merge_cell_runtime;
/// # use gradestalib::gradesta;
/// # use gradestalib::defaults;
///
/// let input = gradesta::CellRuntime{
///  update_count: Some(3),
///  click_count: Some(2),
///  cell_runtime_modes: hashmap!{
///   2 => gradesta::Mode{
///    read: true,
///    write: false,
///    executable: false,
///    dynamic: false,
///   }
///  },
/// ..defaults::blank_cell_runtime()
/// };
/// let mut old = gradesta::CellRuntime{
///  update_count: Some(2),
///  click_count: Some(1),
///  creation_id: Some(String::from("foo")),
///  cell_runtime_modes: hashmap!{
///   1 => gradesta::Mode{
///    read: true,
///    write: true,
///    executable: false,
///    dynamic: false,
///   }
///  },
/// ..defaults::blank_cell_runtime()
/// };
///
/// merge_cell_runtime(&input, &mut old);
/// 
/// let result = gradesta::CellRuntime{
///  update_count: Some(3),
///  click_count: Some(2),
///  creation_id: Some(String::from("foo")),
///  cell_runtime_modes: hashmap!{
///   1 => gradesta::Mode{
///    read: true,
///    write: true,
///    executable: false,
///    dynamic: false,
///   },
///   2 => gradesta::Mode{
///    read: true,
///    write: false,
///    executable: false,
///    dynamic: false,
///   }
///  },
/// ..defaults::blank_cell_runtime()
/// };
///
/// assert_eq!(old, result);
/// ```
pub fn merge_cell_runtime(input: &gradesta::CellRuntime, old: &mut gradesta::CellRuntime) {
 set_if_some![input, old,
  cell,
  update_count, 
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

#[cfg(test)]
mod tests {
    #[test]
    fn other_test() {
        assert_eq!(2 + 2, 4);
    }
}
 
