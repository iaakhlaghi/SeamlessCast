# Playback Workflow

This document describes the playback workflow used in SeamlessCast.

SeamlessCast separates calibration from playback. The calibration stage generates reusable lookup maps, blending-weight maps, and metadata files. The playback stage loads these exported files and uses them to generate corrected projector-specific frames for still images or video content.

## Overview

The playback workflow consists of the following main stages:

1. load calibration metadata
2. load inverse lookup maps
3. load blending-weight maps
4. prepare the input frame
5. apply lookup-based geometric warping
6. apply projector-specific blending weights
7. generate projector-specific output frames
8. display or save the corrected frames

The playback module does not re-estimate calibration parameters. It only uses the data exported by the calibration stage.

## 1. Loading Calibration Metadata

The playback module first loads the calibration metadata file.

Typical file:

```text
data/player_calibration/calibration_metadata.json
```

This JSON file contains information such as:

```text
working-canvas size
number of projectors
projector identifiers
projector resolutions
lookup-map filenames
weight-map filenames
interpolation settings
content scale
content offset
```

The metadata file allows the player to find and load the correct calibration maps for each projector.

## 2. Loading Inverse Lookup Maps

For each projector, the playback module loads two dense inverse lookup maps:

```text
projector_XX_xIn.csv
projector_XX_yIn.csv
```

where `XX` denotes the projector index.

The horizontal lookup map specifies the input-frame x-coordinate sampled by each projector pixel.

The vertical lookup map specifies the input-frame y-coordinate sampled by each projector pixel.

These maps are generated once during calibration and reused during playback.

## 3. Loading Blending-Weight Maps

For each projector, the playback module loads a normalized blending-weight map:

```text
projector_XX_weight.csv
```

The weight map defines the spatial contribution of the corresponding projector.

In non-overlap regions, one projector usually has dominant contribution. In overlap regions, multiple projectors contribute according to their normalized weights.

The same spatial weight map is applied to the red, green, and blue channels.

## 4. Preparing the Input Frame

The input frame may be a still image or a video frame.

Before warping, the frame is prepared on the working canvas. This may include:

```text
resizing
cropping
padding
scaling
offset adjustment
color-format conversion
```

The working canvas is the coordinate system used by the exported calibration maps.

## 5. Lookup-Based Geometric Warping

For each projector, the player uses the inverse lookup maps to sample the prepared input frame.

For every output pixel of a projector, the lookup maps indicate which coordinate should be sampled from the input frame.

This operation produces a geometrically pre-warped projector frame.

The purpose of pre-warping is to compensate for projector placement, viewing geometry, keystone distortion, and projection-surface effects represented by the calibration model.

## 6. Applying Blending Weights

After geometric warping, each projector-specific frame is multiplied by the corresponding blending-weight map.

This step reduces visible seams and avoids excessive brightness accumulation in projector overlap regions.

The same weight map is applied to all color channels:

```text
corrected RGB output = warped RGB frame x projector weight map
```

## 7. Generating Projector-Specific Output Frames

For a system with multiple projectors, the playback module generates one corrected frame per projector.

For a two-projector setup, the output may be:

```text
projector_01_output.png
projector_02_output.png
```

For video playback, the same operation is repeated for each frame of the input video.

## 8. Displaying or Saving Output Frames

The corrected projector-specific frames can be:

```text
displayed directly on the assigned projector screens
saved as image files
used for video playback
used for debugging and visual inspection
```

The exact behavior depends on the playback script or graphical user interface used in the repository.

## Input Files Required for Playback

A typical playback example requires:

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

The exact filenames may differ depending on the repository version. Please refer to the main `README.md` file and the metadata JSON file for the current paths.

## Expected Output Files

A typical playback run may generate:

```text
examples/projector_01_output.png
examples/projector_02_output.png
examples/camera_captured_final_result.png
```

The first two files are the corrected frames sent to the two projectors. The final captured result, if available, shows the projected output as observed by the camera.

## Python Dependencies

The Python playback module requires the dependencies listed in:

```text
requirements.txt
environment.yml
```

Typical dependencies include:

```text
numpy
opencv-python
pandas
PySide6
moderngl
imageio
imageio-ffmpeg
screeninfo
```

## Hardware-Dependent Notes

Direct multi-projector display depends on the local hardware configuration, including:

```text
number of connected displays
operating-system display arrangement
projector screen indices
projector resolution
GPU/display-output configuration
camera viewpoint, if captured validation is performed
```

For this reason, users may need to adjust projector identifiers, screen indices, or display settings before live projection.

However, users can still reproduce the computational playback stage by loading the provided calibration data and saving the corrected projector-specific output frames.

## Relationship to Calibration

The playback workflow depends on the calibration workflow.

The calibration workflow generates the lookup maps, blending-weight maps, and metadata required by the playback module.

The calibration workflow is described separately in:

```text
docs/calibration_workflow.md
```

## Relationship to the Manuscript

This workflow corresponds to the playback and validation parts of the manuscript:

```text
SeamlessCast: A Modular Calibration-to-Playback Framework for Scalable Multi-Projector Displays
```

submitted to:

```text
The Visual Computer
```

The playback workflow supports the manuscript's claim that the exported calibration data can be directly used by an external player for calibrated image and video projection without repeating the calibration stage.
