extern crate prost_build;
use std::process::Command;

fn main() {
 Command::new("python3").args(&["compile_state_machine.py"]).status().expect("Failed to compile state machine"); 
 prost_build::compile_protos(
  &["../../gradesta.proto"],
  &["../../"]).unwrap();
}
