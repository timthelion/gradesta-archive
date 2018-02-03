middle = 70
spread = 50
sm_offset = 200
active = "black"
inactive = "lightgrey"
t = 0
num_clients = 0

function client_center(i) {
 return sm_offset+(i+1)*50
}

actors =
 [
  {"name":"S"
  ,"x":40
  ,"y":0
  ,"active": t>1},

  {"name":"MK"
  ,"x":125
  ,"y":0},

  {"name":"SM"
  ,"x":sm_offset
  ,"y":-spread},

  {"name":"NM"
  ,"x":sm_offset
  ,"y":spread},
 ]

sockets =
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

lines = []

var svg = d3.selectAll("svg");
var socket = svg.selectAll(".socket")
var line = svg.selectAll(".port")
var actor = svg.selectAll(".actor")
var actor_label = svg.selectAll(".actor-label")

function tchange(event){
 if (d3.event.keyCode == 37){
  if(num_clients > 0) {
   num_clients--;
   actors.pop()
   sockets.pop()
   sockets.pop()
   update();
  }
  t--;
 }else if (d3.event.keyCode == 39){
  client = "C"+num_clients
  x = client_center(num_clients) 
  actors.push({"name":client,"x": x,"y":0})
  sockets.push({"name":"clients/"+client+"/manager.gradesock","seg":[[x,0],[x,-spread+6]]})
  sockets.push({"name":"clients/"+client+"/client.gradesock","seg":[[x,spread],[x,24]]})
  num_clients++;
  t++;
  update();
 }
}

function update() {


if (num_clients == 0) {
 lines = []
} else {
 lines = [{
   "name": "clients/<client-id>/manager.gradesock"
  ,"height": -spread
  ,"start": sm_offset + 15
  ,"end": client_center(num_clients - 1)
  }

 ,{"name": "clients/<client-id>/client.gradesock"
  ,"height": spread
  ,"start": sm_offset + 15
  ,"end": client_center(num_clients - 1)
  }
 ]
}
line = svg.selectAll(".port");//Don't know why this is needed. Don't care either.//Don't know why this is needed. Don't care either. It works.
line.data([]).exit().remove();
line = svg.selectAll(".port");
line
 .data(lines)
 .enter()
 .append("line")
 .attr("class", "port")
 .attr("stroke-width", 1)
 .attr("stroke", inactive)
 .attr("x1", function(d){return d.start})
 .attr("y1", function(d){return d.height+middle})
 .attr("x2", function(d){return d.end})
 .attr("y2", function(d){return d.height+middle});

socket = svg.selectAll(".socket");
socket
 .data(sockets)
 .enter()
 .append("line")
 .attr("class", "socket")
 .attr("stroke-width", 1)
 .attr("x1", function(d){return d.seg[0][0]})
 .attr("y1", function(d){return d.seg[0][1]+middle})
 .attr("x2", function(d){return d.seg[1][0]})
 .attr("y2", function(d){return d.seg[1][1]+middle})
 .attr("stroke", function(d){return d.active ? active : inactive})
 .attr("marker-end", function(d){return d.active ? "url(#active-triangle)" : "url(#inactive-triangle)"});

socket
 .data(sockets)
 .exit().remove();

actor = svg.selectAll(".actor")
actor
 .data(actors)
 .enter()
 .append("circle")
 .attr("class","actor")
 .attr("r",18)
 .attr("cy",function(d){return middle+d.y})
 .attr("cx",function(d){return d.x})
 .attr("fill",function(d){return (d.active ? active : inactive)});
actor.data(actors).exit().remove();

actor_label = svg.selectAll(".actor-label")
actor_label.data(actors)
 .enter()
 .append("text")
 .attr("class","actor-label")
 .attr("text-anchor","middle")
 .attr("style","fill:white;")
 .attr("stroke-width","2px")
 .attr("dy",".3em")
 .text(function(d){return d.name})
 .attr("x",function(d){return d.x})
 .attr("y",function(d){return middle+d.y});

actor_label.data(actors)
 .exit().remove();
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

update();

d3.select('body')
   .on("keydown", tchange);
