function [basename, well_id, pacing_rate_bpm, pacing_rate_hz, is_valid] = parse_folder_name(folder_name)

basename = '';
well_id = '';
pacing_rate_bpm = 0;
pacing_rate_hz = 0;
is_valid = false;

if ~ischar(folder_name) && ~isstring(folder_name)
    return;
end

folder_name = char(folder_name);

pattern = '^(.+)_([A-Za-z]+\d+)_(\d+)$';
tokens = regexp(folder_name, pattern, 'tokens');

if isempty(tokens)
    pattern2 = '^([A-Za-z]+\d+)_(\d+)$';
    tokens2 = regexp(folder_name, pattern2, 'tokens');

    if ~isempty(tokens2)
        basename = '';
        well_id = upper(tokens2{1}{1});
        pacing_rate_bpm = sscanf(tokens2{1}{2}, '%f');
        is_valid = true;
    else
        return;
    end
else
    basename = tokens{1}{1};
    well_id = upper(tokens{1}{2});
    pacing_rate_bpm = sscanf(tokens{1}{3}, '%f');
    is_valid = true;
end

if is_valid
    pacing_rate_hz = pacing_rate_bpm / 60.0;

    if pacing_rate_bpm < 0 || pacing_rate_bpm > 500
        warning('Unusual pacing rate detected: %d BPM in folder "%s"', ...
                pacing_rate_bpm, folder_name);
    end

    well_letter = regexp(well_id, '^[A-Z]+', 'match', 'once');
    well_number_str = regexp(well_id, '\d+$', 'match', 'once');
    if ~isempty(well_number_str) && iscell(well_number_str)
        well_number = sscanf(well_number_str{1}, '%f');
    elseif ~isempty(well_number_str) && ischar(well_number_str)
        well_number = sscanf(well_number_str, '%f');
    else
        well_number = NaN;
    end

    if isempty(well_letter) || isnan(well_number)
        warning('Invalid well ID format: "%s" in folder "%s"', well_id, folder_name);
        is_valid = false;
    end
end

end
