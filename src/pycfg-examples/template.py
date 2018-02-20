import sys
def print_arg_zero(*args):
	return __py_cfg_call(0,*args)

def __py_cfg_internal_function_print_arg_zero(*args):
	try:
		print(sys.argv[0]) # □:0
	except Exception as e:
		raise e
	if True: # □:0
		
		return 2,[]
	return None,[]
def print_bar(*args):
	return __py_cfg_call(2,*args)

def __py_cfg_internal_function_print_bar(*args):
	try:
		print("bar") # □:2
	except Exception as e:
		raise e
	return None,[]

__py_cfg_squares = {0:__py_cfg_internal_function_print_arg_zero,2:__py_cfg_internal_function_print_bar}

def __py_cfg_call(__py_cfg_square,*args):
  __py_cfg_bag = list(args)
  while __py_cfg_square is not None:
    __py_cfg_square,__py_cfg_bag = __py_cfg_squares[__py_cfg_square](*__py_cfg_bag)
  return __py_cfg_bag

__py_cfg_call(0,[])


