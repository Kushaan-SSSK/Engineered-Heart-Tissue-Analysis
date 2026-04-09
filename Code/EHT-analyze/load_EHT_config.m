function config = load_EHT_config(config_path)

if nargin < 1 || isempty(config_path)
    config = get_default_config();
    fprintf('Using default EHT configuration\n');
    return;
end

if ~exist(config_path, 'file')
    warning('Config file not found: %s\nUsing default configuration.', config_path);
    config = get_default_config();
    return;
end

try
    fprintf('Loading configuration from: %s\n', config_path);

    run(config_path);

    if ~exist('config', 'var')
        error('Config file must define a variable named "config"');
    end

    config = validate_config(config);

    fprintf('Configuration loaded successfully\n');

catch ME
    warning('Error loading config file: %s\nUsing default configuration.', ME.message);
    config = get_default_config();
end

end


function config = get_default_config()

config.pixel_size = 6.5;

config.post_radius = 1.0;
config.diastolic_distance = 8.0;
config.tissue_height = 12.0;

config.youngs_modulus = 1.7;

config.template_width = 50;
config.template_height = 50;
config.score_threshold = 0.4;
config.min_distance = 30;

config.peak_threshold = 1.0;
config.outlier_sensitivity = 10;
config.sg_poly_order = 4;
config.sg_window_size = 11;

end


function config = validate_config(config)

default_config = get_default_config();
required_fields = fieldnames(default_config);

for i = 1:length(required_fields)
    field = required_fields{i};
    if ~isfield(config, field)
        warning('Missing config field "%s", using default value: %g', ...
                field, default_config.(field));
        config.(field) = default_config.(field);
    end
end

if config.pixel_size <= 0
    error('pixel_size must be positive');
end

if config.score_threshold < 0 || config.score_threshold > 1
    warning('score_threshold should be between 0 and 1, got %g', config.score_threshold);
end

if config.template_width < 10 || config.template_height < 10
    warning('Template dimensions seem very small (w=%d, h=%d)', ...
            config.template_width, config.template_height);
end

end
