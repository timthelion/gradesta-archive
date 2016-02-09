#!/usr/bin/python3
#
# Authors: Timothy Hobbs
# Copyright years: 2016
#
# Description:
#
# mge is a simple TUI Vim style modal editor for text graphs.
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
import json
import optparse
import copy
import subprocess
try:
  import urwid
except ImportError:
  sys.exit("The urwid TUI toolkit is required to run this program. On debian based systems you need to install python3-urwid. On other systems you'll have to search the web.")

def showErrorDialog(error):
  # http://stackoverflow.com/questions/12876335/urwid-how-to-see-errors
  import tkinter as tk
  root = tk.Tk()
  window = tk.Label(root, text=error)
  window.pack()
  root.mainloop()

class Square():
  def __init__(self,squareId,text,streets):
    self.squareId = squareId
    self.text = text
    self.streets = streets

  def __repr__(self):
    return str((self.squareId,self.text,self.streets))

  @property
  def title(self):
    try:
      return self.text.splitlines()[0]
    except IndexError:
      return "<blank-text>"

class TextGraph(list):
  def __init__(self,fileName):
    self.fileName = fileName
    self.edited = False
    self.deleted = []
    self.stagedSquares = []
    self.undone = []
    self.done = []
    self.header = ""
    try:
      with open(fileName) as fd:
        self.json = fd.read()
    except FileNotFoundError:
      self.append(Square(0,"",[]))
    for square in self:
      if square.text is None:
        self.deleted.append(square.squareId)

  def allocSquare(self):
    """
    Return the ID of a new or free square.
    """
    if self.deleted:
      return self.deleted.pop()
    else:
      squareId = len(self)
      self.append(Square(squareId,None,[]))
      return squareId

  def stageSquare(self,square):
    self.stagedSquares.append(copy.deepcopy(square))

  def applyChanges(self):
    didNow = []
    didSomething = False
    for square in self.stagedSquares:
      if square.text is None:
        self.deleted.append(square.squareId)
      elif square.squareId in self.deleted:
        self.deleted.remove(square.squareId)
      prevState = self[square.squareId]
      didNow.append((copy.deepcopy(prevState),copy.deepcopy(square)))
      if not (prevState.text == square.text and prevState.streets == square.streets):
        didSomething = True
        prevState.text = square.text
        prevState.streets = copy.copy(square.streets)
    if didSomething:
      self.undone = []
      self.stagedSquares = []
      self.done.append(didNow)
      if len(self.done)%5 == 0:
        self.saveDraft()
      self.edited = True

  def undo(self):
    try:
      transaction = self.done.pop()
    except IndexError:
      return
    self.edited = True
    for (prevState,postState) in transaction:
      currentState = self[prevState.squareId]
      currentState.text = prevState.text
      currentState.streets = copy.copy(prevState.streets)
    self.undone.append(transaction)

  def redo(self):
    try:
      transaction = self.undone.pop()
    except IndexError:
      return
    self.edited = True
    for (prevState,postState) in transaction:
      currentState = self[postState.squareId]
      currentState.text = postState.text
      currentState.streets = copy.copy(postState.streets)
    self.done.append(transaction)

  def trimBlankSquaresFromEnd(self):
    try:
      square = self.pop()
    except IndexError:
      pass
    if not square.text is None:
      self.append(square)
    else:
      self.deleted.remove(square.squareId)
      # I am not sure if the return makes for tail recursion, but I hope so.
      return self.trimBlankSquaresFromEnd()

  def getIncommingStreets(self,squareId):
    incommingStreets = []
    for square in self:
      if squareId in square.streets:
        incommingStreets.append(square.squareId)
    return incommingStreets

  def newSquareStreetedFromSquare(self,streetedSquareId):
    newSquareId = self.allocSquare()
    newSquare = Square(newSquareId,"",[])
    selectedSquare = copy.deepcopy(self[streetedSquareId])
    selectedSquare.streets.append(newSquareId)
    self.stageSquare(newSquare)
    self.stageSquare(selectedSquare)
    self.applyChanges()
    return newSquareId

  def getDeleteSquareChanges(self,squareId):
    changes = []
    for incommingStreet in self.getIncommingStreets(squareId):
      if incommingStreet != squareId:
        incommingStreetingSquare = copy.deepcopy(self[incommingStreet])
        incommingStreetingSquare.streets = [value for value in incommingStreetingSquare.streets if value != squareId]
        changes.append(incommingStreetingSquare)
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
      if not street in tree:
        tree.update(self.getTree(street))
    return tree

  def deleteTree(self,squareId):
    squaresForDeletion = set(self.getTree(squareId))
    for square in self:
      if not square.squareId in squaresForDeletion:
        newStreets = []
        for street in square.streets:
          if not street in squaresForDeletion:
            newStreets.append(street)
        if newStreets != square.streets:
          self.stageSquare(Square(square.squareId,square.text,newStreets))
    for square in squaresForDeletion:
      self.stageSquare(Square(square,None,[]))
    self.applyChanges()

  @property
  def json(self):
    self.trimBlankSquaresFromEnd()
    serialized = self.header
    for square in self:
      serialized += json.dumps([square.text,square.streets])
      serialized += "\n"
    return serialized

  @json.setter
  def json(self,text):
    self.header = ""
    readingHeader = True
    squareId = 0
    for line in text.splitlines():
      if not line or line.startswith("#"):
        if readingHeader:
          self.header += line+"\n"
      else:
        readingHeader = False
        try:
          (text,streets) = json.loads(line)
          self.append(Square(squareId,text,streets))
          squareId += 1
        except ValueError as e:
          sys.exit("Cannot load file "+self.fileName+"\n"+str(e))

  @property
  def dot(self):
    dot = "digraph graphname{\n"
    labels = ""
    edges = ""
    for square in self:
      if square.text is not None:
        labels += str(square.squareId)+"[label="+json.dumps(square.title)+"]\n"
        for street in square.streets:
          edges += str(square.squareId)+" -> "+str(street)+"\n"
    dot += labels
    dot += edges
    dot += "}"
    return dot

  def showDiagram(self):
    subprocess.Popen(["dot","-T","xlib","/dev/stdin"],stdin=subprocess.PIPE).communicate(input=self.dot.encode("ascii"))

  def save(self):
    with open(self.fileName,"w") as fd:
      fd.write(self.json)

  def saveDraft(self):
    with open("."+self.fileName+".draft","w") as fd:
      fd.write(self.json)

  def saveDot(self):
    with open(self.fileName+".dot","w") as fd:
      fd.write(self.dot)

class GraphView(urwid.Frame):
  def __init__(self,graph):
    self.__mode = 'mge'
    self.clipboard = ""
    self.graph = graph
    self._selection = 0
    self.history = []
    # clipboard
    self.clipboard = Clipboard(self)
    self.clipboardBoxAdapter = urwid.BoxAdapter(self.clipboard,3)
    # incommingStreets
    self.incommingStreets = IncommingStreetsList(self)
    # current square
    self.currentSquare = CurrentSquare(self)
    self.currentSquareWidget = urwid.Filler(urwid.AttrMap(self.currentSquare,None,"selection"))
    # streets
    self.streets = StreetsList(self)
    # status bar
    self.statusMessage = ""
    self.statusBar = urwid.Text("")
    # command bar
    self.commandBar = CommandBar(self)
    # search box
    self.searchBox = SearchBox(self)
    # main frame
    self.pile = urwid.Pile([self.incommingStreets,self.currentSquareWidget,self.streets])
    self.body = urwid.WidgetPlaceholder(self.pile)
    super(GraphView,self).__init__(self.body,header=self.clipboardBoxAdapter,footer=urwid.BoxAdapter(urwid.ListBox(urwid.SimpleFocusListWalker([self.statusBar,self.commandBar])),height=3))
    self.update()
    self.updateStatusBar()
    self.focus_item = self.currentSquareWidget

  def update(self):
    # clipboard
    self.clipboard.update()
    # incommingStreets
    incommingStreets = []
    for incommingStreet in self.graph.getIncommingStreets(self.selection):
      incommingStreets.append(copy.deepcopy(self.graph[incommingStreet]))
    self.incommingStreets.update(incommingStreets)
    # current square
    self.currentSquare.edit_text = self.graph[self.selection].text
    # streets
    squares = []
    for squareId in self.graph[self.selection].streets:
      try:
        squares.append(copy.deepcopy(self.graph[squareId]))
      except IndexError as e:
        raise IndexError("squareId:"+str(squareId)+"\nselection:"+str(self.selection)+str(self.graph.json))
    self.streets.update(squares)

  def updateStatusBar(self):
    if self.graph.edited:
      edited = "Edited"
    else:
      edited = "Saved"
    if self.mode == 'search':
      try:
        currentSquareId = self.searchBox.focused_square
      except IndexError:
        currentSquareId = 0
    elif self.focus_item == self.incommingStreets:
      try:
        currentSquareId = self.incommingStreets.squares[self.incommingStreets.focus_position].squareId
      except IndexError:
        currentSquareId = self.selection
    elif self.focus_item == self.streets:
      try:
        currentSquareId = self.streets.squares[self.streets.focus_position].squareId
      except IndexError:
        currentSquareId = self.selection
    else:
      currentSquareId = self.selection
    self.statusBar.set_text("Square: "+str(currentSquareId) + " " + edited + " Undo: "+str(len(self.graph.done))+" Redo: "+str(len(self.graph.undone))+" Mode: "+self.mode+" "+self.currentSquare.mode+" | "+self.statusMessage)

  def recordChanges(self):
    if self.graph[self.selection].text != self.currentSquare.edit_text:
      currentSquare = copy.deepcopy(self.graph[self.selection])
      currentSquare.text = self.currentSquare.edit_text
      self.graph.stageSquare(currentSquare)
      self.graph.applyChanges()

  @property
  def selection(self):
    return self._selection

  @selection.setter
  def selection(self,value):
    self.history.append(self.selection)
    self._selection = value

  @property
  def focus_item(self):
    if self.focus_position == 'header':
      return self.clipboard
    elif self.focus_position == 'body':
      return self.contents['body'][0].original_widget.focus_item
    elif self.focus_position == 'footer':
      return self.commandBar

  @focus_item.setter
  def focus_item(self,value):
    if value == self.clipboard:
      self.focus_position = 'header'
    elif value == self.commandBar:
      self.focus_position = 'footer'
    else:
      self.focus_position = 'body'
      self.contents['body'][0].original_widget.focus_item = value

  @property
  def mode(self):
    return self.__mode
  @mode.setter
  def mode(self,value):
    if value == 'mge':
      self.body.original_widget = self.pile
    elif value == 'search':
      self.body.original_widget = self.searchBox
    else:
      raise ValueError("Invalid mode"+value)
    self.__mode = value

  def inEditArea(self):
    return self.focus_item == self.commandBar or self.focus_item == self.currentSquareWidget

  def keypress(self,size,key):
    if self.mode == 'search':
      return self.keypressSearchmode(size, key)
    focusedBeforeProcessing = self.focus_item
    value = self.handleKeypress(size,key)
    if key in keybindings['command-mode.down'] and focusedBeforeProcessing == self.currentSquareWidget and self.focus_item == self.streets:
      self.streets.focus_position = 0
    self.updateStatusBar()
    return value

  def handleKeypress(self,size,key):
    if key in keybindings['leave-and-go-to-mainer-part']:
      self.focus_item = self.currentSquareWidget
    if key in ['left','right','up','down','home','end']:
      self.recordChanges()
      return super(GraphView,self).keypress(size,key)
    if key in keybindings['command-mode']:
      self.recordChanges()
      self.currentSquare.mode = 'command'
    elif key in keybindings['move-down-one-mega-widget']:
      self.recordChanges()
      if self.focus_position == 'header':
        self.focus_position = 'body'
        self.contents['body'][0].original_widget.focus_position = 0
      elif self.focus_position == 'body':
        if self.contents['body'][0].original_widget.focus_position < 2:
          self.contents['body'][0].original_widget.focus_position += 1
        else:
          self.focus_position = 'footer'
      elif self.focus_position == 'footer':
        pass
    elif key in keybindings['move-up-one-mega-widget']:
      self.recordChanges()
      if self.focus_position == 'footer':
        self.focus_position = 'body'
        self.contents['body'][0].original_widget.focus_position = 2
      elif self.focus_position == 'body':
        if self.contents['body'][0].original_widget.focus_position > 0:
          self.contents['body'][0].original_widget.focus_position -= 1
        else:
          self.focus_position = 'header'
      elif self.focus_position == 'header':
        pass
    elif not self.inEditArea() or (self.focus_item == self.currentSquareWidget and self.currentSquare.mode == 'command'):
      self.recordChanges()
      if key in keybindings["back"]:
        if self.history:
          self._selection = self.history.pop()
          self.update()
      elif key in keybindings['move-to-square-zero']:
        self.selection = 0
        self.update()
        self.focus_item = self.currentSquareWidget
      elif key in keybindings['search-mode']:
        self.mode = 'search'
        self.searchBox.searchEdit.edit_text = ""
        self.searchBox.update()
        self.updateStatusBar()
        return None
      elif key in keybindings['jump-to-command-bar']:
        self.focus_item = self.commandBar
      elif key in keybindings['insert-mode']:
        self.currentSquare.mode = 'insert'
        if not self.inEditArea():
          return super(GraphView,self).keypress(size,key)
      elif key in keybindings['show-map']:
        return self.graph.showDiagram()
      elif key in keybindings['command-mode.up']:
        return super(GraphView,self).keypress(size,'up')
      elif key in keybindings['command-mode.down']:
        return super(GraphView,self).keypress(size,'down')
      elif key in keybindings['command-mode.left']:
        return super(GraphView,self).keypress(size,'left')
      elif key in keybindings['command-mode.right']:
        return super(GraphView,self).keypress(size,'right')
      elif key in keybindings['command-mode.undo']:
        self.graph.undo()
        if self.selection >= len(self.graph):
          self.selection = 0
        if self.graph[self.selection].text is None:
          self.selection = 0
        self.update()
      elif key in keybindings['command-mode.redo']:
        self.graph.redo()
        self.update()
      else:
        return super(GraphView,self).keypress(size,key)
    else:
      return super(GraphView,self).keypress(size,key)

  def keypressSearchmode(self,size,key):
    if key == 'esc':
      if self.focus_position != 'body':
        self.focus_position = 'body'
        return None
      else:
        self.currentSquare.mode = 'command'
        self.mode = 'mge'
        self.body.original_widget = self.pile
        self.updateStatusBar()
        return None
    elif self.focus_position == 'body':
      value = self.body.keypress(size,key)
      self.updateStatusBar()
      return value
    else:
      super(GraphView,self).keypress(size,key)

class SquareList(urwid.ListBox):
  def __init__(self,selectionCollor,alignment):
    self.selectionCollor = selectionCollor
    self.alignment = alignment
    self.squares = []
    super(SquareList,self).__init__(urwid.SimpleFocusListWalker([]))

  def update(self,squares=None):
    if squares is not None:
      self.squares = squares
    items = []
    if not self.squares:
      items.append(urwid.AttrMap(urwid.Padding(urwid.SelectableIcon(" ",0),align=self.alignment,width="pack"),None,self.selectionCollor))
    for square in self.squares:
      items.append(urwid.AttrMap(urwid.Padding(urwid.SelectableIcon(square.title,0),align=self.alignment,width="pack"),None,self.selectionCollor))
    self.body.clear()
    self.body.extend(items)

class Clipboard(SquareList):
  def __init__(self,view):
    self.view = view
    super(Clipboard,self).__init__("clipboard","right")

  def keypress(self,size,key):
    if key in keybindings["remove-from-stack"]:
      fcp = self.focus_position
      del self.squares[fcp]
      self.update()
      if fcp < len(self.squares):
        self.focus_position = fcp
    if key in keybindings['street-to-stack-item'] or key in keybindings['street-to-stack-item-no-pop']:
      try:
        fcp = self.focus_position
      except IndexError:
        pass
      else:
        square = self.squares[fcp]
        if not key in keybindings['street-to-stack-item-no-pop']:
          del self.squares[fcp]
        currentSquare = copy.deepcopy(self.view.graph[self.view.selection])
        currentSquare.streets.append(square.squareId)
        self.view.graph.stageSquare(currentSquare)
        self.view.graph.applyChanges()
        self.view.update()
    if key in keybindings['incommingStreet-to-stack-item'] or key in keybindings['incommingStreet-to-stack-item-no-pop']:
      try:
        fcp = self.focus_position
      except IndexError:
        pass
      else:
        square = self.squares[fcp]
        if not key in keybindings['incommingStreet-to-stack-item-no-pop']:
          del self.squares[fcp]
        square.streets.append(self.view.selection)
        self.view.graph.stageSquare(square)
        self.view.graph.applyChanges()
        self.view.update()
    else:
      return super(Clipboard,self).keypress(size,key)

class CurrentSquare(urwid.Edit):
  def __init__(self,view):
    self.mode = 'command'
    self.selection = (0,0)
    self.view = view
    super(CurrentSquare,self).__init__(edit_text="",align="left",multiline=True)
    self.cursorCords = (0,0)

  def render(self,size,focus=None):
    self.move_cursor_to_coords(size,self.cursorCords[0],self.cursorCords[1])
    return super(CurrentSquare,self).render(size,True)

  def keypress(self,size,key):
    if key in keybindings['new-square-streeted-to-previous-square']:
      prevSquare = self.view.history[-1]
      self.view.recordChanges()
      newSquareId = self.view.graph.newSquareStreetedFromSquare(prevSquare)
      self.view.selection = newSquareId
      self.view.history.append(prevSquare)
      self.view.update()
    if self.mode =='command':
      if key in keybindings['add-to-stack']:
        self.view.clipboard.squares.append(self.view.graph[self.view.selection])
        self.view.update()
      elif key in keybindings['delete-square']:
        if self.view.selection != 0:
          self.view.graph.deleteSquare(self.view.selection)
          while True:
            prevSelection = self.view.history.pop()
            if prevSelection != self.view.selection:
              self.view.selection = prevSelection
              break
        else:
          self.view.statusMessage = "Cannot delete square 0."
        self.view.update()
      elif key in keybindings['delete-tree']:
        self.view.graph.deleteTree(self.view.selection)
        self.view.update()
      elif not self.valid_char(key):
        value = super(CurrentSquare,self).keypress(size,key)
        self.cursorCords = self.get_cursor_coords(size)
        return value
      else:
        return key
    else:
      value = super(CurrentSquare,self).keypress(size,key)
      self.cursorCords = self.get_cursor_coords(size)
      return value

class SquareNavigator(SquareList):
  def __init__(self,view,selectionCollor,alignment):
    self.alignment = alignment
    super(SquareNavigator,self).__init__(selectionCollor,alignment)

  def keypress(self,size,key):
    if key in keybindings['new-square']:
      self.newSquare()
    if key in [self.alignment,'enter'] or key in keybindings['insert-mode']:
      if self.squares:
        self.view.recordChanges()
        self.view.selection = self.squares[self.focus_position].squareId
        self.view.update()
        if not key == self.alignment:
          self.view.focus_item = self.view.currentSquareWidget
      else:
        self.newSquare()
    if key in keybindings["delete-square"]:
      if self.squares:
        squareId = self.squares[self.focus_position].squareId
        if squareId != 0:
          self.view.graph.deleteSquare(squareId)
          self.view.update()
        else:
          self.view.statusMessage = "Cannot delete square 0."
    if key in keybindings["delete-tree"]:
      if self.squares:
        squareId = self.squares[self.focus_position].squareId
        if squareId != 0:
          self.view.graph.deleteTree(squareId)
          self.view.update()
        else:
          self.view.statusMessage = "Cannot delete square 0."
    if key in keybindings["add-to-stack"]:
      if self.squares:
        self.view.clipboard.squares.append(self.squares[self.focus_position])
        fcp = self.focus_position
        self.view.update()
        self.focus_position = fcp
    else:
      return super(SquareNavigator,self).keypress(size,key)

class IncommingStreetsList(SquareNavigator):
  def __init__(self,view):
    self.view = view
    super(IncommingStreetsList,self).__init__(view,'incommingStreet_selected','left')

  def newSquare(self):
    self.view.recordChanges()
    squareId = self.view.graph.allocSquare()
    square = Square(squareId,"",[self.view.selection])
    self.view.selection = square.squareId
    self.view.graph.stageSquare(square)
    self.view.graph.applyChanges()
    self.view.update()
    self.view.focus_item = self.view.currentSquareWidget
    self.view.currentSquare.mode = 'insert-mode'

  def keypress(self,size,key):
    if key in ['right']:
      self.view.focus_item = self.view.streets
      try:
        self.view.streets.focus_position = 0
      except IndexError:
        pass
    if key in keybindings['street-or-back-street-last-stack-item']:
      if self.view.clipboard.squares:
        square = self.view.clipboard.squares.pop()
        square.streets.append(self.view.selection)
        self.view.graph.stageSquare(square)
        self.view.graph.applyChanges()
        self.view.update()
        self.focus_position = len(self.squares) - 1
    elif key in keybindings['remove-street-or-incommingStreet']:
      try:
        fcp = self.focus_position
        square = self.squares[fcp]
        square.streets.remove(self.view.selection)
        self.view.graph.stageSquare(square)
        self.view.graph.applyChanges()
        self.view.update()
      except IndexError:
        pass
    else:
      return super(IncommingStreetsList,self).keypress(size,key)

class StreetsList(SquareNavigator):
  def __init__(self,view):
    self.view = view
    super(StreetsList,self).__init__(view,'street_selected','right')

  def newSquare(self):
    self.view.recordChanges()
    newSquareId = self.view.graph.newSquareStreetedFromSquare(self.view.selection)
    self.view.selection = newSquareId
    self.view.update()
    self.view.focus_item = self.view.currentSquareWidget

  def keypress(self,size,key):
    if key in keybindings['move-square-up']:
      sel = copy.deepcopy(self.view.graph[self.view.selection])
      fcp = self.focus_position
      if fcp >= 1:
        street = sel.streets[fcp]
        prevStreet = sel.streets[fcp - 1]
        sel.streets[fcp] = prevStreet
        sel.streets[fcp - 1] = street
        self.view.graph.stageSquare(sel)
        self.view.graph.applyChanges()
        self.view.update()
        self.focus_position = fcp - 1
    elif key in keybindings['move-square-down']:
      sel = copy.deepcopy(self.view.graph[self.view.selection])
      fcp = self.focus_position
      if fcp < len(sel.streets):
        street = sel.streets[fcp]
        nextStreet = sel.streets[fcp + 1]
        sel.streets[fcp] = nextStreet
        sel.streets[fcp + 1] = street
        self.view.graph.stageSquare(sel)
        self.view.graph.applyChanges()
        self.view.update()
        self.focus_position = fcp + 1
    elif key in ['left']:
      self.view.focus_item = self.view.incommingStreets
    elif key in keybindings['street-or-back-street-last-stack-item']:
      if self.view.clipboard.squares:
        if self.squares:
          fcp = self.focus_position
        else:
          fcp = -1
        square = self.view.clipboard.squares.pop()
        sel = copy.deepcopy(self.view.graph[self.view.selection])
        sel.streets.insert(fcp + 1,square.squareId)
        self.view.graph.stageSquare(sel)
        self.view.graph.applyChanges()
        self.view.update()
        self.focus_position = fcp + 1
    elif key in keybindings['remove-street-or-incommingStreet']:
      try:
        fcp = self.focus_position
        square = self.squares[fcp]
        selectedSquare = copy.deepcopy(self.view.graph[self.view.selection])
        selectedSquare.streets.remove(square.squareId)
        self.view.graph.stageSquare(selectedSquare)
        self.view.graph.applyChanges()
        self.view.update()
      except IndexError:
        pass
    else:
      return super(StreetsList,self).keypress(size,key)

class SearchBox(urwid.ListBox):
  def __init__(self,view):
    self.view = view
    self.squares = self.view.graph
    super(SearchBox,self).__init__(urwid.SimpleFocusListWalker([]))
    self.searchEdit = urwid.Edit()
    self.body.append(self.searchEdit)
    self.update()

  def update(self):
    self.squares = []
    items = []
    for square in self.view.graph:
      if square.text is not None:
        if self.searchEdit.edit_text in square.text:
          self.squares.append(square)
          items.append(urwid.Padding(urwid.SelectableIcon(square.title,0),align='left',width="pack"))
    del self.body[1:]
    self.body.extend(items)
    self.focus_position = 0

  @property
  def focused_square(self):
    if self.focus_position > 0:
      return self.squares[self.focus_position-1].squareId
    else:
      raise IndexError("No focused square.")

  def keypress(self,size,key):
    if self.focus_position == 0:
      if key == 'enter':
        try:
          self.focus_position = 1
          return super(SearchBox,self).keypress(size,key)
        except IndexError:
          pass
      else:
        value = super(SearchBox,self).keypress(size,key)
        self.update()
        return value
    if key in keybindings['command-mode.up']:
      return super(SearchBox,self).keypress(size,'up')
    elif key in keybindings['command-mode.down']:
      return super(SearchBox,self).keypress(size,'down')
    elif key in keybindings['jump-to-command-bar']:
      self.view.focus_position = 'footer'
    elif key == 'enter':
      self.view.selection = self.focused_square
      self.view.currentSquare.mode = 'command'
      self.view.mode = 'mge'
      self.view.update()
    elif key in keybindings['insert-mode']:
      self.view.selection = self.focused_square
      self.view.currentSquare.mode = 'insert'
      self.view.mode = 'mge'
      self.view.update()
    elif key in keybindings['add-to-stack']:
      self.view.clipboard.squares.append(self.view.graph[self.focused_square])
      self.view.update()
    else:
      return super(SearchBox,self).keypress(size,key)

class CommandBar(urwid.Edit):
  def __init__(self,view):
    self.view = view
    self.edit = self
    super(CommandBar,self).__init__(":")

  def keypress(self,size,key):
    if key != 'enter':
      return super(CommandBar,self).keypress(size,key)
    success = False
    com = self.edit.edit_text
    if com == "savedot":
      success = True
      self.view.graph.saveDot()
    else:
      if "w" in com:
        success = True
        try:
          self.view.recordChanges()
          self.view.graph.save()
          self.view.graph.edited = False
        except FileNotFoundError as e:
          self.edit.set_caption("Unable to save:"+str(e)+"\n:")
      if "q" in com:
        success = True
        if self.view.graph.edited and "!" not in com:
          self.edit.set_caption("Not quiting. Save your work first, or use 'q!'\n:")
        else:
          raise urwid.ExitMainLoop()
      try:
        newSelection = int(com)
        if newSelection >= 0 and newSelection < len(self.view.graph) and self.view.graph[newSelection].text is not None:
          self.view.selection = newSelection
          self.view.update()
          self.view.focus_item = self.view.currentSquareWidget
          self.view.currentSquare.mode = 'command'
          success = True
        else:
          self.edit.set_caption("Cannot jump to "+com+". Square does not exist.\n:")
      except ValueError:
        pass
    if success:
      self.view.focus_item = self.view.currentSquareWidget
      self.edit.edit_text = ""
    else:
      self.edit.set_caption(com + " is not a valid mge command.\n:")

keybindings = {
 # global/command-mode
 'back' : ['meta left','b'],
 'street-or-back-street-last-stack-item' : ['p'],
 'add-to-stack' : ['c'],
 'move-square-up' : ['ctrl up'],
 'move-square-down' : ['ctrl down'],
 'new-square' : ['n'],
 'new-square-streeted-to-previous-square' : ['meta enter'],
 'remove-street-or-incommingStreet' : ['d'],
 'delete-square' : ['delete'],
 'delete-tree' : ['ctrl delete'],
 'move-to-square-zero' : ['.'],
 'jump-to-command-bar' : [':'],
 'leave-and-go-to-mainer-part' : ['esc'],
 'move-up-one-mega-widget' : ['meta up'],
 'move-down-one-mega-widget' : ['meta down'],
 'command-mode' : ['esc'],
 'command-mode.up' : ['k'],
 'command-mode.down' : ['j'],
 'command-mode.left' : ['h'],
 'command-mode.right' : ['l'],
 'command-mode.undo' : ['u'],
 'command-mode.redo' : ['ctrl r'],
 'insert-mode' : ['i'],
 'search-mode' : ['/'],
 'show-map': ['m'],
 # stack area
 'remove-from-stack' : ['d'],
 'street-to-stack-item-no-pop' : ['ctrl right'],
 'street-to-stack-item' : ['right'],
 'incommingStreet-to-stack-item-no-pop' : ['ctrl left'],
 'incommingStreet-to-stack-item' : ['left'],
 }
pallet = [('incommingStreet_selected', 'white', 'dark blue')
         ,('street_selected', 'white', 'dark red')
         ,('selection','black','white')
         ,('clipboard','white','dark gray')]

if __name__ == "__main__":
  parser = optparse.OptionParser(usage = "tg FILE",description = "Edit simple text graph file(tg file) using a simple,fast TUI interface.")
  options,args = parser.parse_args(sys.argv[1:])

  if not len(args) == 1:
    sys.exit("mge expects to be passed a single file path for editing. Use --help for help.")

  graphView = GraphView(TextGraph(args[0]))
  urwid.MainLoop(graphView,pallet).run()
