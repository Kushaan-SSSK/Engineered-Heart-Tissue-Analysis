function W = makeGaussianWeightsFromTemplate(templateSize, centerXY, sigmaPx, clipRadiusPx)
% makeGaussianWeightsFromTemplate  Gaussian weight matrix in template coordinates.
%
% W = makeGaussianWeightsFromTemplate(templateSize, centerXY, sigmaPx)
% W = makeGaussianWeightsFromTemplate(templateSize, centerXY, sigmaPx, clipRadiusPx)
%
% Inputs:
%   templateSize  - [H W] size of the template image
%   centerXY      - [cx cy] post center in 1-based template pixel coords (col, row)
%   sigmaPx       - Gaussian sigma in pixels (e.g. 0.3 * post_radius)
%   clipRadiusPx  - (optional) pixels outside this radius are set to 0
%
% Output:
%   W - H x W weight matrix, values in [0,1], normalized so max = 1

H  = templateSize(1);
Wd = templateSize(2);
cx = centerXY(1);
cy = centerXY(2);

[X, Y] = meshgrid(1:Wd, 1:H);
r2 = (X - cx).^2 + (Y - cy).^2;

W = exp(-0.5 * r2 / max(sigmaPx^2, eps));

if nargin >= 4 && ~isempty(clipRadiusPx)
    W(r2 > clipRadiusPx^2) = 0;
end

maxW = max(W(:));
if maxW > eps
    W = W / maxW;
else
    warning('makeGaussianWeightsFromTemplate: weight matrix is all zeros.');
    W = ones(H, Wd) / (H * Wd);
end

end
