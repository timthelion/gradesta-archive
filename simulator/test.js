tests = [["actors[0].name"],
["sockets[1].active"],
["sockets[0].active"],
["sockets[2].active","sockets[3].active"],
["sockets[4].active"],
["sockets[1].msg"],
["actors[0].state.on_disk_state"],
["sockets[0].msg.current_round.request == 1"],
["actors[1].state.service_state.on_disk_state"],
[],
["actors[1].state.client_state.selections.index"],
["sockets[1].msg.in_view.abc"],
["actors[0].state.in_view.abc"],
["sockets[0].msg.cells.abc"],
["actors[1].state.service_state.cells.abc"],
["actors[1].state.client_state.selections.index.cursors[0].los.state_tree[0] == 'abc'"],
["sockets[1].msg.in_view.fdg"],
["actors[0].state.in_view.fdg"],
["sockets[0].msg.cells.fdg"],
["actors[1].state.client_state.selections.index.cursors[0].los.state_tree[1].forth[0][0] == 'fdg'"],
["sockets[1].msg.in_view.efd"],
["actors[0].state.in_view.efd"],
["sockets[0].msg.cells.efd"],
["actors[1].state.client_state.selections.index.cursors[0].los.state_tree[1].forth[0][1].forth[0][0] == 'efd'"],
[],
["actors[0].state.cells.efd.cell.data == \"Asdf!\""],
["sockets[0].msg.cells.efd"],
["actors[1].state.service_state.cells.efd.cell.data == \"Asdf!\""],
[],
["actors[4]"],
[],
["sockets[4].msg.recipients[0] == \"C1\""],
[]
]

for (t in tests) {
 if (tests[t].length == 0) {
  states[t]["passed"] = true;
 }
 for (i in tests[t]) {
  try {
   test = "states["+t+"]."+tests[t][i]
   console.log("running test: " + test)
   states[t]["passed"] = eval(test)
   try {
    test_on_prev_state = "states["+(t-1)+"]."+tests[t][i]
    if (eval(test_on_prev_state)) {
     states[t]["passed"] = false
    }
   } catch (err) {

   }
   console.log(states[t]["passed"])
   if (!states[t]["passed"]) {
    break
   }
  } catch (err) {
   console.log(err)
   states[t]["passed"] = false
   break
  }
 }
}
