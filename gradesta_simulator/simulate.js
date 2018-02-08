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
  ,"long_name":"service"
  ,"x":40
  ,"y":0
  ,"active": t>1},

  {"name":"M"
  ,"long_name":"manager"
  ,"x":125
  ,"y":0},

  {"name":"CM"
  ,"long_name":"client-manager"
  ,"x":sm_offset
  ,"y":-spread},

  {"name":"NM"
  ,"long_name":"notification-manager"
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
  state.status = "When a client launches, it binds its clients/<client-id>/client.gradesock and clients/<client-id>/manager.gradesock sockets and waits.";
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
  state.actors.push({"name":client,"long_name":"client"+num_clients,"x": x,"y":0,"active":true})
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
  state.status = "The client then sends its metadata to the client-manager and subscribes itself to the default index selection (in most cases).";
  send("clients/"+client+"/manager.gradesock");
  next_state();
  state.status = "The client-manager passes that metadata and subscription on to the manager."
  send("manager/clients.gradesock");
  next_state();
  state.status = "The manager then sends its own metadata, along with the index pointer, service meta data, selections data, client data and default-index-selection-cells to the notifications manager."
  send("manager/notifications.gradesock");
  next_state();
  state.status = "The notifications-manager then passes that on to the client.";
  if (num_clients > 1) {
   state.status += " Simultaneously, all other clients are sent the metadata for the newly created client.";
  }
  send_to_all_clients();
  next_state();
 }

 function request_selection(client, long_version) {
  bookmark("Request selection");
  state.status = "The client sends updated selections on to the client-manager.";
  send("clients/C"+client+"/manager.gradesock");
  next_state();
  state.status = "The client-manager passes the selections on to the manager.";
  send("manager/clients.gradesock");
  next_state();
  get_selection_from_service(long_version);
  bookmark("Sending the client the cells in the requested selection");
  state.status = "The manager can now send the cells in the selection on to the client which requested them via the notification-manager.";
  send("manager/notifications.gradesock");
  next_state();
  state.status = "The notification-manager now passes the cells onto any clients which are subscribed to the given selection.  ";
  if (num_clients > 1) {
   state.status += "While the newly aquired cells only get sent to the client which subscribed to the selection, if the selection is new, all clients are informed that the selection has been created, and in the case of a newly created client, the updated clients list.";
  } 
  send_to_all_clients_with_response(client);
  next_state();

 }

 function get_selection_from_service(long_version) {
  bookmark("Getting the cells seen by a selection from the service")
  state.status = "The manager requests the center cell of the selection from the service.";
  send("service.gradesock");
  next_state();
  send_requested_cells();
  next_state();
  request_cells();
  next_state();
  send_requested_cells();
  next_state();
  if (long_version) {
   request_cells();
   next_state();
   send_requested_cells();
   next_state();
   bookmark("Interuptions to rounds with changes sent by the service");
   state.status = "While the manager is trying to fulfill a requested selection the service may update the graph and inform the manager of the update."
   send("manager.gradesock");
   next_state();
   state.status = "If the topology of the graph has changed, this may mean that previously requested 'rings' around some cursors may need to be requested again.";
   next_state();
   request_cells();
   next_state();
   send_requested_cells();
   next_state();
  }
  request_cells();
  next_state();
  send_requested_cells();
  next_state();
  state.status = "Unless the graph's topology changes too quickly for the manager to keep up, the manager will eventually be able to gather all cells within range of the requested cursors.";
  next_state();
 }

 function request_cells() {
  state.status = "The manager looks at the newly received cells, and requests neighbors from the service in acordance with the given cursor's LineOfSight state-machines."; 
  send("service.gradesock");
 }

 function send_requested_cells() {
  state.status = "The service sends the requested cells to the manager.";
  respond("manager.gradesock");
 }

 function flicker_(fdict) {
  function set_flag(value) {
   for (i in state.sockets) {
    for (sock in fdict) {
     if (sock == state.sockets[i].name) {
      state.sockets[i][fdict[sock]] = value;
     }
    }
   }
  } 
  set_flag(true);
  next_state();
  set_flag(false);
 }

 function flicker(sockets, attr) {
  fdict = {}
  for (i in sockets) {
   fdict[sockets[i]] = attr
  }
  flicker_(fdict);
 }

 function sends(sockets) {
  flicker(sockets,"sending");
 }

 function send(socket) {
  flicker([socket],"sending");
 }
 function send_from_client(client) {
  send("clients/C"+client+"/manager.gradesock");
 }
 function respond(socket) {
  flicker([socket],"responding");
 }
 function respond_to_client(client) {
  respond("clients/C"+client+"/client.gradesock");
 }
 function send_to_all_clients() {
  clients = []
  for (i = 1; i <= num_clients; i++) {
   clients.push("clients/C"+i+"/client.gradesock");
  }
  sends(clients)
 }
 function send_to_all_clients_with_response(client_to_respond_to) {
  c = client_to_respond_to;
  fdict = {}
  for (i = 1; i <= num_clients; i++) {
   fdict["clients/C"+i+"/client.gradesock"] = client_to_respond_to == i ? "responding" : "sending"
  }
  console.log(fdict);
  flicker_(fdict);
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
 state.status = "Once the manager has started it informs the service that manager is ready by sending its metadata.";
 send("service.gradesock");
 state.status = "The service then sends its metadata and the index pointer to the manager.";
 respond("manager.gradesock");
 next_state();
 state.status = "The manager now constructs the default index selection and requests the cells in the index stack from the service.";
 next_state();
 get_selection_from_service(false); 
 bookmark("The service and manager in their ready state");
 state.status = "The manager and service are now ready and await connections from clients.";
 next_state();
 state.status = "It is possible that while the manager is still waiting for clients to connect, the service will send updates to the index/pointer and or cells in the index tack to the manager. The manager updates its cache. If graph topology has changed the manager may also need to request more cells from the index stack, or inform the service that some cells have gone out of view.";
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
 state.status = "The notification manager then passon the cells to the clients who's selections view the changed cells."
 sends(["clients/C1/client.gradesock","clients/C3/client.gradesock"]); 
 next_state();
 bookmark("Setting the index pointer service side");
 state.status = "When the service sets the index pointer it sends the updated pointer to the manager";
 send("manager.gradesock");
 state.status = "Which sends them on to the notification manager";
 send("manager/notifications.gradesock");
 state.status = "Which sends them on to all clients";
 send_to_all_clients();
 next_state();
 state.status = "The same procedure applies for service side updates to the service error_log and cell_template.";
 next_state();
 bookmark("Setting service state fields client side");
 state.status = "When a client sets service state fields such as the index pointer and cells, it passes the changes to the client-manager.";
 send("clients/C1/manager.gradesock");
 state.status = "The source of truth about the service state is the service itself. Therefore, the client-manager does NOT send these changes directly to the clients via the notification-manager, but rather sends them first to the manager.";
 send("manager/clients.gradesock");
 state.status = "The manager then sends the changes on to the service. Which then accepts/rejects/modifies them and sends them (potentially along with a series of unrelated changes) back to the manager.";
 send("service.gradesock");
 respond("manager.gradesock");
 state.status = "If these changes effected graph topology, the manager will send more requests on to the service untill satisfied. Otherwise, it sends the changes on to the notification-manager.";
 send("manager/notifications.gradesock");
 state.status = "If the index pointer has changed, the notification manager will forward the change on to all clients.";
 send_to_all_clients_with_response(1);
 next_state(); 
 bookmark("When client side changes are rejected by the service");
 state.status = "Sometimes, client side changes will be rejected by the service.";
 next_state(); 
 state.status = "When this happens, the client which originated the request should still be passed back the Round object which it origionally sent along with any error string the service might have set. That way it will know that its change request was rejected.";
 next_state();
 send("clients/C2/manager.gradesock");
 next_state();
 send("manager/clients.gradesock");
 next_state();
 send("service.gradesock");
 next_state();
 respond("manager.gradesock");
 next_state();
 send("manager/notifications.gradesock");
 next_state();
 state.status = "Request objects need only be sent to the client_of_origin.";
 respond_to_client(2);
 next_state();
 bookmark("Setting cells client side");
 state.status = "When setting only cells, the patern differs slightly, in that only clients who's selections can see the modified cells are informed of the change.";
 send_from_client(2);
 next_state();
 send("manager/clients.gradesock");
 next_state();
 send("service.gradesock");
 next_state();
 respond("manager.gradesock");
 next_state();
 send("manager/notifications.gradesock");
 next_state();
 flicker_({"clients/C1/client.gradesock":"sending","clients/C2/client.gradesock":"responding"});
 next_state();
 request_selection(2,true);
 bookmark("Moving cursors TODO");
 bookmark("Subscribing to selections");
 state.status = "When a client subscribes to an existing selection, the manager will already have cached versions of the cells viewed by that selection. The manager can send these cells to the new subscriber without contacting the service. The other clients which are subscribed to the same selection will also be informed of the new subscriber. For example, if C2 has a selection and C1 subscribes to it, C1 will be sent the cells which are viewed by the selection, along with the selection metadata and C2 will be sent the updated subscribers list.";
 send_from_client(1);
 send("manager/clients.gradesock");
 send("manager/notifications.gradesock");
 flicker_({"clients/C1/client.gradesock":"responding","clients/C2/client.gradesock":"sending"});
 next_state(); 
 bookmark("Changing client metadata");
 state.status = "While it is not typical that client metadata would change at runtime, it is not forbiden either. If a client changes its metadata, this change will be broadcast to all clients.";
 send_from_client(1);
 send("manager/clients.gradesock");
 send("manager/notifications.gradesock");
 send_to_all_clients_with_response(1); 
 next_state();
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
 .attr("marker-end", d => d.active ? (d.sending ? "url(#sending-triangle)" : (d.responding ? "url(#responding-triangle)" : "url(#active-triangle)")) : "url(#inactive-triangle)")
 .append("title").text(d => d.name);

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
 .attr("fill", d => d.active ? active : inactive)
 .append("title").text(d => d.long_name);
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
 .attr("y",d => middle+d.y)
 .append("title").text(d => d.long_name);

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

d3.selectAll(".bookmarks-heading")
 .data([]).exit().remove();
d3.select("body").selectAll(".bookmarks-heading")
 .data([""])
 .enter()
 .append("h3")
 .attr("class","bookmarks-heading")
 .text("Chapters");

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
