use std::env;
use std::process::Command;

fn main() {
 match env::var("HOME") {
  Ok(home) => {
   Command::new(format!("{}/.cargo/bin/pb-rs", home))
           .args(&["../../gradesta.proto"])
           .output()
           .expect("failed to compile protobuf file with pb-rs");
           ()
  },
  Err(e) =>
   println!("$HOME not configured correctly {}", e),
 }
}
