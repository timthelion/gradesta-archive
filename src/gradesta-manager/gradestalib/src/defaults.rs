use gradesta;
use std::collections::HashMap;

pub fn blank_cell_runtime() -> gradesta::CellRuntime {
 gradesta::CellRuntime{
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
