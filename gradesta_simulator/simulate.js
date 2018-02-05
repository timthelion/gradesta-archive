middle = 100
spread = 50
sm_offset = 200
active = "black"
inactive = "lightgrey"
sending = "red"
responding = "green"
t = 0
num_clients = 0

function client_center(i) {
 return sm_offset+(i)*50
}

states = {}
bookmarks = []

states[0] =
 {"actors":
 [
  {"name":"S"
  ,"x":40
  ,"y":0
  ,"active": t>1},

  {"name":"M"
  ,"x":125
  ,"y":0},

  {"name":"CM"
  ,"x":sm_offset
  ,"y":-spread},

  {"name":"NM"
  ,"x":sm_offset
  ,"y":spread},
 ]
 ,"sockets":
 [ 
  {"name": "manager.gradesock"
  ,"seg": [[spread,5],[100,5]]}

 ,{"name": "service.gradesock"
  ,"seg": [[125,-5],[65,-5]]}

 ,{"name": "manager/clients.gradesock"
  ,"seg": [[sm_offset,-spread],[145,-15]]}

 ,{"name": "manager/notifications.gradesock"
  ,"seg": [[125,0],[sm_offset-20,spread-14]]}

 ,{"name": "manager/notifications.gradesock(1)"
  ,"seg": [[sm_offset,-spread+15],[sm_offset,spread-25]]}
 ]
 ,"lines":[]
 ,"status":"Use the left/right arrow keys to navigate through the simulation."
 ,"index":0
 ,"title":""
 }

var svg = d3.selectAll("svg");
var socket = svg.selectAll(".socket")
var line = svg.selectAll(".port")
var actor = svg.selectAll(".actor")
var actor_label = svg.selectAll(".actor-label")

function tchange(event){
 if (d3.event.keyCode == 37 && t > 0){
  t--;
  update();
 }else if (d3.event.keyCode == 39){
  t++;
  if(!states[t]){
   t--;
  }
  update();
 }
}

var state = states[0]
function build_states() {
 s = 0
 function bookmark(desc) {
  state.title = desc
  for (i in bookmarks) {
   if (bookmarks[i].text == desc) {
    return
   }
  }
  bookmarks.push({"text":desc,"index":s})
 }
 function next_state() {
  //save the old state
  states[s] = state
  // create new state as copy of old state
  s++;
  state = JSON.parse(JSON.stringify(state))
  state.index = s
 }

 function activate_actor(a) {
  for (i in state.actors) {
   if (state.actors[i].name == a) {
    state.actors[i].active = true
   }
  }
 }
 function activate_socket(s) {
  for (i in state.sockets) {
   if (state.sockets[i].name == s) {
    state.sockets[i].active = true
   }
  }
 }
 function add_client() {
  state.status = "When a client launches, it binds its clients/<client-id>/client.gradesock and manager.gradesock sockets and waits.";
  num_clients++;
  x = client_center(num_clients)
  state.lines = [{
    "name": "clients/<client-id>/manager.gradesock"
   ,"height": -spread
   ,"start": sm_offset + 15
   ,"end": x
   ,"active": true
   }
  
  ,{"name": "clients/<client-id>/client.gradesock"
   ,"height": spread
   ,"start": sm_offset + 15
   ,"end": x 
   ,"active": true
   }]
  client = "C"+num_clients
  state.actors.push({"name":client,"x": x,"y":0,"active":true})
  state.sockets.push({"name":"clients/"+client+"/manager.gradesock","seg":[[x,0],[x,-spread+6]],"active":true})
  state.sockets.push({"name":"clients/"+client+"/client.gradesock","seg":[[x,spread],[x,24]],"active":true})
  next_state();
  state.status = "The client-mananger sees, via a file system watcher, the new manager.gradesock socket and connects to that socket.";
  next_state();
  state.status = "The client-manager then sends a blank welcome message to the client via the notification-manager.";
  send("manager/notifications.gradesock(1)");
  next_state();
  state.status = "The notification manager registers the new client and sends the blank wecome message on to the client.";
  send("clients/"+client+"/client.gradesock");
  next_state();
  state.status = "The client then sends its metadata to the client-manager.";
  send("clients/"+client+"/manager.gradesock");
  next_state();
  state.status = "The client-manager passes that metadata on to the manager."
  send("manager/clients.gradesock");
  next_state();
  state.status = "The manager then sends its own metadata, along with bookmarks, service meta data, selections data, and client data to the notifications manager."
  send("manager/notifications.gradesock");
  next_state();
  state.status = "And the notifications-manager then passes that on to the client.";
  send("clients/"+client+"/client.gradesock");
  next_state();
  state.status = "The client then looks at the bookmarks and creates some selections/cursors";
  next_state();
  request_selection(client); 
 }

 function request_selection(client) {
  bookmark("Request selection");
  state.status = "The client sends updated selections on to the client-manager.";
  send("clients/"+client+"/manager.gradesock");
  next_state();
  state.status = "The client-manager passes the selections on to the manager.";
  send("manager/clients.gradesock");
  next_state();
  bookmark("The manager requests a selection from the service")
  state.status = "The manager requests the center cell of each selection from the service.";
  send("service.gradesock");
  next_state();
  send_requested_cells();
  next_state();
  request_cells();
  next_state();
  send_requested_cells();
  next_state();
  request_cells();
  next_state();
  send_requested_cells();
  next_state();
  bookmark("Interuptions to rounds with changes sent by the service");
  state.status = "While the manager is trying to fulfill a requested selection the service may update the graph and inform the manager of the update."
  send("manager.gradesock");
  next_state();
  state.status = "If the topology of the part of the graph that the current selection belongs to changed, this may mean that previously requested 'rings' around the cursor may need to be requested again.";
  next_state();
  request_cells();
  next_state();
  send_requested_cells();
  next_state();
  request_cells();
  next_state();
  send_requested_cells();
  next_state();
  state.status = "Unless the graph's topology changes too quickly for the manager to keep up, however, the manager will eventually be able to gather all cells within range of the requested cursors.";
  next_state();
  bookmark("Sending the client the cells in the requested selection");
  state.status = "The manager can now send the cells in the selection on to the client which requested them via the notification-manager.";
  send("manager/notifications.gradesock");
  next_state();
  state.status = "The notification-manager now passes the cells onto any clients which are subscribed to the given selection.";
  respond("clients/"+client+"/client.gradesock");
  next_state();
 }

 function request_cells() {
  state.status = "The manager looks at the newly received cells and requests their neighbors from the service."; 
  send("service.gradesock");
 }

 function send_requested_cells() {
  state.status = "The service sends the requested cells to the manager.";
  respond("manager.gradesock");
 }

 function flicker(sockets, attr) {
  console.log(sockets);
  for (i in state.sockets) {
   if (sockets.includes(state.sockets[i].name)) {
    state.sockets[i][attr] = true;
   }
  } 
  next_state();
  for (i in state.sockets) {
   if (sockets.includes(state.sockets[i].name)) {
    state.sockets[i][attr] = false;
   }
  }  
 }

 function sends(sockets) {
  flicker(sockets,"sending");
 }

 function send(socket) {
  flicker([socket],"sending");
 }
 function respond(socket) {
  flicker([socket],"responding");
 }
 function send_to_all_clients() {
  clients = []
  for (i = 1; i <= num_clients; i++) {
   clients.push("clients/C"+i+"/client.gradesock");
  }
  sends(clients)
 }
 ////
 bookmark("Startup");
 next_state();
 activate_actor("S")
 activate_socket("service.gradesock")
 state.status = "When the service starts up it binds the service.gradesock socket."
 ////
 next_state();
 activate_actor("M")
 activate_socket("manager.gradesock")
 state.status = "It then launches the manager which binds its own manager.gradesock socket"
 ////
 next_state();
 activate_socket("manager/notifications.gradesock")
 activate_socket("manager/clients.gradesock")
 state.status = "The manager also binds manager/notifications.gradesock and manager/clients.gradesock"
 ////
 next_state();
 activate_actor("NM");
 activate_actor("CM");
 activate_socket("manager/notifications.gradesock(1)");
 state.status = "The manager then launches its subcomponents, the client-manager and the notification-manager.";
 next_state();
 //// 
 state.status = "Once the manager has started it informs the service that manager is ready and sends its metadata.";
 send("service.gradesock");
 state.status = "The service then sends its metadata and bookmarks to manager.";
 respond("manager.gradesock");
 next_state();
 state.status = "It is possible that while the manager is still waiting for clients to connect, the service will send updates to bookmarks to the manager, which the manager then caches.";
 send("manager.gradesock");
 ////
 bookmark("Client connection");
 add_client();
 bookmark("Adding a second client");
 add_client();
 bookmark("Adding a third client");
 add_client();
 bookmark("Changing a cell service side");
 state.status = "If a cell is changed by the service, that change needs to be propogated to the clients.";
 next_state();
 state.status = "First, the changed cell is sent to the manager.";
 send("manager.gradesock");
 next_state();
 state.status = "The manager first checks to see if by changing the cell, graph topoligy has changed as to bring previously out of view cells into view.";
 next_state();
 state.status = "If previously out of view cells have been brought into view, the manager requests them.";
 send("service.gradesock");
 next_state();
 respond("manager.gradesock");
 next_state();
 state.status = "The newly in view cells may point to other cells which also need to be requested.";
 send("service.gradesock");
 next_state();
 respond("manager.gradesock");
 state.status = "Once the manager is satisfied, it determines which cells can be seen by which clients, and sends the changes on to the notification-manager.";
 send("manager/notifications.gradesock");
 state.status = "The notification manager then passon the cells to the clients for whom the changes are relevant."
 sends(["clients/C1/client.gradesock","clients/C3/client.gradesock"]); 
 next_state();
 bookmark("Setting bookmarks service side");
 state.status = "When the service sets a bookmark it sends the complete bookmarks list to the manager";
 send("manager.gradesock");
 state.status = "Which sends them on to the notification manager";
 send("manager/notifications.gradesock");
 state.status = "Which sends them on to all clients";
 send_to_all_clients();
 next_state();
 state.status = "The same procedure applies for service side updates to the service error_log and cell_template.";
 next_state();
 bookmark("Setting a cell client side");
 state.status = "";
}
build_states();
console.log(states)
console.log(bookmarks);

function update_t(time){
 t = time;
 update();
}

function update() {
console.log(t)
line = svg.selectAll(".port");//Don't know why this is needed. Don't care either. It works.
line.data([]).exit().remove();
line = svg.selectAll(".port");
line
 .data(states[t].lines)
 .enter()
 .append("line")
 .attr("class", "port")
 .attr("stroke-width", 4)
 .attr("stroke", d => d.active ? active : inactive)
 .attr("x1", d => d.start)
 .attr("y1", d => d.height+middle)
 .attr("x2", d => d.end)
 .attr("y2", d => d.height+middle);

socket = svg.selectAll(".socket");
socket.data([]).exit().remove();
socket = svg.selectAll(".socket");
socket
 .data(states[t].sockets)
 .enter()
 .append("line")
 .attr("class", "socket")
 .attr("stroke-width", 1)
 .attr("x1", d => d.seg[0][0])
 .attr("y1", d => d.seg[0][1]+middle)
 .attr("x2", d => d.seg[1][0])
 .attr("y2", d => d.seg[1][1]+middle)
 .attr("stroke", d => d.active ? (d.sending ? sending : (d.responding ? responding :active)) : inactive)
 .attr("marker-end", d => d.active ? (d.sending ? "url(#sending-triangle)" : (d.responding ? "url(#responding-triangle)" : "url(#active-triangle)")) : "url(#inactive-triangle)");

socket.data(states[t].sockets).exit().remove();

actor = svg.selectAll(".actor")
actor.data([]).exit().remove();
actor = svg.selectAll(".actor")
actor
 .data(states[t].actors)
 .enter()
 .append("circle")
 .attr("class","actor")
 .attr("r",18)
 .attr("cy", d => middle+d.y)
 .attr("cx", d => d.x)
 .attr("fill", d => d.active ? active : inactive);
actor.data(states[t].actors).exit().remove();

svg.selectAll(".actor-label")
 .data([]).exit().remove();
svg.selectAll(".actor-label")
 .data(states[t].actors)
 .enter()
 .append("text")
 .attr("class","actor-label")
 .attr("text-anchor","middle")
 .attr("style","fill:white;")
 .attr("stroke-width","2px")
 .attr("dy",".3em")
 .text(d => d.name)
 .attr("x",d => d.x)
 .attr("y",d => middle+d.y);

d3.selectAll(".status-label")
 .data([]).exit().remove();
d3.select("body").selectAll(".status-label")
 .data([states[t].status])
 .enter()
 .append("p")
 .attr("class","status-label")
 .text(d => d);

svg.selectAll(".index")
 .data([]).exit().remove();
svg.selectAll(".index")
 .data([states[t].index])
 .enter()
 .append("text")
 .attr("class","index")
 .attr("text-anchor","middle")
 .attr("style","fill:black;")
 .attr("stroke-width","2px")
 .attr("dy",".3em")
 .text(d => d)
 .attr("x", 20)
 .attr("y",10);

svg.selectAll(".title")
 .data([]).exit().remove();
svg.selectAll(".title")
 .data([states[t].title])
 .enter()
 .append("text")
 .attr("class","title")
 .attr("style","fill:black;")
 .attr("style","font-weight:bold;")
 .attr("dy",".3em")
 .text(d => d)
 .attr("x", 40)
 .attr("y",10);


d3.selectAll(".bookmark")
 .data([]).exit().remove();

d3.select("body").selectAll(".bookmark")
 .data(bookmarks)
 .enter()
 .append("p")
 .attr("class","bookmark")
 .text(d => "→ "+d.text)
 .attr("onclick",d => "update_t("+d.index+")")
 .attr("style",d => d.index == t ? "font-weight:bold;" : (d.index < t ? "font-style:italic;":"font-weight:normal;"));
}

//arrow http://jsfiddle.net/igbatov/v0ekdzw1/
svg.append("svg:defs").append("svg:marker")
    .attr("id", "inactive-triangle")
    .attr("refX", 6)
    .attr("refY", 6)
    .attr("markerWidth", 30)
    .attr("markerHeight", 30)
    .attr("markerUnits","userSpaceOnUse")
    .attr("orient", "auto")
    .append("path")
    .attr("d", "M 0 0 12 6 0 12 3 6")
    .style("fill", inactive);

svg.append("svg:defs").append("svg:marker")
    .attr("id", "active-triangle")
    .attr("refX", 6)
    .attr("refY", 6)
    .attr("markerWidth", 30)
    .attr("markerHeight", 30)
    .attr("markerUnits","userSpaceOnUse")
    .attr("orient", "auto")
    .append("path")
    .attr("d", "M 0 0 12 6 0 12 3 6")
    .style("fill", active);

svg.append("svg:defs").append("svg:marker")
    .attr("id", "sending-triangle")
    .attr("refX", 6)
    .attr("refY", 6)
    .attr("markerWidth", 30)
    .attr("markerHeight", 30)
    .attr("markerUnits","userSpaceOnUse")
    .attr("orient", "auto")
    .append("path")
    .attr("d", "M 0 0 12 6 0 12 3 6")
    .style("fill", sending);

svg.append("svg:defs").append("svg:marker")
    .attr("id", "responding-triangle")
    .attr("refX", 6)
    .attr("refY", 6)
    .attr("markerWidth", 30)
    .attr("markerHeight", 30)
    .attr("markerUnits","userSpaceOnUse")
    .attr("orient", "auto")
    .append("path")
    .attr("d", "M 0 0 12 6 0 12 3 6")
    .style("fill", responding);

update();

d3.select('body')
   .on("keydown", tchange);
