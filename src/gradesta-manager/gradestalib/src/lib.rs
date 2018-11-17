#[macro_use] extern crate maplit;
extern crate quick_protobuf;
pub mod merge;
pub mod gradesta;

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}
