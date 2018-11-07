{ //initial states
num_clients = 0
states = {}
bookmarks = []
gcells =
 {"abc":
  {"cell":{"data":"Hello world!"
  ,"dims":[{"forth":[{"cell_id":"fdg"}]}]}
  ,"edit_count":1
  ,"click_count":0}
 ,"fdg":
  {"cell":{"data":"foo"
          ,"dims":[{"back":[{"cell_id":"abc"}],"forth":[{"cell_id":"efd"}]}
                  ,{"forth":[{"cell_id":"did"}]}]}
  ,"edit_count":1
  ,"click_count":0}
 ,"efd":
  {"cell":{"data":"bar"
          ,"dims":[{"back":[{"cell_id":"fdg"}],"forth":[]}]}
  ,"edit_count":1
  ,"click_count":0}
 ,"did":
  {"cell":{"data":"blob"
          ,"dims":[{}
                  ,{"back":[{"cell_id":"fdg"}]}]}
  ,"edit_count":1
  ,"click_count":0}
}

initial_service_state = {"cells":copy(gcells)}
initial_manager_state = {"client_state":{"manager":{"metadata":{"name":"gradesta-manager-py"}}}}

states[0] =
 {"actors":
 [
  {"name":"S"
  ,"long_name":"service"
  ,"x":40
  ,"y":0
  ,"active": false
  ,"state":initial_service_state
  ,"prev_state":initial_service_state
  },

  {"name":"M"
  ,"long_name":"manager"
  ,"x":125
  ,"y":0
  ,"state":initial_manager_state
  ,"prev_state":initial_manager_state
  },

  {"name":"CM"
  ,"long_name":"client-manager"
  ,"x":sm_offset
  ,"y":-spread
  ,"state":{}
  },

  {"name":"NM"
  ,"long_name":"notification-manager"
  ,"x":sm_offset
  ,"y":spread
  ,"state":{}
  },
 ]
 ,"sockets":
 [
  {"name": "manager.gradesock"
  ,"seg": [[spread,5],[100,5]]
  ,"type": "ServiceState"}

 ,{"name": "service.gradesock"
  ,"seg": [[125,-5],[65,-5]]
  ,"type": "ServiceState"}

 ,{"name": "manager/clients.gradesock"
  ,"seg": [[sm_offset,-spread],[145,-15]]
  ,"type": "ClientState"}

 ,{"name": "manager/notifications.gradesock"
  ,"seg": [[125,0],[sm_offset-20,spread-14]]
  ,"type": "Notification"}

 ,{"name": "manager/notifications.gradesock(1)"
  ,"seg": [[sm_offset,-spread+15],[sm_offset,spread-25]]
  ,"type": "Notification"}
 ]
 ,"lines":[]
 ,"status":"Use the left/right arrow keys to navigate through the simulation."
 ,"index":0
 ,"title":""
 }
}
function copy(o){
 return JSON.parse(JSON.stringify(o));
}
var state = states[0]
function build_states() {
 s = 0
 round = 1
////////////////////////////////////////////////////
 {// helpers
 function bookmark(desc) {
  for (i in bookmarks) {
   if (bookmarks[i].text == desc) {
    return
   }
  }
  state.title = desc
  bookmarks.push({"text":desc,"index":s})
 }
 function next_state() {
  var stack =
  state.stack = new Error().stack;
  //save the old state
  states[s] = copy(state);
  // create new state as copy of old state
  s++;
  state = copy(state);
  state.index = s;
 }
 function client_center(i) {
  return sm_offset+(i)*50
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
  send("manager/notifications.gradesock(1)",{"recipients":[client]});
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
 function fulfill_selection(client, long_version) {
  send("clients/C"+client+"/manager.gradesock");
  next_state();
  state.status = "The client-manager passes the selections on to the manager.";
  send("manager/clients.gradesock");
  next_state();
  get_selection_from_service(long_version);
  state.status = "The manager can now send the cells in the selection on to the client which requested them via the notification-manager.";
  send("manager/notifications.gradesock");
  next_state();
  state.status = "The notification-manager now passes the cells onto any clients which are subscribed to the given selection.  ";
 }
 function request_selection(client, long_version) {
  state.status = "The client sends the new selections on to the client-manager.";
  fulfill_selection(client,long_version);
  if (num_clients > 1) {
   state.status += "While the newly aquired cells only get sent to the client which subscribed to the selection, if the selection is new, all clients are informed that the selection has been created, and in the case of a newly created client, the updated clients list.";
  }
  send_to_all_clients();
  next_state();
 }
 function update_selection(client,subscribers) {
  state.status = "The client sends the updated selections on to the client-manager.";
  fulfill_selection(client,false);
  send_to_clients(subscribers);
  next_state();
 }
 function get_selection_from_service(long_version) {
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
 function request_cells(cells) {
  round++;
  cellsd = {}
  for (i in cells) {
   cellsd[cells[i]] = true
  }
  msg =
   {
    "in_view": cellsd
   ,"current_round":{"request":round}
   }
  send("service.gradesock",msg);
 }
 function send_requested_cells(cells) {
  state.status = "The service sends the requested cells to the manager.";
  cellsd = {}
  for (i in cells) {
   cellsd[cells[i]] = copy(gcells[cells[i]])
  }
  msg =
   {
    "cells": cellsd
   ,"current_round":{"request":round}
   }
  respond("manager.gradesock",msg);
  for (i in state.actors) {
   if (state.actors[i].name == "M") {
    state.actors[i]["state"]["service_state"]["cells"] = Object.assign(state.actors[i]["state"]["service_state"]["cells"],cellsd)
   }
  }
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
 function set_socket_msg (socket,msg) {
  for (i in state.sockets) {
   if (state.sockets[i].name == socket) {
    state.sockets[i].msg = msg
   }
  }
 }
 function sends(sockets) {
  flicker(sockets,"sending");
 }
 function send(socket,msg) {
  set_socket_msg(socket,msg);
  flicker([socket],"sending");
  set_socket_msg(socket,null);
 }
 function send_from_client(client) {
  send("clients/C"+client+"/manager.gradesock");
 }
 function respond(socket,msg) {
  set_socket_msg(socket,msg);
  flicker([socket],"responding");
  set_socket_msg(socket,null);
 }
 function respond_to_client(client) {
  respond("clients/C"+client+"/client.gradesock");
 }
 function send_to_clients(clients) {
  client_sockets = []
  for (i in clients) {
   client_sockets.push("clients/C"+clients[i]+"/client.gradesock");
  }
  sends(client_sockets)
 }
 function send_to_all_clients() {
  clients = []
  for (i = 1; i <= num_clients; i++) {
   clients.push(i);
  }
  send_to_clients(clients)
 }
 function send_to_all_clients_with_response(client_to_respond_to) {
  c = client_to_respond_to;
  fdict = {}
  for (i = 1; i <= num_clients; i++) {
   fdict["clients/C"+i+"/client.gradesock"] = client_to_respond_to == i ? "responding" : "sending"
  }
  flicker_(fdict);
 }
 function update_actor_state(actor,f) {
  for (i in state.actors) {
   if (state.actors[i].name == actor) {
    state.actors[i]["prev_state"] = copy(state.actors[i]["state"])
    state.actors[i]["state"] = f(state.actors[i]["state"])
   }
  }
 }
 }
 {// sceenplay
 {////START
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
 state.status = "Once the manager has started it informs the service that manager is ready by sending protocol defaults to the service.";
 msg = {"on_disk_state":1
       ,"current_round":{"request":round}
       ,"cell_template":
         {
          "cell": {"encoding":1,"mime":"text/plain","dims":[{},{}]}
         ,"status": 1
         ,"cell_modes": {1:1,2:1,3:1,4:1}
         ,"link_modes": {1:1,2:1,3:1}
         }
       ,"service_state_modes":{1:1,2:1,3:2,4:1,6:2,7:2,8:2}
       ,"supported_topology":
        {
         "states":
          [
           {"forth":{"var":0,"cont_true":-1,"cont_false":-1}
           ,"back": {"var":0,"cont_true":-1,"cont_false":-1}
           ,"next_dim":1}
          ]
        ,"vars": [1]
        }
       };

 send("service.gradesock",msg);
 msg = copy(msg);

 msg = Object.assign(msg,{
        "index":"abc"
       ,"metadata":{"name":"example-service","source_url":"example.com"}
       ,"supported_encodings":{1:true,2:true}
       });

 update_actor_state("S",as => Object.assign(as,msg));

 next_state();
 update_actor_state("S",as => as);

 state.status = "The service then sends its metadata and the index pointer to the manager along with the defaults. Everything is sent back to the manager, even the defaults that the manager just sent, because the service is always the source of truth about it's state.";

 respond("manager.gradesock",msg);
 state.status = "The manager saves the service state to it's cache."
 update_actor_state("M",function(as){
  as["service_state"] = msg;
  as["service_state"]["cells"] = {};
  return as});
 next_state();
 update_actor_state("M",as => as);
 next_state();

 state.status = "The manager now constructs the default index selection and requests the cells in the index stack from the service.";
 update_actor_state("M", function(as){
   as["client_state"]["selections"] = {};
   as["client_state"].selections["index"] =
    {"name":"Index"
    ,"update_count":1
    ,"cursors":[
      {"name":""
      ,"cell":"abc"
      ,"los":
       {"states":[
          {"forth":
           {0:{"var":0
              ,"cont_true":0
              ,"cont_false":-1
           }}}]
       ,"vars":[1000,0]
       }
      }]
    ,"clients": {}
    };
   return as;
   });
 next_state();
 update_actor_state("M",as => as);
 bookmark("Getting the cells seen by the default index selection")
 request_cells(["abc"]);
 update_actor_state("S", function(as){
  as.in_view = {"abc":true};
  return as;
  });
 next_state();
 update_actor_state("S",as => as);
 send_requested_cells(["abc"]);
 next_state();
 state.status = "Update selection LOS to contain new state machines.";
 update_actor_state("M", function(as){
  as.client_state.selections.index.cursors[0].los.state_tree = {};
  as.client_state.selections.index.cursors[0].los.state_tree =
   ["abc"
   ,{"forth": {}
    ,"back": {}
    ,"current_state":0
    ,"vars":[1000,0]}];
  return as;
  });
 next_state();
 update_actor_state("M",as => as);
 state.status = "The manager looks at the newly received cells, and requests neighbors from the service in acordance with the given cursor's LineOfSight state-machines.";
 request_cells(["fdg"]);
 update_actor_state("S", function(as){
  as.in_view["fdg"] = true;
  return as;
  });
 next_state();
 update_actor_state("S",as => as);
 send_requested_cells(["fdg"]);
 state.status = "The manager looks at the newly received cells, and requests neighbors from the service in acordance with the given cursor's LineOfSight state-machines.";
 update_actor_state("M", function(as){
  as.client_state.selections.index.cursors[0].los.state_tree[1]["forth"][0] =
   ["fdg"
   ,{"forth": {}
    ,"back": {}
    ,"current_state":0
    ,"vars":[999,0]}];
  return as;
  });
 next_state();
 update_actor_state("M",as => as);
 request_cells(["efd"]);
 update_actor_state("S", function(as){
  as.in_view["efd"] = true;
  return as;
  });
 next_state();
 update_actor_state("S",as => as);

 send_requested_cells(["efd"]);
 update_actor_state("M", function(as){
  as.client_state.selections.index.cursors[0].los.state_tree[1]["forth"][0][1]["forth"][0] =
   ["efd"
   ,{"forth": {}
    ,"back": {}
    ,"current_state":0
    ,"vars":[998,0]}];
  return as;
  });
 next_state();
 bookmark("The service and manager in their ready state");
 state.status = "The manager and service are now ready and await connections from clients.";
 update_actor_state("M",as => as);
 next_state();
 state.status = "In the ready state, it is possible that the service will send updates to the manager.";
 update_actor_state("S", function(as){
  as.cells["efd"].cell.data = "Asdf!";
  as.cells["efd"].edit_count++;
  return as;
  });
 next_state();
 update_actor_state("S",as => as);
 state.status = "For example, here the efd cell's data feild has been changed to \"Asdf!\" and that change is passed on to the manager. (If an out of view cell had changed, the change would not be passed on). Note that there is no current_round feild. Rounds are only used when messages are being sent in the direction of the service, and there is the expectation that the round will be \"completed\" by the service's reply.";
 send("manager.gradesock",{"cells":{"efd":{"cell":{"data":"Asdf!"},"edit_count":2}}});
 update_actor_state("M", function(as){
  as.service_state.cells["efd"].cell.data = "Asdf!";
  as.service_state.cells["efd"].edit_count = 2;
  return as;
  });
 next_state();
 state.status = "The service/manager are again in their ready state.";
 update_actor_state("M",as => as);
 next_state();
 ////
 }
 {// Adding clients
 bookmark("Client connection");
 add_client();
 bookmark("Adding a second client");
 add_client();
 bookmark("Adding a third client");
 add_client();
 }
 {// Working with selections
 bookmark("Creating a selection");
 request_selection(2,true);

 bookmark("Subscribing to selections");
 state.status = "When a client subscribes to an existing selection, the manager will already have cached versions of the cells viewed by that selection. The manager can send these cells to the new subscriber without contacting the service. The other clients which are subscribed to the same selection will also be informed of the new subscriber. For example, if C2 has a selection and C1 subscribes to it, C1 will be sent the cells which are viewed by the selection, along with the selection metadata and C2 will be sent the updated subscribers list.";
 send_from_client(1);
 send("manager/clients.gradesock");
 send("manager/notifications.gradesock");
 flicker_({"clients/C1/client.gradesock":"sending","clients/C2/client.gradesock":"sending"});
 next_state();

 bookmark("Moving cursors");
 update_selection(2,[1,2]);
 }
 {// Changing the service state client side
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
 }
 { // setting client metadata
 bookmark("Changing client metadata");
 state.status = "While it is not typical that client metadata would change at runtime, it is not forbiden either. If a client changes its metadata, this change will be broadcast to all clients.";
 send_from_client(1);
 send("manager/clients.gradesock");
 send("manager/notifications.gradesock");
 send_to_all_clients();
 next_state();
 }
 {// service originated events
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
 }
 // Rounds and race conditions
 bookmark("Rounds and race conditions");
 }
}
build_states();
