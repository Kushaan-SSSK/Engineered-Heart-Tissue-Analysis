function S = wncc2_precompute(T, W)
% wncc2_precompute  Precompute WNCC kernels from template and weight matrix.
%
% S = wncc2_precompute(T, W)
%
% Call this ONCE per template before the per-frame tracking loop.
% Stores everything needed by wncc2_apply to compute a WNCC map.
%
% The weighted zero-mean NCC (WNCC) formula is:
%   C = [sum W*(T-muT)*P] / [sqrt(sum W*(T-muT)^2) * sqrt(sum W*P^2 - (sum W*P)^2/sumW)]
%
% Key algebraic fact: sum(W * T0) = 0 by definition of muT, so
%   sum W * T0 * P = sum W * T0 * (P - muP_weighted)
% meaning the numerator kernel W*T0 implicitly handles the local image mean.
%
% Inputs:
%   T - template image (Ht x Wt), any numeric class
%   W - nonnegative weight matrix (Ht x Wt), same size as T
%
% Output struct S fields:
%   Tsize   - [Ht Wt]
%   Knum    - W .* T0 (numerator convolution kernel)
%   Kw      - W (weight kernel for sumP and sumP2 computations)
%   sumW    - scalar sum of all weights
%   denT    - scalar: sqrt(sum(W .* T0.^2)) — fixed template norm
%   center  - [cx cy] geometric center of template (filled by detectPostCenter)

validateattributes(T, {'numeric'}, {'2d', 'real', 'nonempty'}, 'wncc2_precompute', 'T');
validateattributes(W, {'numeric', 'logical'}, {'2d', 'real', 'nonnegative'}, 'wncc2_precompute', 'W');

if ~isequal(size(T), size(W))
    error('wncc2_precompute:SizeMismatch', 'T and W must have the same size.');
end

T = double(T);
W = double(W);

sumW = sum(W(:));
if sumW <= eps
    error('wncc2_precompute:BadWeights', ...
        'Sum of weights is zero or near-zero. Check weight matrix construction.');
end

% Weighted mean of template
muT = sum(W(:) .* T(:)) / sumW;

% Zero-mean template
T0 = T - muT;

% Weighted template norm (fixed denominator term)
denT = sqrt(sum(W(:) .* (T0(:).^2)));
if denT <= eps
    error('wncc2_precompute:DegenerateTemplate', ...
        'Weighted template variance is zero — template has no contrast in the weighted region.');
end

S.Tsize = size(T);
S.Knum  = W .* T0;   % Numerator kernel: slide this over the ROI
S.Kw    = W;         % Weight kernel: for computing sumP and sumP2
S.sumW  = sumW;
S.denT  = denT;
S.muT   = muT;       % Stored for diagnostics

end
