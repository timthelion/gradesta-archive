use gradesta;
use std::hash::Hash;
use std::collections::HashMap;

/// # Merge input map into another HashMap
/// ```
/// #[macro_use] extern crate maplit;
/// extern crate gradestalib;
/// use gradestalib::merge::merge_map;
///
/// let input = hashmap!{
///   "foo" => "bar",
///   "bin" => "baz",
/// };
/// let mut old = hashmap!{
///   "foo" => "lol",
///   "ma" =>  "pa",
/// };
///
/// merge_map(input, &mut old);
/// 
/// let result = hashmap!{
///   "foo" => "bar",
///   "bin" => "baz",
///   "ma"  => "pa",
/// };
/// assert_eq!(old, result);
/// ```

pub fn merge_map<A: Hash + Eq + Copy, B: Copy>(input: HashMap<A, B>, old: &mut HashMap<A, B>) {
 for (key, value) in input.iter() {
  old.insert(key.clone(), value.clone());
 } 
}

#[cfg(test)]
mod tests {
    #[test]
    fn other_test() {
        assert_eq!(2 + 2, 4);
    }
}
 
