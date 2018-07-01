import gradesta_pb2
import zmq
import json


class Obj():
 def __init__(self, server, id):
  self.id = id
  self.server = server
  self.cells = set()
  self.load()

 def mark(self):
  for cell in self.cells:
   self.server.in_view[cell].marked = True


class Cell():
 def __init__(self, server, id):
  self.marked = False
  self.server = server
  self.id = id
  if self.id["obj"] in server.objs:
   self.obj = server.objs[self.id["obj"]]
  else:
   self.obj = self.obj_type(server, self.id["obj"])
   server.objs[self.id["obj"]] = self.obj

 @classmethod
 def id(cls, obj=None, obj_id=None, attrs=None):
  id = {}
  if obj is not None:
   id["obj"] = obj.id
  if obj_id is not None:
   id["obj"] = obj_id
  if attrs is not None:
   id.update(attrs)
  id["type"] = cls.__name__
  return json.dumps(id)

 def fill_in_protobuf(self, cell_runtime):
  cell_runtime.cell.data = self.data()

  def fill_dim(dir, dim, method):
   link = gradesta_pb2.Link()
   link_id = method()
   if link_id is not None:
    link.cell_id = link_id
    dir[dim].links.extend([link])

  fill_dim(cell_runtime.cell.back,  0, self.up)
  fill_dim(cell_runtime.cell.forth, 0, self.down)
  fill_dim(cell_runtime.cell.back,  1, self.left)
  fill_dim(cell_runtime.cell.forth, 1, self.right)

 def up(self):
  return None

 def down(self):
  return None

 def left(self):
  return None

 def right(self):
  return None

class Server():
 def __init__(self, name, source_url, index, cell_types):
  self.objs = {}
  self.in_view = {}
  self.cell_types = {}
  context = zmq.Context()
  self.service_socket = context.socket(zmq.PAIR)
  self.service_socket.bind("ipc://service.gradesock")
  s = gradesta_pb2.ServiceState()
  s.ParseFromString(self.service_socket.recv())
  s.index=index
  self.service_socket.send(s.SerializeToString())
  for cell_type in cell_types:
   self.cell_types[cell_type.__name__] = cell_type

 def serve(self):
  while True:
   m = gradesta_pb2.ServiceState()
   m.ParseFromString(self.service_socket.recv())
   r = gradesta_pb2.ServiceState()
   r.round.CopyFrom(m.round)
   for s_cell_id, is_in_view in m.in_view.items():
    if is_in_view:
     if s_cell_id not in self.in_view:
      j_cell_id = json.loads(s_cell_id)
      self.in_view[s_cell_id] = self.cell_types[j_cell_id['type']](self, j_cell_id)
     self.in_view[s_cell_id].marked = True
    elif not is_in_view:
     out_of_view_cell = self.in_view[s_cell_id]
     out_of_view_cell.obj.cells.remove(s_cell_id)
     if not out_of_view_cell.obj.cells:
      del self.objs[out_of_view_cell.obj.id]
     del self.in_view[s_cell_id]
   for s_cell_id, cell_runtime in m.cells.items():
    pass # TODO
   for id, cell in self.in_view.items():
    if cell.marked:
     cell.fill_in_protobuf(r.cells[id])
     cell.marked = False
   self.service_socket.send(r.SerializeToString())
