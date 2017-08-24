"A trace within an arrow uniquely defines a trace `sub_arrow`"
struct TraceArrow{I, O} <: ArrowRef{I, O}
  arrs::Vector{SubArrow}
end

"Which `SubArrow` does `tracearrow` trace to"
sub_arrow(tracearrow::TraceArrow)::SubArrow = last(tracearrow.arrs)

deref(trace::TraceArrow)::RealArrow = deref(last(trace.arrs))

"A port of a `TraceArrow`"
struct TracePort{T <: Integer} <: AbstractPort
  arrow::TraceArrow
  vertex_id::T
end

"Which `SubPort` does this `traceport` trace to"
function sub_port(traceport::TracePort)::SubPort
  SubPort(sub_arrow(traceport.arrow), traceport.vertex_id)
end

"A `Value` of a `TraceArrow`"
struct TraceRepValue <: Value
  traceport::TracePort
end

"Which `TracePort`s are represented by a `Value`"
function ports(tracevalue::TraceRepValue)::Vector{TracePort}
  subport = sub_port(tracevalue.traceport)
  component = weakly_connected_component(subport)
  [TracePort(tracearrow, subport.id) for subport in component]
end
