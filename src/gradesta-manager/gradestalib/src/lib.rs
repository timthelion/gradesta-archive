#[macro_use] extern crate maplit;
extern crate prost;
#[macro_use] extern crate prost_derive;

pub mod gradesta {
 include!(concat!(env!("OUT_DIR"), "/gradesta.rs"));
}

pub mod state_machine {
 include!(concat!(env!("OUT_DIR"), "/state-machine.rs"));
}

pub mod merge;
pub mod state_machine;
pub mod defaults;

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}
