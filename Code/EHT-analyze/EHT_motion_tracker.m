function EHT_motion_tracker(template_path, data_path, result_path, perform_annotation, config_file, force_reannotation)

if nargin < 4
    perform_annotation = true;
end

if nargin < 5
    config_file = '';
end

if nargin < 6
    force_reannotation = false;
end

config = load_EHT_config(config_file);

fprintf('=== EHT Motion Tracking (Well-Based) ===\n');
fprintf('Template Path: %s\n', template_path);
fprintf('Data Path: %s\n', data_path);
fprintf('Result Path: %s\n', result_path);
fprintf('Configuration: %s\n', ifelse(isempty(config_file), 'Default', config_file));
fprintf('\n');

if ~exist(result_path, 'dir')
    mkdir(result_path);
end
if ~exist(template_path, 'dir')
    mkdir(template_path);
end

fprintf('Scanning video folders...\n');
contents = dir(data_path);
contents = contents([contents.isdir]);
contents = contents(~ismember({contents.name}, {'.', '..'}));

wells = struct();
well_names = {};
skipped_folders = {};

for i = 1:length(contents)
    folder_name = contents(i).name;
    [basename, well_id, rate_bpm, rate_hz, is_valid] = parse_folder_name(folder_name);

    if ~is_valid
        skipped_folders{end+1} = folder_name;
        continue;
    end

    folder_path = fullfile(data_path, folder_name);
    sub_folder = fullfile(folder_path, 'Pos0');

    if ~exist(sub_folder, 'dir')
        skipped_folders{end+1} = folder_name;
        continue;
    end

    tif_files = dir(fullfile(sub_folder, '*.tif'));
    if isempty(tif_files)
        skipped_folders{end+1} = folder_name;
        continue;
    end

    if ~isfield(wells, well_id)
        wells.(well_id) = struct();
        wells.(well_id).well_id = well_id;
        wells.(well_id).basename = basename;
        wells.(well_id).folders = {};
        wells.(well_id).rates_bpm = [];
        wells.(well_id).rates_hz = [];
        wells.(well_id).first_image = '';
        well_names{end+1} = well_id;
    end

    wells.(well_id).folders{end+1} = folder_name;
    wells.(well_id).rates_bpm(end+1) = rate_bpm;
    wells.(well_id).rates_hz(end+1) = rate_hz;

    if isempty(wells.(well_id).first_image)
        wells.(well_id).first_image = fullfile(sub_folder, tif_files(1).name);
    end
end

fprintf('Found %d wells with %d total video folders\n', length(well_names), length(contents) - length(skipped_folders));
if ~isempty(skipped_folders)
    fprintf('Skipped %d folders (invalid naming or missing data):\n', length(skipped_folders));
    for i = 1:length(skipped_folders)
        fprintf('  - %s\n', skipped_folders{i});
    end
end
fprintf('\n');

fprintf('=== Well Summary ===\n');
for i = 1:length(well_names)
    well_id = well_names{i};
    well = wells.(well_id);
    fprintf('Well %s: %d videos, pacing rates = %s BPM\n', ...
            well_id, length(well.folders), mat2str(well.rates_bpm));
end
fprintf('\n');

if perform_annotation
    annotate_posts_by_well(wells, well_names, template_path, config, force_reannotation);
end

results = struct();

fprintf('=== Processing Metadata ===\n');
for i = 1:length(well_names)
    well_id = well_names{i};
    well = wells.(well_id);

    for j = 1:length(well.folders)
        folder_name = well.folders{j};
        folder_path = fullfile(data_path, folder_name);
        sub_folder = fullfile(folder_path, 'Pos0');
        metadata_path = fullfile(sub_folder, 'metadata.txt');

        if exist(metadata_path, 'file')
            timestamps = process_metadata(metadata_path);
            results.(matlab.lang.makeValidName(folder_name)) = timestamps;
            fprintf('  %s: %d frames\n', folder_name, length(timestamps));
        else
            fprintf('  WARNING: Missing metadata in %s\n', folder_name);
        end
    end
end
fprintf('\n');

fprintf('=== Tracking Motion ===\n');
for i = 1:length(well_names)
    well_id = well_names{i};
    well = wells.(well_id);

    fprintf('\nWell %s (%d videos):\n', well_id, length(well.folders));

    for j = 1:length(well.folders)
        folder_name = well.folders{j};
        folder_path = fullfile(data_path, folder_name);
        sub_folder = fullfile(folder_path, 'Pos0');

        video_template_dir = fullfile(sub_folder, 'templates');
        template0_path = fullfile(video_template_dir, 'template0.tif');
        template1_path = fullfile(video_template_dir, 'template1.tif');

        if ~exist(template0_path, 'file') || ~exist(template1_path, 'file')
            well_template_dir = fullfile(template_path, well_id);
            template0_path = fullfile(well_template_dir, 'template0.tif');
            template1_path = fullfile(well_template_dir, 'template1.tif');
        end

        if ~exist(template0_path, 'file') || ~exist(template1_path, 'file')
            fprintf('  WARNING: Templates not found for %s, skipping\n', folder_name);
            continue;
        end

        template0 = imread(template0_path);
        template1 = imread(template1_path);

        if size(template0, 3) == 3
            template0 = rgb2gray(template0);
        end
        if size(template1, 3) == 3
            template1 = rgb2gray(template1);
        end

        template0 = double(template0);
        template1 = double(template1);

        valid_name = matlab.lang.makeValidName(folder_name);
        if exist(sub_folder, 'dir') && isfield(results, valid_name)
            fprintf('  Tracking: %s... ', folder_name);
            results.(valid_name) = track_motion_with_templates(sub_folder, results.(valid_name), ...
                                                               template0, template1, config);
            fprintf('done\n');
        end
    end
end

write_results_v2(results, result_path, wells, data_path);

fprintf('\n=== EHT Motion Tracking Complete ===\n');

end


function annotate_posts_by_well(wells, well_names, template_path, config, force_reannotation)

if nargin < 5
    force_reannotation = false;
end

fprintf('\n=== Post Annotation (Once Per Well) ===\n');
if force_reannotation
    fprintf('NOTE: force_reannotation=true. Existing templates will be overwritten.\n');
end

for i = 1:length(well_names)
    well_id = well_names{i};
    well = wells.(well_id);

    fprintf('\nWell %s (%d videos with rates: %s BPM)\n', ...
            well_id, length(well.folders), mat2str(well.rates_bpm));

    well_template_dir = fullfile(template_path, well_id);
    if ~exist(well_template_dir, 'dir')
        mkdir(well_template_dir);
    end

    template0_path = fullfile(well_template_dir, 'template0.tif');
    template1_path = fullfile(well_template_dir, 'template1.tif');

    if ~force_reannotation && exist(template0_path, 'file') && exist(template1_path, 'file')
        fprintf('  Templates already exist, skipping annotation (use force_reannotation=true to redraw)\n');
        continue;
    end

    if force_reannotation && exist(template0_path, 'file')
        fprintf('  Overwriting existing templates for well %s\n', well_id);
    end

    img_path = well.first_image;
    fprintf('  Using reference image: %s\n', img_path);
    fprintf('  Please select the two posts by dragging boxes\n');

    img = imread(img_path);
    if size(img, 3) == 3
        img = rgb2gray(img);
    end
    img = double(img);

    fig = figure('Name', sprintf('Well %s - Post Annotation', well_id), 'Position', [100, 100, 800, 600]);
    imshow(uint8(img), []);
    title(sprintf('Well %s: Drag box around FIRST post, then double-click inside', well_id), 'FontSize', 12);

    h1 = imrect;
    wait(h1);
    pos1 = getPosition(h1);

    if ~isempty(pos1)
        x1 = max(1, round(pos1(1)));
        y1 = max(1, round(pos1(2)));
        x2 = min(size(img, 2), round(pos1(1) + pos1(3)));
        y2 = min(size(img, 1), round(pos1(2) + pos1(4)));

        template1 = img(y1:y2, x1:x2);

        title(sprintf('Well %s: Drag box around SECOND post, then double-click inside', well_id), 'FontSize', 12);
        delete(h1);

        h2 = imrect;
        wait(h2);
        pos2 = getPosition(h2);

        if ~isempty(pos2)
            x1 = max(1, round(pos2(1)));
            y1 = max(1, round(pos2(2)));
            x2 = min(size(img, 2), round(pos2(1) + pos2(3)));
            y2 = min(size(img, 1), round(pos2(2) + pos2(4)));

            template2 = img(y1:y2, x1:x2);

            imwrite(uint8(template1), template0_path);
            imwrite(uint8(template2), template1_path);

            % Save crop rectangles for WNCC post-center initialization
            rects.pos1 = pos1;  % [xmin ymin width height] of post 0 in full frame
            rects.pos2 = pos2;  % [xmin ymin width height] of post 1 in full frame
            rects_path = fullfile(well_template_dir, 'rects.mat');
            save(rects_path, 'rects');

            fprintf('  Templates saved to %s\n', well_template_dir);
            fprintf('  These templates will be used for all %d videos in well %s\n', ...
                    length(well.folders), well_id);
        else
            fprintf('  WARNING: Second post not selected for well %s\n', well_id);
        end
    else
        fprintf('  WARNING: First post not selected for well %s\n', well_id);
    end

    close(fig);
end

end


function timestamps = process_metadata(metadata_path)

fid = fopen(metadata_path, 'r');
content = fread(fid, '*char')';
fclose(fid);

frame_pattern = 'FrameKey-(\d+)-0-0';
time_pattern = '"ElapsedTime-ms":\s*(\d+)';

frame_matches = regexp(content, frame_pattern, 'tokens');
time_matches = regexp(content, time_pattern, 'tokens');

timestamps = struct();

for i = 1:min(length(frame_matches), length(time_matches))
    frame_num = str2double(frame_matches{i}{1});
    elapsed_time = str2double(time_matches{i}{1});

    timestamps(frame_num + 1).time = elapsed_time;
    timestamps(frame_num + 1).x1 = 0;
    timestamps(frame_num + 1).y1 = 0;
    timestamps(frame_num + 1).x2 = 0;
    timestamps(frame_num + 1).y2 = 0;
end

end


function timestamps = track_motion_with_templates(folder_path, timestamps, template0, template1, config)
% Track post motion using Weighted NCC (WNCC) with annular weights.
% Frame 1 uses full normxcorr2 to bootstrap; frames 2-N use ROI-based WNCC
% centered on the previous position. Falls back to normxcorr2 if WNCC peak
% is below threshold (e.g. defocused frames, occlusion).
% Set config.use_wncc = false to revert to plain normxcorr2 for all frames.

tif_files = dir(fullfile(folder_path, '*.tif'));
tif_files = {tif_files.name};
tif_files = sort(tif_files);

if isempty(tif_files)
    warning('No TIFF files found in %s', folder_path);
    return;
end

Ht0 = size(template0, 1);  Wt0 = size(template0, 2);
Ht1 = size(template1, 1);  Wt1 = size(template1, 2);

% --- Read WNCC config fields with safe defaults ---
use_wncc      = isfield(config, 'use_wncc')               && config.use_wncc;
weights_kind  = 'annulus';
if isfield(config, 'wncc_weights_kind');       weights_kind = config.wncc_weights_kind; end
ring_hw       = 3;
if isfield(config, 'wncc_ring_half_width');    ring_hw      = config.wncc_ring_half_width; end
ring_soft     = 1.0;
if isfield(config, 'wncc_ring_softness');      ring_soft    = config.wncc_ring_softness; end
roi_hs        = 50;
if isfield(config, 'wncc_roi_half_size');      roi_hs       = config.wncc_roi_half_size; end
wncc_thresh   = 0.20;
if isfield(config, 'wncc_fallback_threshold'); wncc_thresh  = config.wncc_fallback_threshold; end
score_thresh  = config.score_threshold;

S0 = [];  S1 = [];
center0 = [];  radius0 = [];
center1 = [];  radius1 = [];

if use_wncc
    % --- Detect post centers and radii in template space ---
    [center0, radius0, m0] = detectPostCenter(template0, false);
    [center1, radius1, m1] = detectPostCenter(template1, false);
    fprintf('  WNCC: post0 center=[%.1f,%.1f] r=%.1fpx (%s); post1 center=[%.1f,%.1f] r=%.1fpx (%s)\n', ...
            center0(1), center0(2), radius0, m0, center1(1), center1(2), radius1, m1);

    % --- Build weight matrices ---
    try
        switch lower(weights_kind)
            case 'annulus'
                W0 = makeAnnulusWeights(size(template0), center0, radius0 * 0.95, ring_hw, ring_soft);
                W1 = makeAnnulusWeights(size(template1), center1, radius1 * 0.95, ring_hw, ring_soft);
            case 'gaussian'
                W0 = makeGaussianWeightsFromTemplate(size(template0), center0, radius0*0.35, radius0*1.1);
                W1 = makeGaussianWeightsFromTemplate(size(template1), center1, radius1*0.35, radius1*1.1);
            otherwise  % 'disk'
                [Xg0, Yg0] = meshgrid(1:Wt0, 1:Ht0);
                W0 = double(hypot(Xg0 - center0(1), Yg0 - center0(2)) <= radius0);
                [Xg1, Yg1] = meshgrid(1:Wt1, 1:Ht1);
                W1 = double(hypot(Xg1 - center1(1), Yg1 - center1(2)) <= radius1);
        end

        % --- Precompute WNCC kernels (once per template, not per frame) ---
        S0 = wncc2_precompute(double(template0), W0);
        S1 = wncc2_precompute(double(template1), W1);
    catch ME
        warning('track_motion:WNCCSetupFailed', ...
                'WNCC setup failed: %s\nFalling back to normxcorr2.', ME.message);
        use_wncc = false;
        S0 = [];  S1 = [];
    end
end

% Previous-frame positions for ROI centering (NaN until frame 1 is done)
prev_x0 = NaN;  prev_y0 = NaN;
prev_x1 = NaN;  prev_y1 = NaN;

for frame_idx = 1:length(tif_files)
    img = imread(fullfile(folder_path, tif_files{frame_idx}));
    if size(img, 3) == 3; img = rgb2gray(img); end
    img = double(img);
    imgH = size(img, 1);  imgW = size(img, 2);

    % =========================================================
    %  POST 0  (template0)
    % =========================================================
    if use_wncc && ~isempty(S0) && frame_idx > 1 && ~isnan(prev_x0) && prev_x0 > 0
        [x0, y0, peak0] = wncc_track_post( ...
            img, S0, center0, prev_x0, prev_y0, roi_hs, Ht0, Wt0, imgH, imgW);

        if peak0 < wncc_thresh
            % WNCC peak too low — fall back to global NCC for this frame
            [x0, y0, peak0] = full_ncc_track(template0, img, Ht0, Wt0);
        end
    else
        % Frame 1 or WNCC disabled: use full normxcorr2
        [x0, y0, peak0] = full_ncc_track(template0, img, Ht0, Wt0);
    end
    if peak0 < score_thresh;  x0 = 0;  y0 = 0;  end
    prev_x0 = x0;  prev_y0 = y0;

    % =========================================================
    %  POST 1  (template1)
    % =========================================================
    if use_wncc && ~isempty(S1) && frame_idx > 1 && ~isnan(prev_x1) && prev_x1 > 0
        [x1, y1, peak1] = wncc_track_post( ...
            img, S1, center1, prev_x1, prev_y1, roi_hs, Ht1, Wt1, imgH, imgW);

        if peak1 < wncc_thresh
            [x1, y1, peak1] = full_ncc_track(template1, img, Ht1, Wt1);
        end
    else
        [x1, y1, peak1] = full_ncc_track(template1, img, Ht1, Wt1);
    end
    if peak1 < score_thresh;  x1 = 0;  y1 = 0;  end
    prev_x1 = x1;  prev_y1 = y1;

    if frame_idx <= length(timestamps)
        timestamps(frame_idx).x1 = x1;
        timestamps(frame_idx).y1 = y1;
        timestamps(frame_idx).x2 = x0;
        timestamps(frame_idx).y2 = y0;
    end
end

end


% --------------------------------------------------------
%  Helper: ROI-based WNCC tracking for one post, one frame
% --------------------------------------------------------
function [x_out, y_out, peak] = wncc_track_post( ...
    img, S, centerXY, prev_x, prev_y, roi_hs, Ht, Wt, imgH, imgW)

cx = centerXY(1);   % post center col in template coords (1-based)
cy = centerXY(2);   % post center row in template coords (1-based)

% ROI bounds such that template center aligned at (prev_x, prev_y)
% gives valid-output center at (roi_hs+1, roi_hs+1).
xMin = max(1, round(prev_x - (cx - 1) - roi_hs));
yMin = max(1, round(prev_y - (cy - 1) - roi_hs));
xMax = min(imgW, xMin + 2*roi_hs + Wt - 1);
yMax = min(imgH, yMin + 2*roi_hs + Ht - 1);

ROI = img(yMin:yMax, xMin:xMax);

[C, ~] = wncc2_apply(ROI, S, 'fft');
[peak, pidx] = max(C(:));
[py, px] = ind2sub(size(C), pidx);

% Subpixel refinement (separable quadratic)
[dxs, dys] = spq(C, py, px);

% Convert valid-map peak to full-image template-center position:
%   template top-left in full image: (xMin + px - 1, yMin + py - 1)
%   template center: add (cx-1, cy-1)
x_out = xMin + (px - 1) + (cx - 1) + dxs;
y_out = yMin + (py - 1) + (cy - 1) + dys;

end


% --------------------------------------------------------
%  Helper: Full-frame normxcorr2 (frame 1 bootstrap + fallback)
% --------------------------------------------------------
function [x_out, y_out, peak] = full_ncc_track(template, img, Ht, Wt)
corr = normxcorr2(template, img);
[peak, idx] = max(corr(:));
[yr, xr] = ind2sub(size(corr), idx);
% normxcorr2 'full' peak → template center position
x_out = xr - Wt + 1 + floor((Wt - 1) / 2);
y_out = yr - Ht + 1 + floor((Ht - 1) / 2);
end


% --------------------------------------------------------
%  Helper: Separable quadratic sub-pixel refinement
% --------------------------------------------------------
function [dx, dy] = spq(C, py, px)
dx = 0;  dy = 0;
if py > 1 && py < size(C,1) && px > 1 && px < size(C,2)
    c = C(py, px);
    l = C(py, px-1);  r = C(py, px+1);
    u = C(py-1, px);  d = C(py+1, px);
    denx = l - 2*c + r;
    deny = u - 2*c + d;
    if abs(denx) > eps;  dx = 0.5*(l - r) / denx;  end
    if abs(deny) > eps;  dy = 0.5*(u - d) / deny;  end
    dx = max(-1, min(1, dx));
    dy = max(-1, min(1, dy));
end
end





function write_results_v2(results, result_path, wells, data_path)

timestamp_str = datestr(now, 'dd-mmm-yyyy_(HH-MM-SS)');
result_file = fullfile(result_path, sprintf('Results_%s.txt', timestamp_str));

fid = fopen(result_file, 'w');

fprintf(fid, 'Sample_Name\tWell_ID\tPacing_Rate_BPM\tPacing_Rate_Hz\tFrame\tTime_ms\tX1\tY1\tX2\tY2\n');

folder_names = fieldnames(results);

for i = 1:length(folder_names)
    valid_name = folder_names{i};

    found_folder = false;

    well_ids = fieldnames(wells);
    for w = 1:length(well_ids)
        well_id = well_ids{w};
        well = wells.(well_id);

        for f = 1:length(well.folders)
            folder_name = well.folders{f};
            if strcmp(matlab.lang.makeValidName(folder_name), valid_name)
                [~, well_id_parsed, rate_bpm, rate_hz, ~] = parse_folder_name(folder_name);

                timestamps = results.(valid_name);

                for frame = 1:length(timestamps)
                    fprintf(fid, '%s\t%s\t%d\t%.4f\t%d\t%d\t%.1f\t%.1f\t%.1f\t%.1f\n', ...
                            folder_name, ...
                            well_id_parsed, ...
                            rate_bpm, ...
                            rate_hz, ...
                            frame - 1, ...
                            timestamps(frame).time, ...
                            timestamps(frame).x1, ...
                            timestamps(frame).y1, ...
                            timestamps(frame).x2, ...
                            timestamps(frame).y2);
                end

                found_folder = true;
                break;
            end
        end

        if found_folder
            break;
        end
    end
end

fclose(fid);

fprintf('\nResults saved to: %s\n', result_file);

end


function result = ifelse(condition, true_val, false_val)
if condition
    result = true_val;
else
    result = false_val;
end
end
