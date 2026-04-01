function [centerXY, radiusPx, method_used] = detectPostCenter(T, debugPlot)
% detectPostCenter  Auto-detect PDMS post tip center and radius in a template image.
%
% [centerXY, radiusPx, method_used] = detectPostCenter(T)
% [centerXY, radiusPx, method_used] = detectPostCenter(T, true)  % show debug plot
%
% Tries three strategies in order of preference:
%   1. Hough circle transform (imfindcircles) on edge-enhanced template
%   2. Intensity centroid of the brightest OR darkest region
%   3. Geometric center fallback (always succeeds)
%
% Inputs:
%   T         - template image (Ht x Wt), grayscale, any numeric class
%   debugPlot - (optional) if true, shows the template with detected center/ring overlaid
%
% Outputs:
%   centerXY    - [cx cy] in 1-based template pixel coords (col, row)
%   radiusPx    - estimated post radius in pixels
%   method_used - string: 'hough', 'centroid', or 'geometric'

if nargin < 2; debugPlot = false; end

T = double(T);
T_norm = mat2gray(T);  % normalize to [0,1] for processing

Ht = size(T, 1);
Wt = size(T, 2);
min_dim = min(Ht, Wt);

% Geometric center is the fallback
cx_geo = Wt / 2 + 0.5;
cy_geo = Ht / 2 + 0.5;
r_geo  = min_dim * 0.40;   % assume post fills ~80% of shorter template dimension

centerXY    = [cx_geo, cy_geo];
radiusPx    = r_geo;
method_used = 'geometric';

% -----------------------------------------------------------------------
% Strategy 1: Hough circle detection on edge-filtered image
% -----------------------------------------------------------------------
try
    % Radius search range: post should fill 20%-55% of the shorter dimension
    r_min = max(3, round(min_dim * 0.20));
    r_max = max(r_min + 1, round(min_dim * 0.55));

    % Edge-enhance for Hough sensitivity
    T_edge = imgaussfilt(T_norm, 1.0);

    [centers, radii, metric] = imfindcircles(T_edge, [r_min, r_max], ...
        'ObjectPolarity', 'bright', ...
        'Sensitivity', 0.87, ...
        'Method', 'TwoStage');

    if isempty(centers)
        % Try dark posts (phase-contrast imaging)
        [centers, radii, metric] = imfindcircles(T_edge, [r_min, r_max], ...
            'ObjectPolarity', 'dark', ...
            'Sensitivity', 0.87, ...
            'Method', 'TwoStage');
    end

    if ~isempty(centers) && max(metric) > 0.3
        % Pick the circle with the highest metric that is inside the template
        for k = 1:length(radii)
            cx_h = centers(k, 1);
            cy_h = centers(k, 2);
            r_h  = radii(k);
            % Check that center is reasonably inside the template
            margin = 3;
            if cx_h >= margin && cx_h <= Wt - margin + 1 && ...
               cy_h >= margin && cy_h <= Ht - margin + 1
                centerXY    = [cx_h, cy_h];
                radiusPx    = r_h;
                method_used = 'hough';
                break;
            end
        end
    end
catch
    % imfindcircles not available or failed — continue to next strategy
end

% -----------------------------------------------------------------------
% Strategy 2: Intensity centroid (brightest or most-contrasted region)
% -----------------------------------------------------------------------
if strcmp(method_used, 'geometric')
    try
        % Use Otsu thresholding to find the post region
        thresh = graythresh(T_norm);

        % Try bright post first
        BW_bright = T_norm > thresh;
        BW_dark   = T_norm < thresh;

        % Pick the mask that gives a single large connected component
        for BW = {BW_bright, BW_dark}
            BW = BW{1};
            BW = imopen(BW, strel('disk', 2));  % denoise
            props = regionprops(BW, 'Area', 'Centroid', 'EquivDiameter');

            if isempty(props); continue; end

            % Find the largest region that is roughly circular
            areas = [props.Area];
            [max_area, max_idx] = max(areas);

            % Check: at least 5% of template area, centroid inside template
            if max_area > 0.05 * Ht * Wt
                cx_c = props(max_idx).Centroid(1);
                cy_c = props(max_idx).Centroid(2);
                r_c  = props(max_idx).EquivDiameter / 2;

                margin = 5;
                if cx_c >= margin && cx_c <= Wt - margin + 1 && ...
                   cy_c >= margin && cy_c <= Ht - margin + 1
                    centerXY    = [cx_c, cy_c];
                    radiusPx    = r_c;
                    method_used = 'centroid';
                    break;
                end
            end
        end
    catch
        % Segmentation failed — geometric fallback remains
    end
end

% -----------------------------------------------------------------------
% Safety clamp: ensure center and radius are sane
% -----------------------------------------------------------------------
centerXY(1) = max(2, min(Wt - 1, centerXY(1)));
centerXY(2) = max(2, min(Ht - 1, centerXY(2)));
radiusPx    = max(2, min(min_dim * 0.50, radiusPx));

% -----------------------------------------------------------------------
% Optional debug visualization
% -----------------------------------------------------------------------
if debugPlot
    figure('Name', 'detectPostCenter Debug');
    imshow(mat2gray(T));  hold on;
    title(sprintf('Post Center Detection: method = %s', method_used));

    cx = centerXY(1);
    cy = centerXY(2);
    r  = radiusPx;

    % Draw detected center
    plot(cx, cy, 'r+', 'MarkerSize', 14, 'LineWidth', 2);

    % Draw detected circle (post boundary estimate)
    theta = linspace(0, 2*pi, 200);
    plot(cx + r*cos(theta), cy + r*sin(theta), 'r-', 'LineWidth', 1.5);

    % Draw target annulus (where weights will peak)
    r_inner = r * 0.80;
    r_outer = r * 1.10;
    plot(cx + r_inner*cos(theta), cy + r_inner*sin(theta), 'y--', 'LineWidth', 1);
    plot(cx + r_outer*cos(theta), cy + r_outer*sin(theta), 'y--', 'LineWidth', 1);

    legend({'Center', 'Estimated boundary', 'Annulus inner/outer'}, ...
           'Location', 'bestoutside');
    hold off;
    drawnow;
end

end
