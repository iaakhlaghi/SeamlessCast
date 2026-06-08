# Calibration Workflow

This document describes the calibration workflow used in SeamlessCast.

SeamlessCast is a modular calibration-to-playback framework for scalable multi-projector displays. The calibration workflow converts projector-camera observations into reusable geometric warping maps, blending-weight maps, and metadata files that can be used by the playback module.

## Overview

The calibration workflow consists of the following main stages:

1. projector and camera setup
2. projector mask acquisition
3. fiducial pattern projection
4. fiducial marker detection
5. correspondence extraction
6. polynomial geometric mapping
7. inverse lookup-map generation
8. blending-weight generation
9. calibration-data export

The output of the calibration stage is a set of JSON and CSV files that can be loaded by the Python playback module.

## 1. Projector and Camera Setup

The projectors illuminate the target display surface, and one or more cameras observe the projected calibration patterns.

The target surface may be planar, curved, or dome-like. In the controlled setup reported in the manuscript, two projectors and one camera were used.

The projectors do not need to be identical, provided that their projected fiducial patterns can be detected reliably.

## 2. Projector Mask Acquisition

For each projector, a binary or grayscale mask is acquired to determine the visible footprint of the projector on the reference canvas.

The projector mask is used to identify the valid projection region and to support blending-weight generation.

Typical outputs from this stage may include:

```text
projector_01_mask.png
projector_02_mask.png
```

The exact filenames may differ depending on the repository version.

## 3. Fiducial Pattern Projection

Each projector displays a fiducial-marker pattern, such as an AprilTag mosaic.

The camera captures the projected fiducial pattern. Since each marker has a unique identity, detected markers can be matched automatically to their corresponding reference positions.

This avoids manual point selection and simplifies the calibration process.

## 4. Fiducial Marker Detection

The captured calibration images are processed to detect fiducial markers.

For each detected marker, the corner points are extracted. The marker centroid is then computed from the four detected corners.

The centroid is used as a compact and repeatable geometric feature for calibration.

## 5. Correspondence Extraction

For each projector, detected fiducial centroids are matched to their known coordinates in the projector reference pattern.

Each correspondence has the form:

```text
projector coordinate  ->  reference-canvas coordinate
```

These correspondences are used to estimate the geometric mapping between the projector image and the reference canvas.

## 6. Polynomial Geometric Mapping

SeamlessCast estimates a two-dimensional polynomial mapping for each projector.

The mapping relates projector-native pixel coordinates to coordinates on the common reference canvas.

Polynomial mappings can compensate for keystone distortion, optical-axis mismatch, surface curvature, and local geometric deviations.

In the manuscript, polynomial degrees 2, 3, and 4 were evaluated. The third-degree polynomial was used as a practical compromise between fitting accuracy and geometric flexibility.

## 7. Inverse Lookup-Map Generation

After estimating the polynomial mapping, SeamlessCast generates dense inverse lookup maps for each projector.

For each projector pixel, the lookup maps specify the corresponding sampling coordinate in the input image or working canvas.

Each projector has two lookup maps:

```text
projector_XX_xIn.csv
projector_XX_yIn.csv
```

where `XX` denotes the projector index.

These lookup maps are computed once during calibration and reused during playback.

## 8. Blending-Weight Generation

Projector masks are converted into smooth blending-weight maps.

The blending weights are generated using distance-transform-based feathering and normalization across projectors.

For each projector, the exported blending-weight map has the form:

```text
projector_XX_weight.csv
```

The weight maps reduce visible seams and prevent excessive brightness accumulation in overlap regions.

## 9. Calibration-Data Export

The final calibration data are exported in transparent and portable formats.

The main exported files are:

```text
calibration_metadata.json
projector_01_xIn.csv
projector_01_yIn.csv
projector_01_weight.csv
projector_02_xIn.csv
projector_02_yIn.csv
projector_02_weight.csv
```

The JSON file contains metadata such as working-canvas size, projector configuration, interpolation settings, and filenames of the corresponding lookup and weight maps.

The CSV files contain dense numerical maps used by the playback module.

## Output of the Calibration Workflow

The calibration workflow produces:

```text
projector-specific geometric mappings
inverse lookup maps
projector validity information
projector masks
distance-transform-based blending weights
normalized weight maps
JSON metadata
CSV calibration maps
calibration metrics
```

These outputs are sufficient for the playback module to generate corrected projector-specific frames without repeating calibration.

## Hardware-Dependent Notes

Some stages of the calibration workflow depend on the local hardware setup, including:

```text
projector display control
camera image acquisition
display switching delays
camera exposure and focus
physical placement of projectors and camera
visibility of fiducial markers
projection-surface geometry
```

For this reason, exact live acquisition may differ across systems.

However, the repository includes representative calibration data and exported calibration files that allow users to inspect and reproduce the computational parts of the workflow.

## Relationship to Playback

The calibration workflow is separated from the playback workflow.

Calibration is performed once to generate reusable lookup maps, blending-weight maps, and metadata.

Playback then uses these exported files to warp and blend still images or video frames in real time or near real time.

The playback workflow is described separately in:

```text
docs/playback_workflow.md
```

## Relationship to the Manuscript

This workflow corresponds to the methodology described in the manuscript:

```text
SeamlessCast: A Modular Calibration-to-Playback Framework for Scalable Multi-Projector Displays
```

submitted to:

```text
The Visual Computer
```