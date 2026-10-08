function v = fixlog(s)
%FIXLOG  Logged values ('Structure With Time') as an N x k matrix, N = time samples.
v = s.signals.values;  N = numel(s.time);
if ndims(v) == 3                       % k x 1 x N (vector signal)
  v = reshape(v, [], size(v, 3)).';
elseif size(v, 1) ~= N && size(v, 2) == N
  v = v.';
end
end
