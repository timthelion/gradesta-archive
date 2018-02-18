
//view-source:https://www.graphdracula.net/0.0.3alpha/index.html
/* add a node with a customized shape 
(the Raphael graph drawing implementation can draw this shape, please 
consult the RaphaelJS reference for details http://raphaeljs.com/) */
var render = function(r, n) {
 /* the Raphael set is obligatory, containing all you want to display */
 var set = r.set().push(
 /* custom objects go here */
 r.rect(n.point[0]-30, n.point[1]-13, 10, 10).attr({"fill": "#fa8", "stroke-width": 1, r : "2px"})).push(
   r.text(n.point[0], n.point[1] + 10, n.label).attr({"font-size":"8px"}));
   return set;
 };

function get_graph(cells) {
 g = new Graph(); 
 if (cells) {
  for (k in cells) {
   cell = cells[k].cell;
   g.addNode(k,{label:k+":"+cell.data,render:render});
  }
  edges = [{},{}]
  for (k in cells) {
   cell = cells[k].cell;
   for (d in cell.dims) {
    if (cell.dims[d].forth) {
     for (i in cell.dims[d].forth) {
      link = cell.dims[d].forth[i];
      g.addEdge(k,link.cell_id,{directed:true,label: d,stroke : "#4286f4"});//, fill : "#56f"});
     }
    }
    /*
    if (cell.dims[d].back) {
     for (i in cell.dims[d].back) {
      link = cell.dims[d].back[i];
     }
    }*/
   }
  }
 }
 return g
}

function getParameterByName(name) {
 var match = RegExp('[?&]' + name + '=([^&]*)').exec(window.location.search);
 return match && decodeURIComponent(match[1].replace(/\+/g, ' '));
}
cells = JSON.parse(getParameterByName("graph"));
g = get_graph(cells);
var layouter = new Graph.Layout.Spring(g);
layouter.layout();
var renderer = new Graph.Renderer.Raphael("canvas", g, 400, 300);
console.log(renderer);
renderer.draw();
