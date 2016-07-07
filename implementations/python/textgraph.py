#!/usr/bin/python3
#
# Authors: Timothy Hobbs
# Copyright years: 2016
#
# Description:
#
# textgraph is a reference implementation for reading, writting, and manipulating text graphs.
#
########################################################################
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
import sys
import copy
import json
import subprocess
import os
import collections.abc

class Street(list):
  def __init__(self,name,destination,origin,readonly = False):
    self.append(name)
    self.append(destination)
    self.origin = origin
    self.readonly = readonly

  @property
  def name(self):
    return self[0]

  @name.setter
  def name(self,value):
    self[0] = value

  @property
  def destination(self):
    return self[1]

  @destination.setter
  def destination(self,value):
    self[1] = value

  def __repr__(self):
    return self.name + "→" + str(self.destination)

  def __eq__(self,other):
    return self.name == other.name and self.destination == other.destination

class Square():
  def __init__(self,squareId,text,streets,readonly = False,incommingStreets=None):
    self.squareId = squareId
    self.text = text
    self.streets = streets
    self.readonly = readonly
    if incommingStreets is not None:
      self.incommingStreets = incommingStreets

  def __repr__(self):
    return str((self.squareId,self.text,self.streets))

  @property
  def list(self):
    streets = []
    for street in self.streets:
      streets.append([street.name,street.destination])
    return [self.squareId,self.text,streets]

  @property
  def title(self):
    try:
      return self.text.splitlines()[0]
    except IndexError:
      return "<blank-text>"
    except AttributeError:
      return "Non-existant square: "+str(self.squareId)

  def lookupStreet(self,streetName):
    for street in self.streets:
      if street.name == streetName:
        return street
    raise KeyError("Square "+str(self.squareId)+" : "+self.text+" has no street named "+streetName)

def getSquareFromList(square,permissions):
  squareId,text,streetsAsLists,incommingStreetLists = square
  _,textPermission,streetPermissions = permissions
  streets = []
  for (name,destination),streetPermission in zip(streetsAsLists,streetPermissions):
    streets.append(Street(name,destination,squareId,streetPermission is not None))
  incommingStreets = []
  for origin,name in incommingStreetLists:
    incommingStreets.append(Street(name,squareId,origin))
  return Square(squareId,text,streets,readonly = textPermission is not None,incommingStreets = incommingStreets)

class TextGraphServer():
  def __init__(self,filename):
    self.proc = subprocess.Popen(["./tgserve.py",filename],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,close_fds=True)

  def send(self,query):
    queryString = json.dumps(query) + "\n"
    self.proc.stdin.write(queryString.encode("utf-8"))
    self.proc.stdin.flush()
    def nextline():
      try:
        line = self.proc.stdout.readline().decode("utf-8")
      except KeyboardInterrupt:
        errors = self.proc.stderr.read().decode("utf-8")
        sys.exit("Sent:"+queryString+"Pipe broken. Backend crashed.\n"+errors)
      if line == "": # This is idiotic. Blank lines return "\n" and eof == "".
        errors = self.proc.stderr.read().decode("utf-8")
        sys.exit("Sent:"+queryString+"Pipe broken. Backend crashed.\n"+errors)
      else:
        return line
    try:
      responseString = nextline()
      response = json.loads(responseString)
    except ValueError:
      sys.exit("Malformed response: "+responseString)
    try:
      returnCodesString = nextline()
      returnCodes = json.loads(returnCodesString)
    except ValueError:
      sys.exit("Response:"+responseString+"\nMalformed return code: "+returnCodeString)
    return (response,returnCodes)

class TextGraph(collections.abc.MutableMapping):
  def __init__(self,filename):
    self.filename = filename
    self.edited = False
    self.stagedSquares = []
    self.undone = []
    self.done = []
    self.header = ""
    self.applyChangesHandler = lambda: None
    self.server = TextGraphServer(filename)

  def _getAllSquares(self):
    allSquares = {}
    response,returnCodes = self.server.send([])
    for square,permissions in zip(response,returnCodes):
      allSquares[square[0]] = getSquareFromList(square,permissions)
    return allSquares

  def __getitem__(self, key):
    response,returnCodes = self.server.send([key])
    return getSquareFromList(response[0],returnCodes[0])

  def __setitem__(self, squareId, square):
    self.server.send(square.list)

  def __delitem__(self,key):
    self.__setitem__(key,Square(key,None,[]))

  def __iter__(self):
    for square in self._getAllSquares():
      yield square

  def __len__(self):
    return len(self._getAllSquares())

  def allocSquare(self):
    """
    Return a new or free square Id.
    """
    response,returnCodes = self.server.send([None])
    return response[0][0]

  def stageSquare(self,square):
    self.stagedSquares.append(copy.deepcopy(square))

  def applyChanges(self):
    if self.readonly:
      self.stagedSquares = []
      return
    didNow = []
    didSomething = False
    for square in self.stagedSquares:
      prevState = self[square.squareId]
      didNow.append((copy.deepcopy(prevState),copy.deepcopy(square)))
      if square.text is None:
        didSomething = True
      elif not (prevState.text == square.text and prevState.streets == square.streets):
        didSomething = True
    if didSomething:
      self.undone = []
      self.server.send([square.list for square in self.stagedSquares])
      self.stagedSquares = []
      self.done.append(didNow)
      if len(self.done)%5 == 0:
        self.saveDraft()
      self.edited = True
      self.applyChangesHandler()

  def undo(self):
    try:
      transaction = self.done.pop()
    except IndexError:
      return
    self.edited = True
    for (prevState,postState) in transaction:
      self[prevState.squareId] = copy.deepcopy(prevState)
      if prevState.text is None:
        del self[prevState.squareId]
    self.undone.append(transaction)
    self.applyChangesHandler()

  def redo(self):
    try:
      transaction = self.undone.pop()
    except IndexError:
      return
    self.edited = True
    for (prevState,postState) in transaction:
      if postState.text is not None:
        self[postState.squareId] = copy.deepcopy(postState)
      else:
        del self[postState.squareId]
    self.done.append(transaction)
    self.applyChangesHandler()

  def newLinkedSquare(self,streetedSquareId,streetName):
    newSquareId = self.allocSquare()
    newSquare = Square(newSquareId,"",[])
    selectedSquare = copy.deepcopy(self[streetedSquareId])
    selectedSquare.streets.append(Street(streetName,newSquareId,selectedSquare.squareId))
    self.stageSquare(newSquare)
    self.stageSquare(selectedSquare)
    self.applyChanges()
    return newSquareId

  def getDeleteSquareChanges(self,squareId):
    """
    Get the changes that need to be preformed in order to delete a square.
    """
    changes = []
    for incommingStreet in self[squareId].incommingStreets:
      if incommingStreet != squareId:
        incommingStreetOrigin = copy.deepcopy(self[incommingStreet.origin])
        incommingStreetOrigin.streets = [street for street in incommingStreetOrigin.streets if street.destination != squareId]
        changes.append(incommingStreetOrigin)
    changes.append(Square(squareId,None,[]))
    return changes

  def stageSquareForDeletion(self,squareId):
    for square in self.getDeleteSquareChanges(squareId):
      self.stageSquare(square)

  def deleteSquare(self,squareId):
    self.stageSquareForDeletion(squareId)
    self.applyChanges()

  def getTree(self,squareId):
    square = self[squareId]
    tree = set([square.squareId])
    for street in square.streets:
      if not street.destination in tree:
        tree.update(self.getTree(street.destination))
    return tree

  def deleteTree(self,squareId):
    squaresForDeletion = set(self.getTree(squareId))
    for square in self:
      if not square.squareId in squaresForDeletion:
        newStreets = []
        for street in square.streets:
          if not street.destination in squaresForDeletion:
            newStreets.append(street.destination)
        if newStreets != square.streets:
          self.stageSquare(Square(square.squareId,square.text,newStreets))
    for square in squaresForDeletion:
      self.stageSquare(Square(square,None,[]))
    self.applyChanges()

  @property
  def readonly(self):
    return self.filename.startswith("http://")

  @property
  def sorted_items(self):
    return sorted(self.items(),key=str)

  @property
  def json(self):
    serialized = self.header
    for _,square in self.sorted_items:
      serialized += json.dumps([square.squareId,square.text,square.streets])
      serialized += "\n"
    return serialized

  @json.setter
  def json(self,text):
    self.header = ""
    readingHeader = True
    lineNo = 0
    sqr = 0
    for line in text.splitlines():
      if not line or line.startswith("#"):
        if readingHeader:
          self.header += line+"\n"
      else:
        readingHeader = False
        try:
          (squareId,text,streetsList) = json.loads(line)
          streets = []
          for streetName,destination in streetsList:
            streets.append(Street(streetName,destination,squareId))
          self[squareId] = Square(squareId,text,streets)
          try:
            if squareId >= self.nextSquareId:
              self.nextSquareId = squareId + 1
          except TypeError:
            pass
        except ValueError as e:
          raise ValueError("Cannot load file "+self.filename+"\n"+ "Error on line: "+str(lineNo)+"\n"+str(e))
      lineNo += 1

  def __neighborhood(self,center,level):
    """
    Returns a list of squares around a given square.
    Level gives you some control over the size of the neighborhood.
    """
    neighborhood = set()
    squareIdsInNeighborhood = set()
    edge = [self[center]]
    # Build neighborhood
    for _ in range(0,level):
      newEdge = []
      oldEdge = []
      for square in edge:
        if not square.squareId in squareIdsInNeighborhood:
          oldEdge.append(square.squareId)
          squareIdsInNeighborhood.add(square.squareId)
        for street in square.streets:
          newEdge.append(self[street.destination])
        for street in square.incommingStreets:
          newEdge.append(self[street.origin])
      edge = newEdge
    # Remove streets that leave neighborhood.
    finalNeighborhood = []
    for squareId in squareIdsInNeighborhood:
      newSquare = copy.deepcopy(self[squareId])
      newSquare.streets = [street for street in newSquare.streets if street.destination in squareIdsInNeighborhood]
      finalNeighborhood.append(newSquare)
    return finalNeighborhood, oldEdge

  def dot(self,markedSquares={},neighborhoodCenter=None,neighborhoodLevel=4):
    if neighborhoodCenter is None:
      neighborhood = self.values()
      edge = []
    else:
      neighborhood, edge = self.__neighborhood(neighborhoodCenter,neighborhoodLevel)
    dot = "digraph graphname{\n"
    labels = ""
    edges = ""
    for square in neighborhood:
      if square.text is not None:
        markings = ""
        if square.squareId in markedSquares:
          for attr,value in markedSquares[square.squareId].items():
            markings += "," + attr + " = " + value
        if square.squareId in edge:
          markings += ", color=grey"
        labelstring = list(repr(square.text+"\n").replace("\\n","\\l"))
        labelstring[0] = '"'
        labelstring[-1] = '"'
        labels += str(square.squareId)+"[shape=rect label="+''.join(labelstring)+markings+"]\n"
        n = 0
        for street in square.streets:
          edgeColoring = ""
          if street.destination in edge or street.origin in edge:
            edgeColoring = ",style = dotted, color = grey"
          labelstring = list(repr(str(n)+":"+street.name))
          labelstring[0] = '"'
          labelstring[-1] = '"'
          edges += str(square.squareId)+" -> "+str(street.destination)+" [label="+''.join(labelstring)+edgeColoring+"]\n"
          n += 1
    dot += labels
    dot += edges
    dot += "}"
    return dot

  def showDiagram(self,neighborhoodCenter = None,neighborhoodLevel = 4,markedSquares={}):
    subprocess.Popen(["dot","-T","xlib","/dev/stdin"],stdin=subprocess.PIPE).communicate(input=self.dot(markedSquares=markedSquares,neighborhoodCenter=neighborhoodCenter,neighborhoodLevel=neighborhoodLevel).encode("utf-8"))

  def save(self):
    if self.readonly:
      raise OSError(self.filename + " is read only.")
    with open(self.filename,"w") as fd:
      fd.write(self.json)

  def saveDraft(self):
    if self.readonly:
      return
    with open(os.path.join(os.path.dirname(self.filename),"."+os.path.basename(self.filename)+".draft"),"w") as fd:
      fd.write(self.json)

  def saveDot(self):
    if self.readonly:
      raise OSError(self.filename + " is read only.")
    with open(self.filename+".dot","w") as fd:
      fd.write(self.dot())
