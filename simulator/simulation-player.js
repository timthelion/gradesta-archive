t = 0
var url = new URL(window.location.href)
t_ = url.searchParams.get("state")
if (t_) {
 t = Number(t_)
}
active_tab = ""
tab_ = url.searchParams.get("tab")
if (tab_) {
 active_tab = tab_;
 $.tab('change tab', active_tab);
}
var svg = d3.selectAll("svg");
var socket = svg.selectAll(".socket")
var line = svg.selectAll(".port")
var actor = svg.selectAll(".actor")
var actor_label = svg.selectAll(".actor-label")

window.onpopstate = function(event) {
 t = event.state["state"];
 active_tab = event.state.tab;
 $.tab('change tab', active_tab);
 update();
};

function push_state(){
  history.pushState({"state":t,"tab":active_tab}, 'state '+t, '/simulator/simulate.html?state='+t+"&tab="+active_tab);
}

function tchange(event){
 if (d3.event.keyCode == 37 && t > 0){
  t--;
  push_state();
  update();
 }else if (d3.event.keyCode == 39){
  t++;
  if(!states[t]){
   t--;
  }else{
   push_state()
  }
  update();
 }
}

function update_t(time){
 t = time;
 push_state();
 update();
}

function load_graph(elem) {
 elem.setAttribute('class','content');
 f = document.createElement('iframe');
 f.setAttribute("src","./graph.html?graph="+elem.getAttribute("data-graph"));
 f.setAttribute('width',"100%");
 f.setAttribute('height',"70%");
 f.setAttribute('frameBorder',0);
 elem.innerText='';
 elem.appendChild(f);
}

function update() {
console.log(t);
console.log(states[t].stack);
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
d3.select("body").select("#step").selectAll(".status-label")
 .data([states[t].status])
 .enter()
 .append("p")
 .attr("class","status-label")
 .text(d => d);

function indent(t) {
 return t.replace(/^(?=.)/gm, " ");
}

function comp(s1,s2) {
 desc = "{";
 start = true;
 for (k in s2) {
  if(!start){
  desc += "\n,";
  }
  start = false
  if (JSON.stringify(s1[k]) == JSON.stringify(s2[k])) {
   desc += "\""+k + "\":";
   desc += JSON.stringify(s2[k],null," ");
  }else{
   if (s1[k] && JSON.stringify(s1[k]).startsWith("{")) {
     desc += "\""+k + "\":";
     desc += indent(comp(s1[k],s2[k]));
    }else{
     desc_p = "<span style='color:green;'>"
     desc_p += "\""+k + "\":";
     desc_p += JSON.stringify(s2[k],null," ");
     desc_p += "</span>";
     desc += indent(desc_p);
    }
  }
 }
 desc += "\n}"
 return desc
}

d3.selectAll(".actor-state")
 .data([]).exit().remove();
actors_tab = d3.select("body").select("#actors-tab")
 .selectAll(".actor-state")
 .data(states[t].actors)
 .enter()
 .append("div")
 .attr("class","actor-state ui card");

actors_tab
 .append("div")
 .attr("class","header")
 .text(d => d.name);

actors_tab
 .append("div")
 .attr("class","meta")
 .text(d => d.long_name);

actors_tab
 .append("pre")
 .html(d => comp(d.prev_state,d.state));

function get_cells(s) {
 if (!s) {
  return {}
 }
 if (s["service_state"]) {
  cells = s["service_state"]["cells"];
 } else {
  cells = s["cells"];
 }
 if (cells) {
  return cells
 } else {
  return {}
 }
}

d3.selectAll(".actor-graph")
 .data([]).exit().remove();
actor_graphs_tab = d3.select("body").select("#graph-views-tab")
 .selectAll(".actor-graph")
 .data(states[t].actors)
 .enter()
 .append("div")
 .attr("class","actor-graph ui item")
 .append("div")
 .attr("class","content");

actor_graphs_tab
 .append("div")
 .attr("class","ui header")
 .text(a => a.name);

actor_graphs_tab
 .append("div")
 .attr("class","meta")
 .append("div")
 .attr("class","actor-graph-container")
 .attr("data-graph",a=>encodeURIComponent(JSON.stringify(get_cells(a.state))));

activate_graphs();

num_msgs = 0
for (k in states[t].sockets) {
 if (states[t].sockets[k].msg) {
  num_msgs++;
 }
}
d3.selectAll(".socket-msg-counter").data([]).exit().remove();
if(num_msgs) {
d3.select("body").select("#sockets-tab-btn").selectAll(".socket-msg-counter")
 .data([num_msgs])
 .enter()
 .append("div")
 .text(d => d)
 .attr("class","socket-msg-counter ui floated right label black");
}

d3.selectAll(".socket-msg")
 .data([]).exit().remove();
sockets_tab = d3.select("body").select("#sockets-tab")
 .selectAll(".socket-msg")
 .data(states[t].sockets)
 .enter()
 .append("div")
 .attr("class","socket-msg ui card");

sockets_tab.append("div")
 .attr("class","header")
 .text(d => d.name);
sockets_tab.append("div")
 .attr("class","meta")
 .text(d => d.type);

sockets_tab.append("pre")
 .text(d => (d.msg ? JSON.stringify(d.msg, null, " ") : ""));

cursors = []
for (selid in states[t].actors[1].state.client_state.selections) {
 sel = states[t].actors[1].state.client_state.selections[selid]
 for (cursi in sel.cursors) {
  cursor = sel.cursors[cursi]
  cursors.push(
  [sel.name + "." + cursi
  ,cursor
  ]);
 }
}

d3.selectAll(".cursor-card")
 .data([]).exit().remove();
cursors_tab = d3.select("body").select("#cursors-tab")
 .selectAll(".cursor-card")
 .data(cursors)
 .enter()
 .append("div")
 .attr("class","cursor-card ui content");

cursors_tab.append("div")
 .attr("class","header")
 .text(d => d[0]);

/*
function mk_status_list(los) {
 "⚏"
}

cursors_tab.append("div")
 .attr("class","header")
 .text();
*/

function mk_state_tree(los) {
 html = "<table class=\"ui celled table\">";
 html += "<thead><tr><th></th><th>var</th><th>cont_true</th><th>cont_false</th></tr></thead>";

 html += "<tbody>";
 for (state_id in los.states) {
  state = los.states[state_id]
  function add_direction(direction,dn) {
   for (dim in direction) {
    condition = direction[dim]
    html += "<tr><td>"+state_id+"."+dn+"."+dim+"</td><td>"+condition.var+"</td><td>"+condition.cont_true+"</td><td>"+condition.cont_false+"</td></tr>";
   }
  }
  add_direction(state.forth,"forth");
  add_direction(state.back,"back");
 }
 html += "</tbody></table>";

 html += "<table class=\"ui celled table\">";
 html += "<thead><tr><th>var</th>";
 for (vi in los.vars) {
  html += "<th>"+vi+"</th>";
 }
 html += "</tr></thead><tbody><tr><th>value</th>";
 for (vi in los.vars) {
  html += "<td>"+los.vars[vi]+"</td>";
 }
 html += "</tr></tbody></table>";
 function add_branch(branch){
  html += "<div class='ui list'>"
   html+= "<div class='item'>"
    html+= "<i class='arrows alternate'></i>"
    html+= "<div class='content'>"
     html+= "<div class='header'>"+branch[0]+" → <tt>state:"+branch[1].current_state+" vars:"+branch[1].vars+"</tt></div>"
    html+= "</div>"
    function add_direction(dir,dn){
     for(dimi in dir) {
      html+= "<div class='item'>"
      html+= "<i class='angle right'></i>"
      html+= "<div>"+dn+"."+dimi+"</div>"
      add_branch(dir[dimi])
      html+= "</div>"
     }
    }
    html += "<div class='ui list'>"
     add_direction(branch[1].forth,"forth")
     add_direction(branch[1].back,"back")
    html += "</div>"
   html += "</div>"
  html += "</div>"
 }
 console.log(los)
 if(los.state_tree){
  add_branch(los.state_tree)
 }
 return html;
}
cursors_tab.append("pre")
 .html(d => mk_state_tree(d[1].los));

d3.selectAll(".index").data([]).exit().remove();
d3.select("body").select("#step-counter").selectAll(".title")
 .data([states[t].index])
 .enter()
 .append("text")
 .text(d => (d + 1) + (states[t]["passed"] ? "" : "✗"))
 .attr("class","index")

d3.selectAll(".title")
 .data([]).exit().remove();
d3.select("body").select("#step-title").selectAll(".title")
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

d3.selectAll(".bookmark").data([]).exit().remove();
d3.select("body").select("#contents-tab").selectAll(".bookmark")
 .data(bookmarks)
 .enter()
 .append("a")
 .attr("class","bookmark item")
 .text(d => d.text)
 .attr("onclick",d => "update_t("+d.index+")")
 .attr("style",d => d.index == t ? "font-weight:bold;" : (d.index < t ? "font-style:italic;":"font-weight:normal;"))
 .append("div")
 .attr("class","ui floated right")
 .attr("style","float:right;")
 .text(d => d.index);
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

$('.menu .item').tab({'onVisible':function(elem){
  active_tab = elem;
  activate_graphs();
  push_state();
   }});

function activate_graphs() {
 if (active_tab == "graph-views"){
  Array.from(document.getElementsByClassName("actor-graph-container")).forEach(
   function(element, index, array) {
    load_graph(element)
   })
 }
}
