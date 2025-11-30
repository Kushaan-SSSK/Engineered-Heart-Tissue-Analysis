# EHT-scope Code - MATLAB Workflow
Author: Kushaan Sharma

This folder contains all the code for the EHT-scope platform using a unified MATLAB workflow.

## Overview

The workflow consists of three main stages:
1. **Image Acquisition** - Automated imaging via MicroManager (BeanShell)
2. **Motion Tracking** - Post position tracking using MATLAB Image Processing Toolbox
3. **Force Analysis** - Physiological parameter calculation in MATLAB

## Files

### Arduino Controller
- **EHT_controller.ino**: Arduino sketch for controlling optical pacer, focus motor, and illumination

### Acquisition
- **EHT_acqure_v2.bsh**: BeanShell script for automated acquisition via MicroManager

### Motion Tracking (MATLAB)
- **EHT-analyze/EHT_motion_tracker.m**: Main motion tracking function

### Force Analysis (MATLAB)
- **EHT-analyze/multi_pacing_analysis.m**: Main analysis script
- **EHT-analyze/analyze_EHT_with_figure.m**: Detailed analysis and plotting
- **EHT-analyze/post_force2.m**: Force calculation from post deflection
- **EHT-analyze/find_pv7.m**: Peak and valley detection
- **EHT-analyze/peakdet2.m**: Peak detection algorithm
- **EHT-analyze/sgolayfilt.m**: Savitzky-Golay filter
- **EHT-analyze/analyze_slopes.m**: Contraction/relaxation slope analysis
- **EHT-analyze/detect_maxmin.m**: Helper wrapper function
- **EHT-analyze/calculate_slopes.m**: Helper wrapper function

## Requirements

### MATLAB
- MATLAB R2016b or later
- Image Processing Toolbox

### MicroManager (for acquisition only)
- MicroManager 2.0 or later
- Compatible camera and motorized stage

## Quick Start

### 1. Acquisition
Run `EHT_acqure_v2.bsh` in MicroManager to capture images.

### 2. Motion Tracking
```matlab
% In MATLAB, navigate to Code/EHT-analyze/
EHT_motion_tracker()
```

### 3. Force Analysis
```matlab
% In MATLAB
multi_pacing_analysis()
```

## Data Flow

```
Raw Images (TIF) 
    ↓ (MicroManager)
Image Folders + Metadata
    ↓ (EHT_motion_tracker.m)
Post Positions (TXT)
    ↓ (multi_pacing_analysis.m)
Force Metrics (TXT) + Plots (FIG)
```

## Documentation

See **EHT-analyze/README.md** for comprehensive documentation including:
- Detailed usage instructions
- Parameter descriptions
- Calibration procedures
- Troubleshooting guide
- Example workflows

## Advantages of MATLAB Workflow

✓ **No ImageJ dependency**: All processing in MATLAB  
✓ **Unified environment**: One platform for all analysis  
✓ **Powerful visualization**: MATLAB plotting and export  
✓ **Academic standard**: Widely used in research  
✓ **Reproducible**: Version-controlled analysis scripts  

## Support

For detailed help, see `EHT-analyze/README.md` in this directory.
