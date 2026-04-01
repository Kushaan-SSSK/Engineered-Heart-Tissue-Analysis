function W = makeAnnulusWeights(templateSize, centerXY, R, ringHalfWidth, softnessPx)
% makeAnnulusWeights  Soft annular weight matrix in template coordinates.
%
% W = makeAnnulusWeights(templateSize, centerXY, R, ringHalfWidth, softnessPx)
%
% Creates a weight matrix peaking at radius R from centerXY, falling off
% smoothly inward and outward. Pixels far from the rim receive near-zero
% weight, preventing background anchoring in WNCC.
%
% Inputs:
%   templateSize  - [H W] size of the template image
%   centerXY      - [cx cy] post center in 1-based template pixel coords (col, row)
%   R             - ring center radius in pixels (typically 0.90-0.95 * post_radius)
%   ringHalfWidth - half-width of the ring in pixels (e.g. 3)
%   softnessPx    - smoothness of ring edges in pixels (e.g. 1.0); 0 = hard binary ring
%
% Output:
%   W - H x W weight matrix, values in [0,1], normalized so max = 1

if nargin < 5 || isempty(softnessPx); softnessPx = 1.0; end
if nargin < 4 || isempty(ringHalfWidth); ringHalfWidth = 3; end

H  = templateSize(1);
Wd = templateSize(2);
cx = centerXY(1);
cy = centerXY(2);

[X, Y] = meshgrid(1:Wd, 1:H);
r = hypot(X - cx, Y - cy);

inner = R - ringHalfWidth;
outer = R + ringHalfWidth;

if softnessPx <= 0
    W = double(r >= inner & r <= outer);
else
    s = max(softnessPx, 1e-6);
    insideOuter = 1 ./ (1 + exp( (r - outer) / s));
    outsideInner = 1 ./ (1 + exp((inner - r) / s));
    W = insideOuter .* outsideInner;
end

maxW = max(W(:));
if maxW > eps
    W = W / maxW;
else
    warning('makeAnnulusWeights: weight matrix is all zeros. Check centerXY and R.');
    W = ones(H, Wd) / (H * Wd);
end

end
