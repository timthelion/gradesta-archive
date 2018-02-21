source = getParameterByName("tg");
function load_hash() {
 center = window.location.hash
 if(center=="") {
  center = 0;
 }
 if(center.startsWith("#")){
  center = center.split("#")[1];
 }
}
load_hash();
function readTextFile(file, callback) {
    var rawFile = new XMLHttpRequest();
    rawFile.overrideMimeType("application/json");
    rawFile.open("GET", file, true);
    rawFile.onreadystatechange = function() {
        if (rawFile.readyState === 4 && rawFile.status == "200") {
            callback(rawFile.responseText);
        }
    }
    rawFile.send(null);
}

readTextFile(source, load_tg);

nodes = {}
function load_tg(tg) {
lines = tg.split("\n");
for (i in lines) {
 line = lines[i];
 if (!line.startsWith("[")) {
  continue;
 }
 ld = JSON.parse(line);
 nodes[ld[0]] = {text:ld[1],streets:ld[2],backstreets:[]};
}
for (k in nodes) {
 node = nodes[k];
 for (i in node.streets) {
  backstreet = JSON.parse(JSON.stringify(node.streets[i]));
  backstreet[1] = k;
  nodes[node.streets[i][1]].backstreets.push(backstreet);
 }
}
show(nodes,center,true);
}

function show(nodes, center,set_location) {
 if(set_location){
  window.location.hash = "#"+center;
 }
 window.scrollTo(0,0);
 node = nodes[center];
 document.title = node.text.split("\n")[0]
 document.getElementById("center").innerText = node.text;
 function add_street(s,div) {
  street = document.createElement("a");
  street.setAttribute("class","ui item");
  dest = s[1]
  street.setAttribute("onclick", "show(nodes,"+dest+",true);");
  streetName = document.createElement("div");
  streetName.setAttribute("class","ui label");
  streetName.innerText = s[0]
  streetDest = document.createElement("pre");
  streetDest.setAttribute("class","detail");
  streetDest.innerText = nodes[s[1]].text.split("\n")[0]
  street.appendChild(streetName);
  streetName.appendChild(streetDest);
  div.appendChild(street);
 }
 streets = document.getElementById("streets");
 while (streets.firstChild) {
  streets.removeChild(streets.firstChild);
 }
 for (var i = 0; i < node.streets.length; i++) {
  s = node.streets[i];
  add_street(s,streets);
 }
 backstreets = document.getElementById("backstreets");
 while (backstreets.firstChild) {
  backstreets.removeChild(backstreets.firstChild);
 }
 for (var i = 0; i < node.backstreets.length; i++) {
  s = node.backstreets[i];
  add_street(s,backstreets);
 }
}
$(window).on('hashchange', function() {
  load_hash();
  show(nodes,center,false);
});
