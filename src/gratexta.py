#!/usr/bin/python3
import sys
import json

class LineByLineFile():
 def __init__(self, filename):
  self.lineno = -1
  self.file = open(filename,"r")

 def readline(self):
  line = self.file.readline()
  self.lineno += 1
  return line

 def close(self):
  self.file.close()

class FromGratextaFile():
 def __init__(self,file):
  if type(file) == str:
   file = LineByLineFile(sys.argv[1])
  self.bookmarks = {}
  self.cells = {}

  #READ BOOKMARKS SECTION
  while True:
   line = file.readline()
   if not line:
    break
   if line.strip() == "CELLS":
    break
   elif line.strip() == "BOOKMARKS":
    pass
   elif not line.strip():
    pass
   elif ':' in line:
    [bookmark_name_string,destination_string] = line.split(':')
    bookmark_name = json.loads(bookmark_name_string.strip())
    self.bookmarks[bookmark_name] = json.loads(destination_string.strip())
   else:
    sys.exit("Error on line %n: Expected a bookmark entry."%file.lineno)
  
  #READ CELLS SECTION
  while True:
   line = file.readline()
   if not line:
    break
   if not line.strip():
     pass
   else:
    cell_id = line.rstrip('\n')
    cell = {}
    # READ PROPERTIES DICT
    while True:
     line = file.readline()
     if not line:
      break
     if line == " ---\n":
      break
     if line.startswith(' '):
      try:
       [key,value] = line.split(":")
      except ValueError:
       print("Error on line %i: expected dictionary entry."%file.lineno)
       print(line)
       exit()
      key = key.strip()
      value = value.strip()
      if key == "up" or key == "down" or key == "tags":
       try:
        value = json.loads(value)
       except ValueError:
        print("Error on line %i: failed to parse value."%file.lineno)
        print(line)
       cell[key] = value 
      elif key == "left" or key == "right":
       link = {}
       try:
        json.loads(value)
       except json.decoder.JSONDecodeError as e:
        try:
         link["service"] = json.loads(value[:e.pos])
        except json.decoder.JSONDecodeError as e2:
         print("Error on line %i: Failed to parse string."%file.lineno)
         print(line)
         print(e)
         exit(1)
        try:
         rest = value[e.pos:]
         json.loads(rest)
        except json.decoder.JSONDecodeError as e1:
         try:
          path_string = rest[:e1.pos]
          link["path"] = json.loads(path_string)
         except ValueError as e3:
          print("Error on line %i: Failed to parse string %s."%(file.lineno,path_string))
          print(e3)
          print(line)
          exit(1)
         link["cell_id"] = json.loads(rest[e1.pos:])
         cell[key] = link 
    # read cell text
    text = ""
    while True:
     line = file.readline()
     if not line or line == '\n':
      if text:
       cell["text"] = text[:-1]
      else:
       cell["text"] = ""
      self.cells[cell_id] = cell
      break
     elif line.startswith(' '):
      text += line[1:]
    text = ""

 def get_json(self):
  obj = {"bookmarks":self.bookmarks,"cells":self.cells}
  return json.dumps(obj)

gd = FromGratextaFile(sys.argv[1]) 
print(gd.get_json())
