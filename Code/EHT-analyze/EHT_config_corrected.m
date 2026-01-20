config.pixel_size = 67;

config.post_radius = 1.0;
config.diastolic_distance = 8.0;
config.tissue_height = 12.0;

config.youngs_modulus = 1.7;

config.template_width = 50;
config.template_height = 50;
config.score_threshold = 0.4;

config.min_distance = 30;

config.peak_threshold = 1.0; % Increased to 1.0 to match legacy Analyze_logs_EHT.m

config.outlier_sensitivity = 10; % Reverted to 10 to match legacy Analyze_logs_EHT.m

config.sg_poly_order = 4;
config.sg_window_size = 11;
