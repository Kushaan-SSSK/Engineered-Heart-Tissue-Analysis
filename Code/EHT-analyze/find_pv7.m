function [peaks_x, peaks_y, valleys_x, valleys_y] = find_pv7(x, y, thresh)

ystd = [thresh*std(y) 1];
ystd(end+1,2) = length(y);
delta = ystd;

[maxes, mins] = peakdet2(y, delta);

if isempty(maxes)
    peaks_x = [];
    peaks_y = [];
    valleys_x = [];
    valleys_y = [];
    return;
end

max_ind = maxes(:,1);
max_vals = maxes(:,2);
min_ind = mins(:,1);
min_vals = mins(:,2);

max_corrected = max_vals;
min_corrected = min_vals;

max_i = find(ismember(max_vals, max_corrected));
min_i = find(ismember(min_vals, min_corrected));

max_vals = max_vals(max_i);
min_vals = min_vals(min_i);
max_ind = max_ind(max_i);
min_ind = min_ind(min_i);

if ~isempty(min_ind) && ~isempty(max_ind)
    if (min_ind(1) < max_ind(1))
        min_ind = min_ind(2:end);
        min_vals = min_vals(2:end);
    else
        max_ind = max_ind(2:end);
        max_vals = max_vals(2:end);
    end
end

if ~isempty(min_ind) && ~isempty(max_ind)
    if (min_ind(end) > max_ind(end))
        min_ind = min_ind(1:end-1);
        min_vals = min_vals(1:end-1);
    else
        max_ind = max_ind(1:end-1);
        max_vals = max_vals(1:end-1);
    end
end

if isempty(max_ind) || isempty(min_ind)
    peaks_x = [];
    peaks_y = [];
    valleys_x = [];
    valleys_y = [];
    return;
end

peaks_x = x(max_ind);
peaks_y = max_vals;
valleys_x = x(min_ind);
valleys_y = min_vals;
end
