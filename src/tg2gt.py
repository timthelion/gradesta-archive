#!/usr/bin/python3
import json
import sys
import uuid

print("""BOOKMARKS
"home":"0"

CELLS
""")

class Cell():
 def __init__(self):
  self.cell_id = ""
  self.up = ""
  self.down = ""
  self.left = ""
  self.right = ""
  self.text = ""
  self.destination = None

 def print(self):
  print(self.cell_id)
  if self.up:
   print(" up:"+json.dumps(self.up))
  if self.down:
   print(" down:"+json.dumps(self.down))
  if self.left:
   print(" left: \".\" \".\" "+json.dumps(self.left))
  if self.right:
   print(" right: \".\" \".\" "+json.dumps(self.right))
  print(" tags: \"\"")
  print(" ---")
  text = " " + self.text.replace("\n","\n ")
  print(text)
  print("")

class Stack():
 def __init__(self, node):
  self.node = node
  self.top_cell = Cell()
  self.ins  = []
  self.outs = []

 def add_in(self,out):
  in_cell = Cell()
  in_cell.cell_id = str(uuid.uuid4())
  in_cell.left = out
  self.ins.append(in_cell)
  return in_cell.cell_id

 def print(self):
  self.top_cell.print()
  for in_cell in self.ins:
   in_cell.print()
  for out in self.outs:
   out.print()

 def link(self):
  all_cells = [self.top_cell] + self.ins + self.outs
  prev_cell = None
  for cell in all_cells:
   if prev_cell:
    cell.up = prev_cell.cell_id
   prev_cell = cell
  prev_cell = None
  for cell in reversed(all_cells):
   if prev_cell:
    cell.down = prev_cell.cell_id
   prev_cell = cell
stacks = {}

while True:
 line = sys.stdin.readline()
 if not line:
  break
 if (not line.strip()) or line.startswith("#"):
  continue
 node = json.loads(line)
 stack = Stack(node)
 stack.top_cell.text = node[1]
 stack.top_cell.cell_id = str(node[0])
 stacks[stack.top_cell.cell_id] = stack
 for name,destination in node[2]:
  destination = str(destination)
  out_cell = Cell()
  out_cell.cell_id = str(uuid.uuid4())
  out_cell.text = name
  out_cell.destination = destination
  stack.outs.append(out_cell)

for stack in stacks.values():
 for out in stack.outs:
  out.right = stacks[out.destination].add_in(out.cell_id)
 stack.link()
 stack.print()
