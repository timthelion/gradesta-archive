# Copyright 2018 Timothy Hobbs AGPLv3

class FISO:
 """
 First in Sorted out

 This class allows you to add objects which can
 be indexed using an integer and then take them
 out in the right order, waiting untill all the
 messages have been received.
 
 >>> fiso = FISO(lambda a: i)
 >>> fiso.add(0)
 >>> fiso.add(1)
 >>> fiso.add(3)
 >>> fiso.next()
 0
 >>> fiso.next()
 1
 >>> fiso.next()
 Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
  File "FISO.py", line 17, in next
 raise StopIteration()
 >>> fiso.add(2)
 >>> fiso.next()
 2
 >>> fiso.next()
 3
 """

 def __init__(self, get_index, start_index = 0):
  self.index = start_index
  self.que = {}
  self.get_index = get_index

 def add(self,m):
  self.que[self.get_index(m)] = m

 def next(self):
  if self.index in self.que:
   next = self.que[self.index]
   del self.que[self.index]
   self.index += 1
   return next
  else:
   raise StopIteration()
