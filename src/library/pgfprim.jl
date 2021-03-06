"This file contains the pgfs of primitive arrows."

# FIXME: at the moment all of the pgfs are manually constructed.
# at least want to just add the parameter part to the arrow and
# not have to construct the arrow along with the parameter.

pgf(arr, const_in) = pgf(arr)

function pgf(arr::MulArrow, const_in)
  "As f^(-1)(z; θ) = (z/θ, θ), then the pgf becomes r(x, y) = (x*y, y)."
  ## HAck
  if const_in[1] || const_in[2]
    deepcopy(arr)
  else
    carr = CompArrow(Symbol(:pgf_, :mul), [:x, :y], [:z, :θmul])
    x, y, z, θ = ⬨(carr)
    x * y ⥅ z
    y ⥅ θ
    carr
  end
end

function pgf(arr::AddArrow, const_in)
  "As f^(-1)(z; θ) = (z-θ, θ), then the pgf becomes r(x, y) = (x+y, y)."
  if const_in[1] || const_in[2]
    deepcopy(arr)
  else
    carr = CompArrow(Symbol(:pgf_, :add), [:x, :y], [:z, :θadd])
    x, y, z, θ = ⬨(carr)
    x + y ⥅ z
    y ⥅ θ
    carr
  end
end

function pgf(arr::SubtractArrow)
  "As f^(-1)(z; θ) = (z+θ, θ), then the pgf becomes r(x, y) = (x-y, y)."
  carr = CompArrow(Symbol(:pgf_, :sub), [:x, :y], [:z, :θ])
  x, y, z, θ = ⬨(carr)
  x - y ⥅ z
  y ⥅ θ
  carr
end


function pgf(arr::GatherNdArrow)
  carr = CompArrow(Symbol(:pgf_, :sub),
                      [:param, :indices, :shape],
                      [:z, :θgather])
  param, indices, shape, z, θ = ⬨(carr)
  sarr = add_sub_arr!(carr, GatherNdArrow())
  param ⥅ (sarr, 1)
  indices ⥅ (sarr, 2)
  shape ⥅ (sarr, 3)
  (sarr, 1) ⥅ z
  scatter = add_sub_arr!(carr, ScatterNdArrow())
  (sarr, 1) ⥅ (scatter, 1)
  indices ⥅ (scatter, 2)
  shape ⥅ (scatter, 3)
  (param - ◃(scatter, 1)) ⥅ θ
  carr
end

pgf_np(arr::SinArrow) = deepcopy(arr)
pgf_np(arr::CosArrow) = deepcopy(arr)
pgf(arr::SourceArrow) = deepcopy(arr)
pgf(arr::IdentityArrow) = deepcopy(arr)
pgf(arr::ReshapeArrow) = deepcopy(arr)
pgf(arr::ScatterNdArrow) = deepcopy(arr)
pgf(arr::NegArrow) = deepcopy(arr)
pgf(arr::LogArrow) = deepcopy(arr)
pgf(arr::ExpArrow) = deepcopy(arr)

function pgf(arr::SinArrow)
  "As f^(-1)(y; θ) = πθ + (-1)^θ * asin(y), then the pgf becomes θ = floor((x+π/2)/π)."
  carr = CompArrow(Symbol(:pgf_, :sin), [:x], [:y, :θsin])
  x, y, θ = sub_ports(carr)
  sinarr = add_sub_arr!(carr, SinArrow())
  link_ports!(x, (sinarr, 1))
  link_ports!((sinarr, 1), y)
  pihalf = add_sub_arr!(carr, SourceArrow(π/2))
  pi = add_sub_arr!(carr, SourceArrow(π))
  add = add_sub_arr!(carr, AddArrow())
  div = add_sub_arr!(carr, DivArrow())
  floor = add_sub_arr!(carr, FloorArrow())
  link_ports!(x, (add, 1))
  link_ports!((pihalf, 1), (add, 2))
  link_ports!((add, 1), (div, 1))
  link_ports!((pi, 1), (div, 2))
  link_ports!((div, 1), (floor, 1))
  link_ports!((floor, 1), θ)
  carr
end

function pgf(arr::CosArrow)
  "As f^(-1)(y; θ) = 2π * ceil(θ/2) + (-1)^θ * acos(y), then the pgf becomes θ = floor(x/π)."
  carr = CompArrow(Symbol(:pgf_, :cos), [:x], [:y, :θcos])
  x, y, θ = sub_ports(carr)
  cosarr = add_sub_arr!(carr, CosArrow())
  link_ports!(x, (cosarr, 1))
  link_ports!((cosarr, 1), y)
  pi = add_sub_arr!(carr, SourceArrow(π))
  div = add_sub_arr!(carr, DivArrow())
  floor = add_sub_arr!(carr, FloorArrow())
  link_ports!(x, (div, 1))
  link_ports!((pi, 1), (div, 2))
  link_ports!((div, 1), (floor, 1))
  link_ports!((floor, 1), θ)
  carr
end

function pgf(arr::DivArrow)
  ## Hack
  if false
    carr = CompArrow(Symbol(:pgf_, :div), [:x, :y], [:z, :θ])
    x, y, z, θ = ⬨(carr)
    x / y ⥅ z
    y ⥅ θ
    carr
  else
    deepcopy(arr)
  end
end

function pgf(arr::LessThanArrow)
  "As f^(-1)(z; θ1, θ2) = (θ1, [θ1+θ2, θ1-θ2]^z), then the pgf becomes r(x, y) = (x<y, x, abs(x-y))."
  carr = CompArrow(Symbol(:pgf_, :lessthan), [:x, :y], [:z, :θ1, :θ2])
  x, y, z, θ1, θ2 = ⬨(carr)
  abs = add_sub_arr!(carr, AbsArrow())
  x < y ⥅ z
  x ⥅ θ1
  x - y ⥅ (abs, 1)
  link_ports!((abs, 2), θ2)
  carr
end
