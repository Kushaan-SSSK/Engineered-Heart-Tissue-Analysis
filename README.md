# EHT-scope
**Engineered heart tissue imaging platform with acquisition and analysis software**

The platform is designed to image engineered heart tissues suspended on flexible posts in a 24 well dish.

## Components

* **EHT-scope Hardware Build**: Instructions and schematics to build the imaging platform
* **Code**: Software for acquisition, tracking, and analysis
  * **EHT-analyze**: MATLAB scripts to analyze post positions and calculate physiological parameters

## Workflow (MATLAB-Based)

1.  **Acquisition**: Automated 24-well plate imaging with pacing protocols
2.  **Motion Tracking** (`EHT_motion_tracker.m`): Template-based post position tracking
3.  **Force Analysis** (`multi_pacing_analysis.m`): Calculate force, contraction/relaxation kinetics, and beat metrics

## Key Features

✓ No ImageJ dependency - all analysis in MATLAB
✓ Automated batch processing of multiple wells
✓ Physiological parameter extraction (force, beat rate, kinetics)
✓ Customizable for different tissue geometries and pacing protocols

## Getting Started

See `Code/EHT-analyze/README.md` for detailed usage instructions.
