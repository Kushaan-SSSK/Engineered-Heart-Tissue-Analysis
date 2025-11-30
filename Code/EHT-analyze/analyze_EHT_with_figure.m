function analyze_EHT_with_figure(file_name, pixel, pacing_freqs, config_file, fig_num)

if nargin < 5
    fig_num = 1;
end

if nargin < 4
    config_file = '';
end

config = load_EHT_config(config_file);

post_radius = config.post_radius;
diastolicdist = config.diastolic_distance;
tissue_heights = config.tissue_height;
thresh = config.peak_threshold;
sens = config.outlier_sensitivity;
p_order = config.sg_poly_order;
w_size = config.sg_window_size;

log = readtable(file_name);

if width(log) <= 7
    log = log(:,3:end);
else
    log = log(:,6:end);
end

log = table2array(log);
log(:,1) = log(:,1)./1000;

post_distances = sqrt((log(:,4)-log(:,2)).^2+(log(:,3)-log(:,5)).^2) ./ pixel;
measurement_times = log(post_distances~=0,1);
measurement_times = measurement_times - min(measurement_times);
post_distances = post_distances(post_distances~=0);

actual_diastolic_dist = diastolicdist;
fprintf('  Using fixed diastolic distance: %.3f mm\n', actual_diastolic_dist);

total_deflections = actual_diastolic_dist - post_distances;
post_deflections = total_deflections / 2;
raw_force = post_force2(post_deflections, tissue_heights, tissue_heights, post_radius);

smooth_data = sgolayfilt(raw_force, p_order, w_size);

indout = (1:length(raw_force))';

sampling_freq = 1 / mean(diff(measurement_times));
zm_force = smooth_data - mean(smooth_data);
L = length(smooth_data);
NFFT = 2^nextpow2(L);
fc = fft(zm_force, NFFT)/L;
nfft_half = floor(NFFT/2) + 1;
fc = 2*abs(fc(1:nfft_half));
f = sampling_freq/2 * linspace(0, 1, nfft_half);
[max_fc, max_i] = max(fc);
beating_freqs = f(max_i);

[max_t, maxima, min_t, minima] = detect_maxmin(measurement_times, smooth_data, thresh);
indices = 1:length(smooth_data);
[max_ind, maxjunk, min_ind, minjunk] = detect_maxmin(indices, smooth_data, thresh);
clearvars maxjunk minjunk

if isempty(maxima) || isempty(minima)
    warning('No peaks/valleys detected in the data. The tissue may not be beating or the threshold may be too high.');
    fprintf('Data characteristics:\n');
    fprintf('  Force range: %.4f to %.4f mN\n', min(smooth_data), max(smooth_data));
    fprintf('  Force std dev: %.4f mN\n', std(smooth_data));
    fprintf('  Peak threshold: %.2f\n', thresh);
    fprintf('\nTip: Try adjusting peak_threshold in config file if tissue is beating.\n');
    return;
end

peak_v = zeros(size(smooth_data));
val_v = zeros(size(smooth_data));
cur_pk = 1;
cur_vl = 1;

for n=1:length(smooth_data)

    if ~isempty(maxima)
        peak_v(n) = maxima(cur_pk);
        val_v(n) = minima(cur_vl);

        if (cur_pk < length(maxima) && measurement_times(n) >= max_t(cur_pk+1));
            cur_pk = cur_pk + 1;
        end
        if (cur_vl < length(minima) && measurement_times(n) >= min_t(cur_vl+1));
            cur_vl = cur_vl + 1;
        end

    end
end

if (~isempty(maxima))
    max_deflections = max(maxima);
    dev_forces = mean(peak_v-val_v);
    dev_forc_std = std(peak_v-val_v);

    dias_forces = mean(val_v);
    dias_forc_st = std(val_v);
    syst_forces = mean(peak_v);
    syst_forces_st = std(peak_v);

    force(:,1) = measurement_times;
    force(:,2) = smooth_data;

    periods = diff(max_t);
    beatrate = 1./periods;

    beating_rates = mean(beatrate);
    beating_rates_std = std(beatrate);

    t2prev = periods(1:end-1);
    t2next = periods(2:end);
end

contractpoints = {};
relaxpoints = {};
contraction_times = [];
r = 1;
relaxedpoints = [];
T50vals = [];
time = measurement_times;

for z = 1:length(maxima)-1
    Tl = [];
    Tr = [];
    minimum = (val_v(max_ind(z))+val_v(max_ind(z+1)))/2;

    F90 = (maxima(z) - minimum)*.90 + minimum;
    F10 = (maxima(z) - minimum)*.10 + minimum;
    F50 = (maxima(z) + minimum)/2;

    llimit = r;
    rlimit = max_ind(z+1);
    l = max_ind(z)-1;
    r = max_ind(z)+1;

    relaxpoints{z,1} = max_ind(z);
    contractpoints{z,1} = max_ind(z);
    relaxpoints{z,2} = [];
    contractpoints{z,2} = [];
    tempr = [];
    templ = [];

    while smooth_data(r) > F10 && r<rlimit;
        if (smooth_data(r)<F90);
            relaxpoints{z,2} = [relaxpoints{z,2} r];
            tempr = [tempr r];
            if (smooth_data(r)<F50 && isempty(Tr));
                Tr = r;
            end
            r = r+1;
        else
            r = r+1;
        end
    end

    while  smooth_data(l) > F10 && l>llimit;
        if (smooth_data(l)<F90);
            contractpoints{z,2} = [l contractpoints{z,2}];
            templ = [l templ];
            if (smooth_data(l)<F50 && isempty(Tl));
                Tl = l;
            end
            l = l-1;
        else
            l = l-1;
        end
    end

    if ~isempty(Tl) && ~isempty(Tr);
        XL = smooth_data(Tl:Tl+1);
        XR = smooth_data(Tr-1:Tr);
        Tlx = time(Tl:Tl+1);
        Trx = time(Tr-1:Tr);
        a=1;
        b=2;
        while (XR(1)==XR(2));
            XL = [smooth_data(Tl-a),smooth_data(Tl+b)];
            Tlx = [time(Tl-a),time(Tl+b)];
            a=a+1;
            b=b+1;
        end
        a=1;
        b=2;
        while (XL(1) == XL(2));
            XR = [smooth_data(Tr-b),smooth_data(Tr+a)];
            Trx = [time(Tr-b),time(Tr+a)];
            a=a+1;
            b=b+1;
        end
        T50l = interp1(XL,Tlx,F50);
        T50r = interp1(XR,Trx,F50);
        T50vals(end+1,:) = [time(max_ind(z)),T50r-T50l,F50,time(max_ind(z))-T50l,T50r - time(max_ind(z))];

        xl = smooth_data(l:l+1);
        xr = smooth_data(r-1:r);
        tl = time(l:l+1);
        tr = time(r-1:r);

        relaxedpoints = [xl xr];

        if length(unique(xl))>1;
            t10_start = interp1(xl,tl,F10);
        else
            t10_start = mean(tl);
        end
        if length(unique(xr))>1;
            t10_end = interp1(xr,tr,F10);
        else
            t10_end = mean(tr);
        end

        t2peak =  time(max_ind(z))-t10_start;
        t2relax90 = t10_end - time(max_ind(z));
        t2relax50 = T50r - time(max_ind(z));

        if t2peak < 6 && t2relax90 < 6;
            contraction_times(end+1,:) = [time(max_ind(z)) t2peak t2relax50 t2relax90];

        end
    end

end

if ~isempty(contractpoints) && ~isempty(relaxpoints)
    slopes = calculate_slopes(measurement_times,smooth_data,contractpoints,relaxpoints);
else
    slopes = [NaN NaN NaN NaN];
end

beat_rate_cov = beating_rates_std/beating_rates;
tissue_name = string(file_name);

if ~isempty(T50vals) && size(T50vals, 2) >= 5
    t50 = mean(nonzeros(T50vals(:,2)));
    t50_std = std(nonzeros(T50vals(:,2)));
    c50 = mean(nonzeros(T50vals(:,4)));
    c50_std = std(nonzeros(T50vals(:,4)));
    r50 = mean(nonzeros(T50vals(:,5)));
    r50_std = std(nonzeros(T50vals(:,5)));
else
    t50 = NaN;
    t50_std = NaN;
    c50 = NaN;
    c50_std = NaN;
    r50 = NaN;
    r50_std = NaN;
end

if ~isempty(contraction_times) && size(contraction_times, 2) >= 4
    t2peak = mean(nonzeros(contraction_times(:,2)));
    t2peak_std = std(nonzeros(contraction_times(:,2)));
    r90 = mean(nonzeros(contraction_times(:,4)));
    r90_std = std(nonzeros(contraction_times(:,4)));
else
    t2peak = NaN;
    t2peak_std = NaN;
    r90 = NaN;
    r90_std = NaN;
end
if ~isempty(slopes) && size(slopes, 2) >= 4
    riseslopes = slopes(:,1);
    fallslopes = slopes(:,3);
    uv = mean(riseslopes(isfinite(riseslopes)));
    uv_std = std(riseslopes(isfinite(riseslopes)));
    dv = mean(fallslopes(isfinite(fallslopes)));
    dv_std = std(fallslopes(isfinite(fallslopes)));
else
    uv = NaN;
    uv_std = NaN;
    dv = NaN;
    dv_std = NaN;
end

output = table(tissue_name, pacing_freqs, beating_rates, beating_rates_std,...
    beat_rate_cov, dias_forces, dias_forc_st, syst_forces, syst_forces_st,...
    dev_forces, dev_forc_std, t50, t50_std, c50, c50_std, r50, r50_std, t2peak, ...
    t2peak_std, r90, r90_std, uv, uv_std, dv, dv_std);

writetable(output, [file_name,'_result.txt'], 'FileType', 'text', 'Delimiter', '\t');

figure(fig_num);
clf;
plot(time,raw_force, 'Color', [0.8 0.5 0.2], 'LineWidth', 1);
hold on;
plot(time, smooth_data, 'Color', [0.2 0.4 0.8], 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Force (mN)');
title(sprintf('EHT Force Analysis - Figure %d', fig_num));
legend('Raw Force', 'Smoothed Force', 'Location', 'best');
grid on;
hold off;
savefig(gcf, [file_name,'_fig.fig']);

end
