#[macro_use] extern crate maplit;
extern crate prost;
#[macro_use] extern crate prost_derive;

pub mod gradesta {
 include!(concat!(env!("OUT_DIR"), "/gradesta.rs"));
}

pub mod merge;

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}
