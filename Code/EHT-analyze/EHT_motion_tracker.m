function EHT_motion_tracker(template_path, data_path, result_path, perform_annotation, config_file)

if nargin < 4
    perform_annotation = true;
end

if nargin < 5
    config_file = '';
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
    annotate_posts_by_well(wells, well_names, template_path, config);
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


function annotate_posts_by_well(wells, well_names, template_path, config)

fprintf('\n=== Post Annotation (Once Per Well) ===\n');

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

    if exist(template0_path, 'file') && exist(template1_path, 'file')
        fprintf('  Templates already exist, skipping annotation\n');
        continue;
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

            fprintf('  ✓ Templates saved to %s\n', well_template_dir);
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

tif_files = dir(fullfile(folder_path, '*.tif'));
tif_files = {tif_files.name};
tif_files = sort(tif_files);

if isempty(tif_files)
    warning('No TIFF files found in %s', folder_path);
    return;
end

for frame_idx = 1:length(tif_files)
    img_path = fullfile(folder_path, tif_files{frame_idx});
    img = imread(img_path);

    if size(img, 3) == 3
        img = rgb2gray(img);
    end
    img = double(img);

    corr0 = normxcorr2(template0, img);
    [max_val0, max_idx0] = max(corr0(:));
    [y0, x0] = ind2sub(size(corr0), max_idx0);

    x0 = x0 - size(template0, 2) + 1 + floor((size(template0, 2)-1)/2);
    y0 = y0 - size(template0, 1) + 1 + floor((size(template0, 1)-1)/2);

    if max_val0 < config.score_threshold
        x0 = 0;
        y0 = 0;
    end

    corr1 = normxcorr2(template1, img);
    [max_val1, max_idx1] = max(corr1(:));
    [y1, x1] = ind2sub(size(corr1), max_idx1);

    x1 = x1 - size(template1, 2) + 1 + floor((size(template1, 2)-1)/2);
    y1 = y1 - size(template1, 1) + 1 + floor((size(template1, 1)-1)/2);

    if max_val1 < config.score_threshold
        x1 = 0;
        y1 = 0;
    end

    if frame_idx <= length(timestamps)
        timestamps(frame_idx).x1 = x1;
        timestamps(frame_idx).y1 = y1;
        timestamps(frame_idx).x2 = x0;
        timestamps(frame_idx).y2 = y0;
    end
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
