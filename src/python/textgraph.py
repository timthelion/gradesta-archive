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
  def json(self):
    return json.dumps(self.list)

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
  def __init__(self):
    self.proc = subprocess.Popen(["tgserve"],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,close_fds=True)

  def send(self,query):
    return self.send_raw(json.dumps(query))

  def send_raw(self,queryString):
    queryString += "\n"
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
  def __init__(self):
    self.stagedSquares = []
    self.undone = []
    self.done = []
    self.applyChangesHandler = lambda: None
    self.server = TextGraphServer()
    self.edited = False
    self._cache = {}

  def __getitem__(self, key):
    if not key in self._cache:
      response,returnCodes = self.server.send([key])
      self._cache[key] = getSquareFromList(response[0],returnCodes[0])
    return self._cache[key]

  def __setitem__(self, squareId, square):
    response,returnCodes = self.server.send(square.list)
    for square,permissions in zip(response,returnCodes):
      if square[1] is None:
        try:
          del self._cache[square[0]]
        except KeyError:
          pass
      else:
        self._cache[square[0]] = getSquareFromList(square,permissions)

  def __delitem__(self,key):
    self.__setitem__(key,Square(key,None,[]))

  def __iter__(self):
    raise NotImplementedError("Not implemented due to the need to support infinite graphs in the future!")

  def __len__(self):
    raise NotImplementedError("Not implemented due to the need to support infinite graphs in the future!")

  def allocSquare(self):
    """
    Return a new or free square Id.
    """
    response,returnCodes = self.server.send([None])
    return response[0][0]

  def stageSquare(self,square):
    self.stagedSquares.append(copy.deepcopy(square))

  def applyChanges(self):
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
      for square in self.stagedSquares:
        self[square.squareId] = square
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

  def newLinkedSquare(self,streetedSquareId,streetName,index = None):
    newSquareId = self.allocSquare()
    newSquare = Square(newSquareId,"",[])
    selectedSquare = copy.deepcopy(self[streetedSquareId])
    newStreet = Street(streetName,newSquareId,selectedSquare.squareId)
    if index is None:
      selectedSquare.streets.append(newStreet)
    else:
      selectedSquare.streets.insert(index,newStreet)
    self.stageSquare(newSquare)
    self.stageSquare(selectedSquare)
    self.applyChanges()
    return newSquareId

  def interjectSquare(self,origionalSquareId,streetIndex):
    newSquareId = self.allocSquare()
    selectedSquare = copy.deepcopy(self[origionalSquareId])
    newSquare = Square(newSquareId,"",[selectedSquare.streets[streetIndex]])
    newStreet = Street("",newSquareId,selectedSquare.squareId)
    selectedSquare.streets[streetIndex] = newStreet
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

  def getSubgraph(self,squareId,subgraph=None):
    square = self[squareId]
    if subgraph is None:
      subgraph = set([square.squareId])
    else:
      subgraph.update([square.squareId])
    for street in square.streets:
      if not street.destination in subgraph:
        subgraph.update(self.getSubgraph(street.destination,subgraph=subgraph))
    return subgraph

  def getNextSibling(self,squareId):
    for incommingStreet in self[squareId].incommingStreets:
      found = False
      for street in self[incommingStreet.origin].streets:
        if street.destination == squareId:
          found = True
        elif found:
          return street.destination
      if found:
        for street in self[incommingStreet.origin].streets:
          if street.destination != squareId:
            return street.destination
    return squareId

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

  def sorted_items(self,center=0):
    neighborhoodIds,_ = self.getNeighborhoodIds(center)
    return [self[squareId] for squareId in neighborhoodIds]

  @property
  def json(self):
    serialized = ""
    for square in self.sorted_items():
      serialized += square.json
      serialized += "\n"
    return serialized

  @json.setter
  def json(self,text):
    for line in text.splitlines():
      self.server.send_raw(line)

  def lookupStreetedSquare(self,squareId,text):
    """
    Look up square which is connected to squareId. If no matching square exists, returns None.
    """
    for street in self[squareId].streets:
      if self[street.destination].text == text:
        return self[street.destination]
    return None

  def lookupSquareViaContents(self,root,contents):
    currentSquare = root
    for text in contents:
      try:
        currentSquare = self.lookupStreetedSquare(currentSquare,text).squareId
      except AttributeError:
        raise KeyError("No square with text "+text+" is linked to from square "+str(currentSquare))
    return currentSquare

  def getNeighborhoodIds(self,center,level=None):
    squareIdsInNeighborhood = set()
    changed = True
    edge = [self[center]]
    oldEdge = []
    ring = 0
    while True:
      if not changed:
        return squareIdsInNeighborhood, oldEdge
      if level is not None and ring >= level:
        return squareIdsInNeighborhood, oldEdge
      changed = False
      ring += 1
      newEdge = []
      oldEdge = []
      for square in edge:
        if square.squareId not in squareIdsInNeighborhood:
          changed = True
          oldEdge.append(square.squareId)
          squareIdsInNeighborhood.add(square.squareId)
          for street in square.streets:
            newEdge.append(self[street.destination])
          for street in square.incommingStreets:
            newEdge.append(self[street.origin])
      edge = newEdge

  def getNeighborhood(self,center,level=None):
    """
    Returns a list of squares around a given square.
    Level gives you some control over the size of the neighborhood.
    """
    squareIdsInNeighborhood, oldEdge = self.getNeighborhoodIds(center,level) 
    # Remove streets that leave neighborhood.
    finalNeighborhood = []
    for squareId in squareIdsInNeighborhood:
      newSquare = copy.deepcopy(self[squareId])
      newSquare.streets = [street for street in newSquare.streets if street.destination in squareIdsInNeighborhood]
      finalNeighborhood.append(newSquare)
    return finalNeighborhood, oldEdge

class TextGraphFile(TextGraph):
  def __init__(self,filename):
    TextGraph.__init__(self)
    self.filename = filename
    self.header = ""
    if filename is None:
      pass
    elif filename.startswith("http://"):
      import urllib.request
      try:
        with urllib.request.urlopen(filename) as webgraph:
          self.json = webgraph.read().decode("utf-8")
      except urllib.error.URLError as e:
        raise OSError(str(e))
    else:
      try:
        with open(filename) as fd:
          self.json = fd.read()
      except FileNotFoundError:
        pass
    self.edited = False

  @property
  def readonly(self):
    return self.filename.startswith("http://")

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

  @property
  def json(self):
    return self.header + TextGraph.json.fget(self)

  @json.setter
  def json(self,text):
    if text.startswith("["):
      TextGraph.json.fset(self,text)
      return
    try:
      (header,rest) = text.split("\n[",1)
      self.header = header + "\n" 
      TextGraph.json.fset(self,"["+rest)
    except ValueError:
      TextGraph.json.fset(self,text)
