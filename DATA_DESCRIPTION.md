# Data Description

This document describes the representative data files included with the SeamlessCast repository.

SeamlessCast is a modular calibration-to-playback framework for scalable multi-projector displays. The repository includes source code, representative calibration data, exported calibration maps, blending weights, and example output images from the controlled two-projector setup reported in the manuscript.

## Dataset Overview

The included dataset corresponds to a controlled planar two-projector and one-camera setup. This setup was used in the manuscript to evaluate geometric calibration accuracy, calibration repeatability, polynomial mapping degree, blending performance, calibration-data export, and playback validation.

The dataset is provided to support transparency and reproducibility of the reported results.

## Main Data Categories

### 1. Calibration Metadata

Calibration metadata are stored in JSON format. These files describe the working canvas, projector configuration, map filenames, interpolation settings, and playback-related parameters.

Typical file:

```text
data/player_calibration/calibration_metadata.json
```

This file is used by the Python playback module to load the corresponding lookup maps and blending-weight maps.

### 2. Lookup Maps

For each projector, SeamlessCast exports two dense inverse lookup maps:

```text
projector_XX_xIn.csv
projector_XX_yIn.csv
```

where `XX` denotes the projector index.

The horizontal lookup map specifies the input-frame x-coordinate sampled by each projector pixel. The vertical lookup map specifies the corresponding input-frame y-coordinate.

These maps are generated during calibration and reused during playback. They allow the player to pre-warp image or video frames without re-estimating the geometric mapping.

### 3. Blending-Weight Maps

For each projector, SeamlessCast exports a normalized blending-weight map:

```text
projector_XX_weight.csv
```

The weight map specifies the spatial contribution of each projector during playback. In overlap regions, these weights reduce excessive brightness accumulation and support smooth transitions between adjacent projector footprints.

The weights are normalized across projectors and are applied to the red, green, and blue channels during color-image or video playback.

### 4. Calibration Metrics

The repository includes calibration-metric files from repeated calibration runs. These files summarize the number of matched fiducial markers and RMS fitting residuals for each projector.

Typical files:

```text
results/calibration_metrics/calibration_metrics_run_01.json
results/calibration_metrics/calibration_metrics_run_02.json
results/calibration_metrics/calibration_metrics_run_03.json
results/calibration_metrics/calibration_metrics_run_04.json
results/calibration_metrics/calibration_metrics_run_05.json
```

These files support the repeatability analysis reported in the manuscript.

### 5. Photometric Evaluation Images

The photometric evaluation images correspond to the captured gray-level overlap test used to evaluate blending behavior.

Typical files:

```text
results/photometric/captured_gray_single_projector_01.png
results/photometric/captured_gray_single_projector_02.png
results/photometric/captured_gray_before_blending.png
results/photometric/captured_gray_after_blending.png
```

These images were used to compare the overlap luminance before and after applying the proposed blending weights.

### 6. Example Input and Output Images

The repository includes example images for playback validation. These files may include:

```text
examples/input_image.jpg
examples/projector_01_output.png
examples/projector_02_output.png
examples/camera_captured_final_result.png
```

The exact filenames may differ depending on the repository version. Please refer to the `examples/` folder and the main `README.md` file for the current file names.

The purpose of these files is to demonstrate that the exported calibration data can be loaded by the Python player and used for calibrated image playback.

## Data Resolution

In the controlled two-projector setup, the projector and working-canvas resolution were:

```text
1920 x 1080 pixels
```

The exported lookup maps and blending-weight maps are therefore stored as dense numerical arrays with dimensions corresponding to the full-HD working canvas.

Depending on the storage format, arrays may appear as:

```text
1080 x 1920
```

which corresponds to image-array indexing in row-column order.

## Data Formats

The repository uses transparent and portable file formats:

```text
JSON    : calibration metadata and metric summaries
CSV     : dense lookup maps and blending-weight maps
PNG/JPG : calibration, photometric, and output images
MP4     : optional video input or playback examples
MAT     : optional MATLAB intermediate calibration files, if included
```

## Reproducibility Notes

The complete hardware acquisition process depends on the local projector-camera setup. Therefore, exact acquisition cannot be reproduced without similar hardware.

However, the provided data allow users to reproduce and inspect the main computational stages of the framework, including:

```text
loading calibration metadata
loading lookup maps
loading blending-weight maps
applying lookup-based image warping
applying projector-specific blending weights
generating projector-specific output frames
inspecting calibration metrics
checking repeatability results
reviewing photometric before/after blending examples
```

## Relationship to the Manuscript

The data in this repository are associated with the manuscript:

```text
SeamlessCast: A Modular Calibration-to-Playback Framework for Scalable Multi-Projector Displays
```

submitted to:

```text
The Visual Computer
```

The included files support the experimental results reported in the manuscript, including geometric calibration accuracy, repeatability assessment, polynomial-degree evaluation, blending analysis, calibration-data export, runtime behavior, and playback validation.

## Citation

If you use the SeamlessCast source code or the associated data in academic work, please cite the associated manuscript and this repository.

Citation information is provided in:

```text
CITATION.cff
README.md
```

## Contact

For questions about the data or reproducibility, please contact:

```text
Iman Ahadi Akhlaghi
Department of Electrical Engineering and Biomedical Engineering
Sadjad University of Technology
Mashhad, Iran
Email: 
i_a_akhlaghi@sadjad.ac.ir
i.a.akhlaghi@gmail.com
```
