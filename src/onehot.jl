import Base: *

@deprecate onehotbatch onehot

struct OneHotVector <: AbstractVector{Bool}
  ix::UInt32
  of::UInt32
end

Base.size(xs::OneHotVector) = (Int64(xs.of),)

Base.getindex(xs::OneHotVector, i::Integer) = i == xs.ix

A::AbstractMatrix * b::OneHotVector = A[:, b.ix]

struct OneHotMatrix{A<:AbstractVector{OneHotVector}} <: AbstractMatrix{Bool}
  height::Int
  data::A
end

Base.size(xs::OneHotMatrix) = (Int64(xs.height),length(xs.data))

Base.getindex(xs::OneHotMatrix, i::Integer, j::Integer) = xs.data[j][i]
Base.getindex(xs::OneHotMatrix, ::Colon, i::Integer) = xs.data[i]
Base.getindex(xs::OneHotMatrix, ::Colon, i::AbstractArray) = OneHotMatrix(xs.height, xs.data[i])

A::AbstractMatrix * B::OneHotMatrix = A[:, map(x->x.ix, B.data)]

Base.hcat(x::OneHotVector, xs::OneHotVector...) = OneHotMatrix(length(x), [x, xs...])

batch(xs::AbstractArray{<:OneHotVector}) = OneHotMatrix(length(first(xs)), xs)

import Adapt.adapt

adapt(T, xs::OneHotMatrix) = OneHotMatrix(xs.height, adapt(T, xs.data))

@require CuArrays begin
  import CuArrays: CuArray, cudaconvert
  Base.Broadcast._containertype(::Type{<:OneHotMatrix{<:CuArray}}) = CuArray
  cudaconvert(x::OneHotMatrix{<:CuArray}) = OneHotMatrix(x.height, cudaconvert(x.data))
end

"""
  onehot(l, labels)

Returns a onehot encoding of the `l`, where `l ∈ labels` or
`l[i] ∈ labels`.

**Usage**:
```julia

julia> onehot(:b, [:a, :b, :c])
3-element Flux.OneHotVector:
 false
  true
 false

julia> onehot([1, 2, 1, 2], 1:3)
3×4 Flux.OneHotMatrix{Array{Flux.OneHotVector,1}}:
  true  false   true  false
 false   true  false   true
 false  false  false  false
```

See also [`argmax`](@ref).
"""
function onehot(l, labels)
  i = findfirst(labels, l)
  i > 0 || error("Value $l is not in labels")
  OneHotVector(i, length(labels))
end

function onehot(l, labels, unk)
  i = findfirst(labels, l)
  i > 0 || return onehot(unk, labels)
  OneHotVector(i, length(labels))
end

onehot(ls::AbstractVector, labels, unk...) =
  OneHotMatrix(length(labels), [onehot(l, labels, unk...) for l in ls])

"""
argmax(y)
argmax(y, labels)

For vector `y` and label set `labels`, returns the label of the maximum element
in `y`. For matrix `y`, returns a vector containing
the labels of the maximum elements in each column. 
If the `labels` argument is omitted, the labels
are assumed to be positions in columns.
"""  
argmax(y::AbstractVector, labels = 1:length(y)) =
  labels[findfirst(y, maximum(y))]

argmax(y::AbstractMatrix, l...) =
  squeeze(mapslices(y -> argmax(y, l...), y, 1), 1)

# Ambiguity hack

a::TrackedMatrix * b::OneHotVector = invoke(*, Tuple{AbstractMatrix,OneHotVector}, a, b)
a::TrackedMatrix * b::OneHotMatrix = invoke(*, Tuple{AbstractMatrix,OneHotMatrix}, a, b)
