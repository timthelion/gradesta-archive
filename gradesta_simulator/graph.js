function get_graph(cells) {
 g = new Graph(); 
 if (cells) {
  for (k in cells) {
   cell = cells[k].cell;
   g.addNode(k,{label:k+":"+cell.data});
  }
  for (k in cells) {
   cell = cells[k].cell;
   for (d in cell.dims) {
    if (cell.dims[d].forth) {
     for (i in cell.dims[d].forth) {
      link = cell.dims[d].forth[i];
      g.addEdge(k,link.cell_id,{label:d+" forth"});
     }
    }
    if (cell.dims[d].back) {
     for (i in cell.dims[d].back) {
      link = cell.dims[d].back[i];
      g.addEdge(k,link.cell_id,{label:d+" back"});
     }
    }
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
var renderer = new Graph.Renderer.Raphael("canvas", g, 400, 200);
console.log(renderer);
renderer.draw();
