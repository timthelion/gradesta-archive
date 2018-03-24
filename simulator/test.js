tests = [["actors[0].name"],
["sockets[1].active"],
["sockets[0].active"],
["sockets[2].active","sockets[3].active"],
["sockets[4].active"],
["sockets[1].msg"],
["actors[0].state.on_disk_state"],
["sockets[0].msg.current_round.request == 1"],
["actors[1].state.service_state.on_disk_state"],
["actors[1]"],
["actors[1].state.client_state.selections.index"],
["sockets[1].msg.in_view.abc"],
["actors[0].state.in_view.abc"],
["sockets[0].msg.cells.abc"],
["actors[1].state.service_state.cells.abc"],
]

for (t in tests) {
 for (i in tests[t]) {
  try {
   test = "states["+t+"]."+tests[t][i]
   console.log("running test: " + test)
   states[t]["passed"] = eval(test)
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
