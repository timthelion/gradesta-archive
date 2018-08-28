#!/usr/bin/python3
import os
import zmq
import gradesta_pb2
import uuid
import sys
import threading
import time

FIELD=0   # Optional field
RFIELD= 1 # Repeated field
UDICT=2   # Update dict
ODICT=3   # Overwrite entries

cell_runtime_merge_policy = {
 "cell": FIELD,
 "update_count": FIELD,
 "click_count": FIELD,
 "creation_id": FIELD,
 "cell_runtime_modes": ODICT,
 "cell_modes": ODICT,
 "link_modes": ODICT,
 "for_link_modes": ODICT,
 "back_link_modes": ODICT,
 "supported_encodings": RFIELD,
 "role_permissions": ODICT,
}

metadata_merge_policy = {
 "name": FIELD,
 "source_url": FIELD,
 "privacy_policy": FIELD,
}

client_state_merge_policy = {
 "service_state": (FIELD, {
  "cells": (UDICT, cell_runtime_merge_policy),
  "index": FIELD,
  "on_disk_state": FIELD,
  "log": ODICT,
  "metadata": (FIELD, metadata_merge_policy),
  "cell_template": (FIELD, cell_runtime_merge_policy),
  "service_state_modes": ODICT,
 }),
 "clients": (UDICT, {
  "status": FIELD,
  "metadata": (FIELD, metadata_merge_policy),
 }),
 "manager": (FIELD, {
  "metadata": (FIELD, metadata_merge_policy),
 }),
 "selections": (UDICT, {
  "name": FIELD,
  "update_count": FIELD,
  "clients": ODICT,
  "cursors": (UDICT, {
  }),
  "symbols": (UDICT, {
  }),
  "production_rules": (UDICT, {
  }),
  "vars": ODICT,
  "max_length": FIELD,
 }),
}


def merge(new, old, policy):
 for fd, v in new.ListFields():
  if fd.name in policy:
   action = policy[fd.name]

   if action == FIELD:
    try:
     old.__setattr__(fd.name, v)
    except (AttributeError, TypeError):
     old.__getattribute__(fd.name).CopyFrom(v)
    continue

   elif action == RFIELD:
    orf = old.__getattribute__(fd.name)
    while True: # This is the only why I found to clear a repeated field. Please shoot me.
     try:
      orf.pop()
     except IndexError:
      break
    orf.extend(v)
    continue

   elif action == ODICT or action == UDICT:
    for k, val in v.items():
     old.__getattribute__(fd.name)[k] = val
     if action == UDICT and val.delete:
      del old.__getattribute__(fd.name)[k]
    continue

   try:
    action, subpolicy = action
    if action == FIELD:
     merge(v, old.__getattribute__(fd.name), subpolicy)
     continue
    if action == UDICT:
     old_dict = old.__getattribute__(fd.name)
     for entry_name, ev in v.items():
      if entry_name in old_dict:
       try:
        deleted = ev.deleted
       except AttributeError:
        deleted = False
       if deleted:
        del old_dict[entry_name]
       else:
        merge(ev, old_dict[entry_name], subpolicy)
      else:
       old_dict[entry_name].CopyFrom(ev)
   except TypeError as e:
    print("TypeError", fd.name, v)
    pass


class Client():
 def __init__(self, name='', source_url='', privacy_policy=''):
  self.request = 1
  self.id = os.path.split(os.getcwd())[-1]
  context = zmq.Context()
  self.inproc_sock = context.socket(zmq.PAIR)
  self.inproc_sock.bind("inproc://messages")
  self.command_sock = context.socket(zmq.PAIR)
  self.command_sock.bind("inproc://commands")
  self.truth = gradesta_pb2.ClientState()
  self.staged = gradesta_pb2.ClientState()
  self.staged.service_state.round.full_sync = True
  client = self.staged.clients[self.id]
  metadata = gradesta_pb2.ActorMetadata()
  metadata.name=name
  metadata.source_url=source_url
  metadata.privacy_policy=privacy_policy
  client.metadata.CopyFrom(metadata)
  self.lm = None
  def recv_loop():
   sock = context.socket(zmq.PAIR)
   sock.bind("ipc://client.gradesock")
   inproc_sock = context.socket(zmq.PAIR)
   inproc_sock.connect("inproc://messages")
   command_sock = context.socket(zmq.PAIR)
   command_sock.connect("inproc://commands")
   poller = zmq.Poller()
   poller.register(inproc_sock, zmq.POLLIN)
   poller.register(sock, zmq.POLLIN)
   poller.register(command_sock, zmq.POLLIN)
   time.sleep(0.04)
   while True:
    socks = dict(poller.poll())
    if inproc_sock in socks:
     m = inproc_sock.recv()
     sock.send(m)
    if sock in socks:
     m = gradesta_pb2.ClientState()
     m.ParseFromString(sock.recv())
     merge(m, self.truth, client_state_merge_policy)
     self.clean_truth()
     self.lm=m
     self.update(m)
    if command_sock in socks:
     self.control(command_sock.recv())

  t = threading.Thread(name='client proc', target=recv_loop, daemon=True)
  t.start()
  time.sleep(0.08)

 def get_in_view(self):
  in_view = set()
  for selection in self.truth.selections.values():
   if self.id in selection.clients and selection.clients[self.id] != gradesta_pb2.Selection.NONE:
    for cursor in selection.cursors.values():
     for k, v in cursor.in_view.items():
      if v:
       in_view.add(k)
  return in_view

 def clean_truth(self):
  in_view = self.get_in_view()
  for_deletion = set()
  for k in self.truth.service_state.cells.keys():
   if k not in in_view:
    for_deletion.add(k)
  for k in for_deletion:
   del self.truth.service_state.cells[k]

 def _send(self, m):
  m.service_state.round.client_of_origin = self.id
  m.service_state.round.request = self.request
  self.request += 1
  self.inproc_sock.send(m.SerializeToString())

 def commit(self):
  for sid, selection in self.staged.selections.items():
   if sid in self.truth.selections:
    print("Update_count", self.truth.selections[sid].update_count)
    selection.update_count = self.truth.selections[sid].update_count + 1
  self._send(self.staged)
  self.staged = gradesta_pb2.ClientState()

 def new_selection(self, selection_name):
  return Selection(self, selection_name)

 def run_command(self, msg):
  self.command_sock.send(msg)

 @property
 def selections(self):
  selections = []
  for id in self.truth.selections.keys():
   selections.append(Selection(self, id=id))
  return selections


class Selection:
 def __init__(self, client, status=None, id=None):
  if id is None:
   self.id = str(uuid.uuid4())
  else:
   self.id = id
  self.client = client
  if self.id not in self.client.truth.selections: # if new
   s = self.staged
   s.update_count = 1
   s.clients[client.id] = status
   self.update_count = 2
  else:
   t = self.truth
   self.update_count = t.update_count
  self.symbol_id = 0
  self.var_id = 0

 @property
 def staged(self):
  return self.client.staged.selections[self.id]

 @property
 def truth(self):
  return self.client.truth.selections[self.id]

 def add_symbol(self, direction, dimension, var, relabel):
  while self.symbol_id in self.truth.symbols or self.symbol_id in self.staged.symbols:
   self.symbol_id += 1
  sym = self.staged.symbols[self.symbol_id]
  sym.direction = direction
  sym.dimension = dimension
  sym.var = var
  sym.relabel = relabel
  return self.symbol_id

 def add_var(self, val):
  while self.var_id in self.truth.vars or self.var_id in self.staged.vars:
   self.var_id += 1
  self.staged.vars[self.var_id] = val
  return self.var_id

 def add_production_rule(self, lhs, rhs):
  s = self.staged
  s.production_rules[lhs].symbols.extend(rhs)

 def add_cursor(self, center, start_symbol):
  return Cursor(self, center, start_symbol)

 @property
 def cursors(self):
  cursors = []
  for id in self.truth.cursors.keys():
   cursors.append(Cursor(self, id))
  return cursors

 @property
 def active_cursor(self):
  order = 0
  active_cursor = None
  for cursor in self.cursors:
   if cursor.truth.order >= order:
    active_cursor = cursor
    order = cursor.truth.order
  return active_cursor

class Cursor:
 def __init__(self, selection, center, start_symbol=None):
  self.selection = selection
  self.center = center
  s = self.selection.staged
  if center not in selection.truth.cursors:
   s.cursors[center].deleted = False
  if start_symbol is not None:
   s.cursors[center].start_symbol = start_symbol

 @property
 def truth(self):
  return self.selection.truth.cursors[self.center]

 @property
 def start_symbol(self):
  return self.truth.start_symbol

 def move(self, new_center):
  s = self.selection.staged
  s.cursors[self.center].deleted = True
  s.cursors[new_center].deleted = False
  s.cursors[new_center].start_symbol = self.start_symbol
  self.center = new_center

 def delete(self):
  s = self.selection.client.staged.selections[self.selection.id]
  s.cursors[self.center].deleted = True
