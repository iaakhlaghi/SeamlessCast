# MATLAB Requirements

The calibration part of SeamlessCast was developed and tested in MATLAB.

## Recommended MATLAB Version

MATLAB R2023b or later is recommended.

The code may also work in earlier recent MATLAB versions, but it has not been systematically tested on all releases.

## Required MATLAB Toolboxes

The following MATLAB toolboxes are recommended:

- Image Processing Toolbox
- Computer Vision Toolbox

## Main MATLAB Components

The MATLAB part of SeamlessCast includes modules for:

- projector mask acquisition
- fiducial-marker image processing
- geometric correspondence extraction
- polynomial projector-to-reference mapping
- inverse lookup-map generation
- distance-transform-based blending-weight generation
- JSON/CSV calibration-data export

## Fiducial Marker Detection

The current implementation uses AprilTag-based fiducial markers. Depending on the MATLAB version, AprilTag detection may require functions from the Computer Vision Toolbox.

If AprilTag detection is not available in the user's MATLAB installation, detected marker centroids or correspondence files can be provided as input for reproducing the geometric calibration and export stages.

## Input and Output Data

The MATLAB calibration module takes calibration images, projector masks, and fiducial correspondences as input and generates:

- projector-specific geometric mappings
- horizontal inverse lookup maps
- vertical inverse lookup maps
- normalized blending-weight maps
- JSON metadata
- CSV calibration maps

## Notes

Some acquisition-related parts depend on the local projector and camera configuration. For reproducibility, this repository includes representative calibration data and exported calibration files from the controlled two-projector setup reported in the manuscript.