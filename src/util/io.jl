using PyCall
import TensorFlow
const tf = TensorFlow

Operation = tf.Operation
Graph = tf.Graph
Tensor = tf.Tensor

num_inputs(op::Operation) = length(tf.get_def(op).input)
get_inputs(op::Operation) = [tf.get_input(op, i) for i = 1:num_inputs(op)]

"`Operation`s that take `ten` as input"
function consumers(ten::Tensor)
  unique(op for op in tf.get_operations() if ten ∈ get_inputs(op))
end

"Tensors which are outputs of `op`"
function get_outputs(op::Operation)


"Get the constant output of a const op as value"
function get_const_op_value(const_op::Operation)
  local value
  try
    value = Array(tf.load_proto(tf.get_def(op).attr["value"]))
  catch err
    if isa(err, tf.EmptyTensorError)
      T = eltype(Tensor(op, 1))
      value = Array{T}(0)
    else
      rethrow(err)
    end
  end
  value
end

conv_Add(add_op::Operation) = AddArrow()

conv_Sub(sub_op::Operation) = SubtractArrow()

conv_AddN(addm_op::Operation) = AddNArrow(length(addm_op.inputs))

conv_Const(const_op::Operation) = SourceArrow(get_const_op_value(const_op))

conv_Cos(sin_op::Operation) = CosArrow()

conv_Exp(exp_op::Operation) = ExpArrow()

conv_Gather(gather_op::Operation) = GatherArrow()

conv_GatherNd(gathernd_op::Operation) = GatherNdArrow()

conv_Mul(mul_op::Operation) = MulArrow()

conv_Neg(neg_op::Operation) = NegArrow()

conv_Sin(sin_op::Operation) = SinArrow()

conv_Reshape(res_op::Operation) = ReshapeArrow()

conv_Greater(gt_op::Operation) = GreaterArrow()

conv_Identity(id_op::Operation) = IdentityArrow()

conv_Abs(id_op::Operation) = AbsArrow()

# Mapping between op types and arrows
# Cannot use multimethods because different ops not distinguished by type
Op_Type_To_Arrow = Dict{String, Function}(
  "Add" => conv_Add,
  "AddN" => conv_AddN,
  "Abs" => conv_Abs,
  "Sub" => conv_Sub,
  "Gather" => conv_Gather,
  "GatherNd" => conv_GatherNd,
  "Exp" => conv_Exp,
  "Mul" => conv_Mul,
  "Neg" => conv_Neg,
  "Sin" => conv_Sin,
  "Cos" => conv_Cos,
  "Reshape" => conv_Reshape,
  "Const" => conv_Const,
  "Greater" => conv_Greater,
  "Identity" => conv_Identity,
  "VariableV2" => conv_Const)

"""Return an arrow from a list or create one if haven't done already"""
function arrow_from_op(c::CompArrow,
                       op::Operation,
                       op_to_arrow::Dict{Operation, Arrow})::Arrow
  if op in keys(op_to_arrow)
    op_to_arrow[op]
  else
    # tf.get_def(op).op
    op_type = op.op_name
    conv_op = Op_Type_To_Arrow[op_type]
    arrow = conv_op(op)
    arrowref = add_sub_arr!(c, arrow)
    op_to_arrow[op] = arrowref
    # @assert length(in_ports(arrow)) == length(op.inputs)
  end
end

function update_seen!(op::Operation, seen_tens::Set{<:Tensor},
                      to_see_tens::Vector{<:Tensor})
  for ten ∈ get_inputs(op)
    if ten ∉ seen_tens
      push!(to_see_tens, ten)
    end
  end
end

"is `ten` an input?"
is_input_ten(ten::Tensor)::Bool =  ten.op.op_name == "Placeholder"

"""Convert a tenflow graph into an arrow.
Assume inputs are 'Placeholder' tens
Args:
  out_tens: Tensors designated as outputs
  inp_tens: Tensors designated as inputs.  If not given then
                   we assume any placeholder tens connected (indrectly)
                   to the outputs are input tens
  name: Name of the composite arrow
Returns:
  A `CompArrow` equivalent to graph which computes 'out_tens'
"""
function graph_to_arrow(name::Symbol, inp_tens::Vector{<:Tensor},
                        out_tens::Vector{<:Tensor})::CompArrow
  op_to_arrow = Dict{Operation, Arrow}()
  seen_tens = Set{Tensor}()
  I, O = length(inp_tens), length(out_tens)
  c = CompArrow{I, O}(name)

  # Make an in_port for every input ten
  ten_in_port = Dict{Port, Tensor}(zip(in_ports(c), inp_tens))
  # set_port_shape(in_port, const_to_tuple(ten.get_shape().as_list()))

  # Make an out_port for every output ten
  for (id, ten) in enumerate(out_tens)
    arrow = arrow_from_op(c, ten.op, op_to_arrow)
    left = out_port(arrow, ten.value_index)
    link_ports!(c, left, out_port(c, id))
  end

  # Starting from outputs
  to_see_tens = copy(out_tens)
  while !isempty(to_see_tens)
    ten = pop!(to_see_tens)
    push!(seen_tens, ten)
    if is_input_ten(ten)
      left_port = ten_to_in_port[ten]
      set_port_shape(left_port, const_to_tuple(ten.get_shape().as_list()))
    else
      out_port_id = ten.value_index
      left_arrow = arrow_from_op(c, ten.op, op_to_arrow)
      left_port = out_port(left_arrow, out_port_id)
      update_seen!(ten.op, seen_tens, to_see_tens)
    end

    for rec_op in consumers(ten)
      for (i, input_ten) in enumerate(get_inputs(rec_op))
        if ten == input_ten
          in_port_id = i
          right_arrow = arrow_from_op(c, rec_op, op_to_arrow)
          link_ports!(c, left_port, in_port(right_arrow, in_port_id))
        end
      end
    end
  end

  @assert is_wired_ok(c)
  return c
end
