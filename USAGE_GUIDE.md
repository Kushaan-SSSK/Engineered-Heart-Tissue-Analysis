# EHT Analysis Pipeline - Usage Guide

## Overview
This guide explains how to run the EHT analysis pipeline to track post motion and calculate force metrics from engineered heart tissue videos.

## Prerequisites
- MATLAB R2016b or later
- Image Processing Toolbox
- Curve Fitting Toolbox

## Quick Start

### Step 1: Prepare Your Data
Organize your data folders following this naming convention:
```
[Basename]_[WellID]_[PacingRate]
```

**Examples:**
- `Acquire-EHT_C3_0` (Well C3 at 0 BPM / unpaced)
- `Acquire-EHT_C3_60` (Well C3 at 60 BPM)
- `Acquire-EHT_C3_120` (Well C3 at 120 BPM)

Each folder must contain:
- `Pos0/` subfolder with `.tif` image files
- `Pos0/metadata.txt` with timing information

### Step 2: Motion Tracking

Navigate to the analysis directory:
```matlab
cd('C:\Users\kusha\Downloads\11.11.25 EHT\EHT-scope-main\Code\EHT-analyze')
```

Run the motion tracker:
```matlab
% Set your paths
template_path = 'C:/Path/To/Templates/';
data_path = 'C:/Path/To/Your/Data/';
result_path = 'C:/Path/To/Results/';

% Run motion tracker (with annotation for first time)
EHT_motion_tracker(template_path, data_path, result_path, true);
```

**What this does:**
- Scans your data folder for video folders
- Asks you to annotate posts ONCE per well (drag boxes around the two posts)
- Tracks post motion across all frames and pacing rates
- Saves results to: `Results_DD-MMM-YYYY_(HH-MM-SS).txt`

**For subsequent runs** (templates already exist):
```matlab
EHT_motion_tracker(template_path, data_path, result_path, false);
```

### Step 3: Force Analysis

After motion tracking completes, run the analysis:
```matlab
multi_pacing_analysis
```

**What this does:**
- Automatically finds the most recent `Results_*.txt` file
- Analyzes each well at each pacing rate
- Generates figures and result files for each well/pacing combination

**Output files** (in Results folder):
- `[Well]_[Rate]BPM_temp_result.txt` - Force metrics
- `[Well]_[Rate]BPM_temp_fig.fig` - Force vs. time plot

## Configuration

### Pixel Calibration
Update the pixel size in `multi_pacing_analysis.m`:
```matlab
pixel_size = 67;  % Update with YOUR camera calibration (pixels/mm)
```

### Results Folder
Change the results folder path in `multi_pacing_analysis.m`:
```matlab
results_folder = 'C:\Path\To\Your\Results';
```

## Example Workflow

Complete example for analyzing the D31 dataset:

```matlab
% Navigate to code folder
cd('C:\Users\kusha\Downloads\11.11.25 EHT\EHT-scope-main\Code\EHT-analyze')

% Step 1: Motion tracking (first time - with annotation)
template_path = 'C:/Users/kusha/Downloads/11.11.25 EHT/EHT-scope-main/Templates/';
data_path = 'C:/Users/kusha/Downloads/11.11.25 EHT/EHT-scope-main/D31_plate1_kushaan try_181125/';
result_path = 'C:/Users/kusha/Downloads/11.11.25 EHT/EHT-scope-main/Results/';

EHT_motion_tracker(template_path, data_path, result_path, true);

% Step 2: Force analysis (after Step 1 completes)
multi_pacing_analysis
```

## Expected Results

For the D31 dataset (Well C3), you should get results similar to:

| Condition | Diastolic Force | Systolic Force | Developed Force |
|:----------|:----------------|:---------------|:----------------|
| Baseline (0 BPM) | 0.250 mN | 0.785 mN | 0.535 mN |
| 60 BPM | 0.248 mN | 0.798 mN | 0.550 mN |
| 120 BPM | 0.311 mN | 0.871 mN | 0.561 mN |

## Troubleshooting

### "Found 0 wells"
- Check that your `data_path` is correct
- Verify folder names follow the `[Basename]_[WellID]_[PacingRate]` format
- Ensure each folder has a `Pos0` subfolder with images

### "No Results_*.txt files found"
- Run Step 1 (motion tracker) first
- Check that `results_folder` path in `multi_pacing_analysis.m` matches your `result_path`

### Templates not found
- Run motion tracker with `true` as the last parameter
- Complete the post annotation step by dragging boxes around the posts

## Advanced Usage

### Using Video-Specific Templates
If you have different templates for each pacing rate, place them in:
```
[VideoFolder]/Pos0/templates/template0.tif
[VideoFolder]/Pos0/templates/template1.tif
```

The motion tracker will prioritize video-specific templates over well-based templates.

### Batch Processing
To process multiple datasets, create a script that loops through your data folders:
```matlab
datasets = {'Dataset1', 'Dataset2', 'Dataset3'};
for i = 1:length(datasets)
    data_path = fullfile(base_path, datasets{i});
    EHT_motion_tracker(template_path, data_path, result_path, false);
end
```

## Output Metrics

The analysis calculates the following physiological parameters:

- **Diastolic Force** (mN): Baseline force at rest
- **Systolic Force** (mN): Peak force during contraction
- **Developed Force** (mN): Difference between systolic and diastolic
- **T50** (s): Time to 50% relaxation
- **Upstroke Velocity** (mN/s): Rate of force increase
- **Downstroke Velocity** (mN/s): Rate of force decrease
- **Beat Rate** (Hz): Frequency of contractions

## Notes

- Templates are saved per well and reused for all pacing rates in that well
- The first run requires manual annotation; subsequent runs are automatic
- Results are timestamped to prevent overwriting
- All analysis uses the corrected MATLAB algorithms with bug fixes applied
