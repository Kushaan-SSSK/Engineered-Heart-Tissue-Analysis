function [C, aux] = wncc2_apply(ROI, S, method)
% wncc2_apply  Apply precomputed WNCC kernels to an image ROI.
%
% [C, aux] = wncc2_apply(ROI, S)
% [C, aux] = wncc2_apply(ROI, S, method)
%
% Returns a 'valid'-style WNCC correlation map. Output size is
%   (ROI_H - Ht + 1) x (ROI_W - Wt + 1)
% matching the template sliding within the ROI.
%
% Math:
%   num   = sum_pixels [ Knum(x) * ROI(x + shift) ]   (via correlation)
%   sumP  = sum_pixels [ Kw(x)   * ROI(x + shift) ]   (weighted local sum)
%   sumP2 = sum_pixels [ Kw(x)   * ROI(x + shift)^2 ] (weighted local sum of squares)
%   E_P   = sumP2 - sumP^2 / sumW                      (weighted variance of ROI patch)
%   C     = num / (denT * sqrt(E_P))                   (WNCC coefficient)
%
% Inputs:
%   ROI    - grayscale image patch (Hr x Wr), must satisfy Hr>=Ht and Wr>=Wt
%   S      - precomputed struct from wncc2_precompute
%   method - 'fft' (default) or 'spatial'
%
% Outputs:
%   C   - WNCC correlation map, values typically in [-1, 1], size (Hr-Ht+1) x (Wr-Wt+1)
%   aux - struct with intermediate terms (num, sumP, sumP2, E_P) for diagnostics

if nargin < 3 || isempty(method)
    method = 'fft';
end
method = lower(char(method));

ROI = double(ROI);

Ht = S.Tsize(1);
Wt = S.Tsize(2);
Hr = size(ROI, 1);
Wr = size(ROI, 2);

if Hr < Ht || Wr < Wt
    error('wncc2_apply:ROITooSmall', ...
        'ROI (%d x %d) must be >= template (%d x %d).', Hr, Wr, Ht, Wt);
end

Knum = S.Knum;
Kw   = S.Kw;
sumW = S.sumW;
denT = S.denT;

switch method
    case 'spatial'
        % Direct 2D convolution — simpler but slower for large templates
        num   = conv2(ROI,      rot90(Knum, 2), 'valid');
        sumP  = conv2(ROI,      rot90(Kw,   2), 'valid');
        sumP2 = conv2(ROI.^2,   rot90(Kw,   2), 'valid');

    case 'fft'
        % FFT-accelerated — preferred for templates > ~15x15 px
        outH = Hr + Ht - 1;
        outW = Wr + Wt - 1;

        % Forward FFTs of ROI and ROI^2
        Froi  = fft2(ROI,      outH, outW);
        Froi2 = fft2(ROI.^2,   outH, outW);

        % Forward FFTs of kernels (rotated for correlation = convolution with flipped kernel)
        Fknum = fft2(rot90(Knum, 2), outH, outW);
        Fkw   = fft2(rot90(Kw,   2), outH, outW);

        % Three cross-correlations via pointwise multiplication
        num_full   = real(ifft2(Froi  .* Fknum));
        sumP_full  = real(ifft2(Froi  .* Fkw));
        sumP2_full = real(ifft2(Froi2 .* Fkw));

        % Extract 'valid' region:
        % In a full correlation of (Hr x Wr) with (Ht x Wt), the valid
        % portion starts at row Ht, col Wt (1-indexed) in the full output.
        num   = num_full(   Ht:Hr, Wt:Wr);
        sumP  = sumP_full(  Ht:Hr, Wt:Wr);
        sumP2 = sumP2_full( Ht:Hr, Wt:Wr);

    otherwise
        error('wncc2_apply:BadMethod', 'method must be ''fft'' or ''spatial''.');
end

% Weighted variance of ROI windows (guard against numerical negatives)
E_P = sumP2 - (sumP.^2) / sumW;
E_P = max(E_P, 0);

% Denominator: fixed template norm * local image weighted-std
denom = denT .* sqrt(E_P);
denom(denom < eps) = eps;  % avoid division by zero in flat regions

C = num ./ denom;

% Clip to valid correlation range (rounding errors can push slightly outside)
C = max(-1, min(1, C));

if nargout > 1
    aux.num   = num;
    aux.sumP  = sumP;
    aux.sumP2 = sumP2;
    aux.E_P   = E_P;
end

end
