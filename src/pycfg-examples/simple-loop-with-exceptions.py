def main(*args):
	return __py_cfg_call(0,*args)

def __py_cfg_internal_function_main(*args):
	try:
		name = input("What is your name? ") # □:0
	except Exception as e:
		raise e
	if True: # □:0
		
		return 10,[name]
	return None,[]
def introduce_yourself(*args):
	return __py_cfg_call(1,*args)

def __py_cfg_internal_function_introduce_yourself(*args):
	[name,age] = list(args)
	try:
		print("Hello "+name) # □:1
		print("Your age is "+str(age)) # □:1
	except Exception as e:
		raise e
	return None,[]
def ask_age(*args):
	return __py_cfg_call(10,*args)

def __py_cfg_internal_function_ask_age(*args):
	[name] = list(args)
	try:
		age_string = input("Enter your age: ") # □:10
		age = int(age_string) # □:10
	except ValueError: # □:10
		
		return 11,[name,age_string]
	except Exception as e:
		raise e
	if age >= 13: # □:10
		
		return 1,[name,age]
	if True: # □:10
		
		return 2,[name,age]
	return None,[]
def complain_about_invalid_age(*args):
	return __py_cfg_call(11,*args)

def __py_cfg_internal_function_complain_about_invalid_age(*args):
	[name,age_string] = list(args)
	try:
		print(age_string+" is not a valid integer.") # □:11
	except Exception as e:
		raise e
	if True: # □:11
		
		return 10,[name]
	return None,[]
def refuse_to_talk(*args):
	return __py_cfg_call(2,*args)

def __py_cfg_internal_function_refuse_to_talk(*args):
	[name,age] = list(args)
	try:
		print("I don't talk to minors.") # □:2
	except Exception as e:
		raise e
	if True: # □:2
		
		return 9,[name,age]
	return None,[]
def count_the_years(*args):
	return __py_cfg_call(5,*args)

def __py_cfg_internal_function_count_the_years(*args):
	[age] = list(args)
	try:
		age = age + 1 # □:5
		print("One year has passed, and you are now "+str(age)+" old.") # □:5
	except Exception as e:
		raise e
	if age < 13: # □:5
		
		return 5,[age]
	if True: # □:5
		
		return None,[age]
	return None,[]
def wait_till_youre_older(*args):
	return __py_cfg_call(9,*args)

def __py_cfg_internal_function_wait_till_youre_older(*args):
	[name,age] = list(args)
	try:
		[age] = count_the_years(age) # □:9
	except Exception as e:
		raise e
	if True: # □:9
		
		return 1,[name,age]
	return None,[]

__py_cfg_squares = {0:__py_cfg_internal_function_main,1:__py_cfg_internal_function_introduce_yourself,10:__py_cfg_internal_function_ask_age,11:__py_cfg_internal_function_complain_about_invalid_age,2:__py_cfg_internal_function_refuse_to_talk,5:__py_cfg_internal_function_count_the_years,9:__py_cfg_internal_function_wait_till_youre_older}

def __py_cfg_call(__py_cfg_square,*args):
  __py_cfg_bag = list(args)
  while __py_cfg_square is not None:
    __py_cfg_square,__py_cfg_bag = __py_cfg_squares[__py_cfg_square](*__py_cfg_bag)
  return __py_cfg_bag

__py_cfg_call(0,[])

