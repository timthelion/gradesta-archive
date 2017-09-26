from math import pow

def max_neighborhood_size(upstream = 0, downstream = 0, stack = 0, backlinks = 0,backscatter = 0, forwardscatter = 0):
  directly_downstream = pow(stack, downstream)
  print("Directly downstream: %f"%directly_downstream)
  downstream_backscatter = directly_downstream * pow(backlinks, backscatter)
  print("Downstream backscatter: %f"%downstream_backscatter)
  directly_upstream = pow(backlinks, upstream)
  print("Directly upstream: %f"%directly_upstream)
  upstream_forwardscatter = directly_upstream * pow(stack, forwardscatter)
  print("Upstream forwardscatter: %f"%upstream_forwardscatter)
  return directly_downstream + downstream_backscatter + directly_upstream + upstream_forwardscatter
