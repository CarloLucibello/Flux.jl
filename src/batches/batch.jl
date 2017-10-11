struct Batch{T,A,M}
  data::A
  mask::M
end

Batch{T}(data, mask) where T = Batch{T,typeof(data),typeof(mask)}(data, mask)

batchindex(xs, i) = (reverse(Base.tail(reverse(indices(xs))))..., i)

function tobatch(xs)
  data = similar(first(xs), size(first(xs))..., length(xs))
  for (i, x) in enumerate(xs)
    data[batchindex(data, i)...] = x
  end
  return data
end

Batch(xs) = Batch{typeof(first(xs))}(tobatch(xs),trues(length(xs)))
