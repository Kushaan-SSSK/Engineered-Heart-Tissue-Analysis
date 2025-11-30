results_folder = 'C:\Users\kusha\Downloads\11.11.25 EHT\EHT-scope-main\Results';

pixel_size = 67;

config_file = 'EHT_config.m';

fprintf('=== Multi-Pacing Force Analysis ===\n');

result_files = dir(fullfile(results_folder, 'Results_*.txt'));
if isempty(result_files)
    error('No Results_*.txt files found in %s', results_folder);
end

[~, idx] = max([result_files.datenum]);
results_file = fullfile(results_folder, result_files(idx).name);

fprintf('Loading results from: %s\n\n', results_file);

data = readtable(results_file, 'Delimiter', char(9));

wells = unique(data.Well_ID);
pacing_rates = unique(data.Pacing_Rate_BPM);

fprintf('Found %d wells: %s\n', length(wells), strjoin(string(wells), ', '));
fprintf('Found %d pacing rates: %s BPM\n\n', length(pacing_rates), mat2str(pacing_rates));

fprintf('=== Starting Force Analysis ===\n');
config = load_EHT_config(config_file);

fig_num = 1;

for i = 1:length(wells)
    for j = 1:length(pacing_rates)
        well = wells{i};
        pacing_bpm = pacing_rates(j);
        pacing_hz = pacing_bpm / 60;

        fprintf('\n--- Analyzing Well %s at %d BPM (%.2f Hz) ---\n', well, pacing_bpm, pacing_hz);

        subset = data(strcmp(data.Well_ID, well) & data.Pacing_Rate_BPM == pacing_bpm, :);

        if height(subset) < 50
            fprintf('Warning: Only %d frames found. Skipping.\n', height(subset));
            continue;
        end

        temp_file = fullfile(results_folder, ...
                            sprintf('%s_%dBPM_temp.txt', well, pacing_bpm));
        writetable(subset, temp_file, 'Delimiter', char(9));

        try
            analyze_EHT_with_figure(temp_file, pixel_size, pacing_hz, config_file, fig_num);
            fprintf('Analysis completed successfully (Figure %d)\n', fig_num);
            fig_num = fig_num + 1;
        catch ME
            fprintf('Error during analysis: %s\n', ME.message);
            if ~isempty(ME.stack)
                fprintf('  at line %d in %s\n', ME.stack(1).line, ME.stack(1).name);
            end
        end
    end
end

fprintf('\n=== Analysis Complete ===\n');
fprintf('Results and figures have been saved to the Results folder.\n');
fprintf('Each result file is named: [Well]_[PacingRate]BPM_temp_result.txt\n');
fprintf('Each figure is saved as: [Well]_[PacingRate]BPM_temp_fig.fig\n');
