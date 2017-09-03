"Get (self) sub_arrow reference to `arr`"
sub_arrow(arr::CompArrow) = sub_arrow(arr, 1)

"All source (projecting) sub_ports"
src_sub_ports(arr::CompArrow)::Vector{SubPort} = filter(is_src, sub_ports(arr))

"All source (projecting) sub_ports"
all_src_sub_ports(arr::CompArrow)::Vector{SubPort} = filter(is_src, all_sub_ports(arr))

"All destination (receiving) sub_ports"
dst_sub_ports(arr::CompArrow)::Vector{SubPorts} = filter(is_dst, sub_ports(arr))

"All source (projecting) sub_ports"
all_dst_sub_ports(arr::CompArrow)::Vector{SubPort} = filter(is_dst, all_sub_ports(arr))

"is `port` a reference?"
is_ref(sport::SubPort) = true

"Is `sport` a port on one of the `SubArrow`s within `arr`"
function in(sport::SubPort, arr::CompArrow)::Bool
  if parent(sport) == arr
    nsubports = num_all_sub_ports(arr)
    1 <= sport.vertex_id <= nsubports
  end
  false
end

"Is `port` within `arr` but not on boundary"
function strictly_in{I, O}(port::SubPort, arr::CompArrow{I, O})::Bool
  if parent(port) == arr
    nsubports = num_sub_ports(arr)
    return I + O < port.vertex_id <= I + O + nsubports
  end
  false
end

"Is `arr` a sub_arrow of composition `c_arr`"
in(arr::SubArrow, c_arr::CompArrow)::Bool = arr in all_sub_arrows(p)

"Number of sub_arrows in `c_arr` including `c_arr`"
num_all_sub_arrows(arr::CompArrow) = length(arr.sub_arrs)

"Number of sub_arrows"
num_sub_arrows(arr::CompArrow) = num_all_sub_arrows(arr) - 1

#FIXME Should this be `sub_ports`?
"All ports(references) of a sub_arrow(reference)"
ports(sarr::SubArrow)::Vector{SubPort} =
  [SubPort(sarr.parent, v_id) for v_id in sarr.parent.sub_arr_vertices[sarr.id]]

  #FIXME Should this be `sub_port`?
"Ith SubPort on `arr`"
port(arr::SubArrow, i::Integer)::SubPort = ports(arr)[i]

#FIXME Should this be `sub_port`?
"Ith SubPort on `arr`"
port(arr::SubArrow, name::Symbol)::SubPort = port(arr, port_id(name))

"`PortProp`s of `subport` are `PortProp`s of `Port` it refers to"
port_props(subport::SubPort) = port_props(deref(subport))

"Ensore we find the port"
must_find(i) = i == 0 ? throw(DomainError()) : i

"Get the id of a port from its name"
port_id(port::Arrow, name::Symbol) = must_find(findfirst(port_names(arr), name))

"Get parent of any `x ∈ xs` and check they all have the same parent"
function anyparent(xs::Vararg{<:Union{SubArrow, SubPort}})::CompArrow
  if !same(parent.(xs))
    println("Different parents!")
    throw(DomainError())
  end
  @show typeof(xs)
  parent(first(xs))
end

"Is this `SubArrow` the parent of itself?"
self_parent(sarr::SubArrow) = parent(sarr) == deref(sarr)

link_ports!(l, r) =
  link_ports!(promote_left_port(l), promote_right_port(r))

promote_port(port::Port{<:CompArrow}) = SubPort(port.arrow, port.index)
promote_port(port::SubPort) = port

promote_left_port(port::SubPort) = promote_port(port)
promote_right_port(port::SubPort) = promote_port(port)
promote_left_port(port::Port) = promote_port(port)
promote_right_port(port::Port) = promote_port(port)

# # TODO: Check here and below that Port is valid boundary, i.e. port.arrow = c
# # TODO: DomainError not assert
# @assert parent(r) == c
src_port(srcarr, src_id) =
  self_parent(srcarr) ? in_port(srcarr, src_id) : out_port(srcarr, src_id)

dst_port(dst_arr, dst_id) =
  self_parent(dst_arr) ? out_port(dst_arr, dst_id) : in_port(dst_arr, dst_id)

promote_left_port(pid::Tuple{SubArrow, <:Integer}) = src_port(pid...)
promote_right_port(pid::Tuple{SubArrow, <:Integer}) = dst_port(pid...)

# Graph traversal
"is vertex `v` a destination, i.e. does it project more than 0 edges"
is_dst(g::LG.DiGraph, v::Integer) = LG.indegree(g, v) > 0

"is vertex `v` a source, i.e. does it receive more than 0 edges"
is_src(g::LG.DiGraph, v::Integer) = LG.outdegree(g, v) > 0

"Is `port` a destination. i.e. does corresponding vertex project more than 0"
is_dst(port::SubPort) = lg_to_p(is_dst, port)

"Is `port` a source,  i.e. does corresponding vertex receive more than 0 edge"
is_src(port::SubPort) = lg_to_p(is_src, port)

"All neighbors of `port`"
neighbors(port::SubPort)::Vector{SubPort} = v_to_p(LG.neighbors, port)

"`Subport`s of ports which `port` receives from"
in_neighbors(port::SubPort)::Vector{SubPort} = v_to_p(LG.in_neighbors, port)

"`Subport`s which `port` projects to"
out_neighbors(port::SubPort)::Vector{SubPort} = v_to_p(LG.out_neighbors, port)

"Return the number of `SubPort`s which begin at `port`"
out_degree(port::SubPort)::Integer = lg_to_p(LG.outdegree, port)

"Number of `SubPort`s which end at `port`"
in_degree(port::SubPort)::Integer = lg_to_p(LG.indegree, port)

"All neighbouring `SubPort`s of `subarr`, each port connected to each outport"
function out_neighbors(subarr::Arrow)
  ports = Port[]
  for port in out_ports(subarr)
    for neighport in out_neighbors(port)
      push!(ports, neighport)
    end
  end
  ports
end

Component = Vector{SubPort}
Components = Vector{Component}

"""Partition the ports into weakly connected equivalence classes"""
function weakly_connected_components(arr::CompArrow)::Components
  cc = weakly_connected_components(arr.edges)
  pi = i->port_index(arr, i)
  map(component->pi.(component), cc)
end

"""Partition the ports into weakly connected equivalence classes"""
function weakly_connected_component(edges::LG.DiGraph, i::Integer)::Vector{Int}
  cc = weakly_connected_components(edges)
  filter(comp -> i ∈ comp, cc)[1]
end

"Ports in `arr` weakly connected to `port`"
function weakly_connected_component(port::SubPort)::Component
  # TODO: Shouldn't need to compute all connected components just to compute
  arr = parent(port)
  components = weakly_connected_components(arr)
  first((comp for comp in components if port ∈ comp))
end

"`src_port.arrow` such that `src_port -> port`"
src_arrow(port::SubPort)::SubArrow = sub_arrow(src(port))

"`src_port` such that `src_port -> port`"
function src(port::SubPort)::SubPort
  if is_src(port)
    port
  else
    in_neighs = in_neighbors(port)
    @assert length(in_neighs) == 1
    first(in_neighs)
  end
end

"Should `port` be a src in context `arr`. Possibly false iff is_wired_ok = false"
function should_src(port::SubPort, arr::CompArrow)::Bool
  if !(port in all_sub_ports(arr))
    errmsg = "Port $port not in ports of $(name(arr))"
    println(errmsg)
    throw(DomainError())
  end
  if strictly_in(port, parent(port))
    is_out_port(port)
  else
    is_in_port(port)
  end
end

"Should `port` be a dst in context `arr`? Maybe false iff is_wired_ok=false"
function should_dst(port::SubPort, arr::CompArrow)::Bool
  if !(port in all_sub_ports(arr))
    errmsg = "Port $port not in ports of $(name(arr))"
    println(errmsg)
    throw(DomainError())
  end
  if strictly_in(port, parent(port))
    is_in_port(port)
  else
    is_out_port(port)
  end
end

"Is `arr` wired up correctly"
function is_wired_ok(arr::CompArrow)::Bool
  for i = 1:LG.nv(arr.edges)
    if should_dst(port_index(arr, i), arr)
      # If it should be a desination
      if !(LG.indegree(arr.edges, i) == 1 &&
           LG.outdegree(arr.edges, i) == 0)
      # TODO: replace error with lens
        errmsg = """vertex $i Port $(port_index(arr, i)) should be a dst but
                    indeg is $(LG.indegree(arr.edges, i)) (notbe 1)
                    outdeg is $(LG.outdegree(arr.edges, i) == 0)) (not 0)
                  """
        warn(errmsg)
        return false
      end
    end
    if should_src(port_index(arr, i), arr)
      # if it should be a source
      if !(LG.outdegree(arr.edges, i) > 0 || LG.indegree(arr.edges) == 1)
        errmsg = """vertex $i Port $(port_index(arr, i)) is source but out degree is
        $(LG.outdegree(arr.edges, i)) (should be >= 1)"""
        warn(errmsg)
        return false
      end
    end
  end
  true
end

## Printing ##

function string(port::SubPort)
  a = "SubArrow $(port.vertex_id) of $(name(parent(port))) - "
  b = string(deref(port))
  string(a, b)
end

print(io::IO, p::SubPort) = print(io, string(p))
show(io::IO, p::SubPort) = print(io, p)

"Parent of a `SubPort` is `parent` of attached `Arrow`"
parent(subport::SubPort) = subport.parent
