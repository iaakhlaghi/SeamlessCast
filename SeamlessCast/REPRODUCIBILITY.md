# Reproducibility Guide

This document provides a practical guide for reproducing the main computational stages of SeamlessCast using the source code and representative data included in this repository.

SeamlessCast is a modular calibration-to-playback framework for scalable multi-projector displays. The complete acquisition process depends on the availability of a projector-camera setup. However, the repository includes representative data from the controlled two-projector setup reported in the manuscript, allowing users to inspect and reproduce the main data-processing and playback stages.

## Reproducibility Scope

The repository supports reproducibility at two levels.

### 1. Data-Level Reproducibility

Users can inspect the exported calibration files, lookup maps, blending-weight maps, calibration metrics, and photometric evaluation images associated with the controlled two-projector setup.

This level does not require access to the original projectors or camera.

### 2. Processing-Level Reproducibility

Users can run the MATLAB and Python modules to reproduce the main computational steps, including:

- loading calibration metadata
- reading exported lookup maps
- reading blending-weight maps
- applying lookup-based image warping
- applying projector-specific blending weights
- generating projector-specific output frames
- inspecting calibration metrics
- reviewing before/after blending examples

The exact hardware acquisition stage requires a local projector-camera setup and may vary depending on the available devices.

## Repository Components

The repository includes the following main components:

```text
src/ProjectorsCalibration_MATLAB/
src/Player_Python/
data/player_calibration/
results/calibration_metrics/
results/photometric/
examples/
docs/
```

The exact folder names may vary slightly between releases. Please refer to the main `README.md` file for the current repository structure.

## MATLAB Calibration Stage

The MATLAB part of SeamlessCast includes the calibration and export modules.

Typical tasks include:

* projector mask processing
* fiducial-marker detection or correspondence processing
* polynomial projector-to-reference mapping
* inverse lookup-map generation
* distance-transform-based blending-weight generation
* JSON/CSV export for the playback module

Recommended MATLAB requirements are described in:

```text
MATLAB_REQUIREMENTS.md
```

Some acquisition-related functions depend on the local projector-camera configuration. For this reason, users who do not have access to similar hardware may reproduce the computational stages using the provided exported calibration data.

## Python Playback Stage

The Python playback module loads the exported calibration data and applies them to input images or video frames.

The main playback steps are:

1. load the calibration metadata from JSON
2. load projector-specific lookup maps from CSV files
3. load projector-specific blending-weight maps from CSV files
4. prepare the input frame on the working canvas
5. generate warped output frames for each projector
6. multiply each warped frame by the corresponding blending-weight map
7. display or save the projector-specific output frames

Python dependencies are listed in:

```text
requirements.txt
environment.yml
```

## Suggested Python Setup

Using pip:

```bash
python -m venv seamlesscast_env
seamlesscast_env\Scripts\activate
pip install -r requirements.txt
```

On Linux or macOS:

```bash
python -m venv seamlesscast_env
source seamlesscast_env/bin/activate
pip install -r requirements.txt
```

Using conda:

```bash
conda env create -f environment.yml
conda activate seamlesscast
```

## Data Required for Playback Reproduction

To reproduce the playback stage, the following files are required:

```text
data/player_calibration/calibration_metadata.json
data/player_calibration/projector_01_xIn.csv
data/player_calibration/projector_01_yIn.csv
data/player_calibration/projector_01_weight.csv
data/player_calibration/projector_02_xIn.csv
data/player_calibration/projector_02_yIn.csv
data/player_calibration/projector_02_weight.csv
examples/input_image.jpg
```

The exact filenames may differ depending on the repository version. If necessary, update the paths in the playback script or in the metadata file.

## Expected Outputs

After running the playback module with the provided calibration data, the expected outputs are projector-specific corrected frames, such as:

```text
examples/projector_01_output.png
examples/projector_02_output.png
```

These frames are geometrically pre-warped and weighted according to the exported calibration maps.

## Calibration Metrics

The calibration metrics from repeated runs are stored as JSON files, typically in:

```text
results/calibration_metrics/
```

These files can be used to verify the repeatability results reported in the manuscript, including the number of matched fiducial markers and RMS fitting residuals for each projector.

## Photometric Evaluation

The photometric evaluation images are stored in:

```text
results/photometric/
```

These images include single-projector captures, unblended two-projector capture, and blended two-projector capture. They support the reported comparison of overlap luminance before and after applying the proposed blending weights.

## Hardware-Dependent Notes

The following steps are hardware-dependent and may not be exactly reproducible without a similar projector-camera setup:

* projector display control
* camera capture timing
* projector mask acquisition
* live AprilTag image acquisition
* physical overlap-region formation
* final visual inspection on a projection surface

Nevertheless, the provided data and scripts allow users to reproduce the main computational workflow from exported calibration data to corrected playback frames.

## Relationship to the Manuscript

This reproducibility guide is associated with the manuscript:

```text
SeamlessCast: A Modular Calibration-to-Playback Framework for Scalable Multi-Projector Displays
```

submitted to:

```text
The Visual Computer
```

The repository and data support the manuscript's reported results on geometric calibration accuracy, repeatability, polynomial-degree behavior, blending evaluation, data export, runtime behavior, and playback validation.

## Citation

If you use the SeamlessCast source code, data, or examples in academic work, please cite the associated manuscript and this repository.

Citation information is provided in:

```text
CITATION.cff
README.md
```
