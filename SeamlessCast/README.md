# SeamlessCast

**SeamlessCast: A Modular Calibration-to-Playback Framework for Scalable Multi-Projector Displays**

SeamlessCast is a modular calibration-to-playback framework for scalable multi-projector displays. It connects projector-camera calibration, polynomial warping, distance-transform-based blending, calibration-data export, and calibrated image/video playback in a single reproducible workflow.

The framework was developed for practical multi-projector visualization scenarios, including planar displays, curved projection surfaces, dome-oriented environments, educational projection systems, and custom immersive-display installations.

This repository accompanies the manuscript:

```text
SeamlessCast: A Modular Calibration-to-Playback Framework for Scalable Multi-Projector Displays
```

submitted to:

```text
The Visual Computer
```

---

## Main Features

SeamlessCast provides:

- marker-guided projector-camera calibration using fiducial correspondences
- polynomial projector-to-reference geometric mapping
- reusable inverse lookup-map generation
- distance-transform-based blending-weight generation
- transparent JSON/CSV calibration-data export
- MATLAB-based calibration modules
- Python-based calibrated playback module
- representative controlled two-projector calibration data
- repeatability metrics from five independent calibration runs
- photometric before/after blending examples
- documentation for calibration, playback, data, and reproducibility

The key design objective is to separate calibration from playback. Calibration is performed once, and the exported lookup maps and blending weights are then reused by the player for still-image or video projection.

---

## Repository Structure

A typical structure of this repository is:

```text
SeamlessCast/
├── README.md
├── LICENSE
├── CITATION.cff
├── requirements.txt
├── environment.yml
├── MATLAB_REQUIREMENTS.md
├── DATA_DESCRIPTION.md
├── REPRODUCIBILITY.md
├── src/
│   ├── ProjectorsCalibration_MATLAB/
│   └── Player_Python/
├── data/
│   └── player_calibration/
├── results/
│   ├── calibration_metrics/
│   └── photometric/
├── examples/
└── docs/
    ├── calibration_workflow.md
    └── playback_workflow.md
```

The exact filenames and subfolder names may vary slightly between releases. The main calibration and playback workflows are documented in the `docs/` folder.

---

## Calibration-to-Playback Workflow

The SeamlessCast workflow consists of two main stages.

### 1. Calibration Stage

The calibration stage is implemented mainly in MATLAB. It performs:

```text
projector mask acquisition
fiducial-marker detection or correspondence processing
projector-to-reference mapping estimation
polynomial geometric calibration
inverse lookup-map generation
blending-weight generation
JSON/CSV calibration-data export
```

The calibration workflow is described in:

```text
docs/calibration_workflow.md
```

MATLAB requirements are described in:

```text
MATLAB_REQUIREMENTS.md
```

### 2. Playback Stage

The playback stage is implemented in Python. It loads the exported calibration data and generates corrected projector-specific frames.

The playback stage performs:

```text
loading calibration metadata
loading inverse lookup maps
loading blending-weight maps
preparing the input frame
lookup-based geometric warping
projector-specific blending
image or video playback
```

The playback workflow is described in:

```text
docs/playback_workflow.md
```

---

## Data Included in This Repository

This repository includes representative data from the controlled two-projector setup reported in the manuscript.

The data include:

```text
calibration metadata
projector-specific inverse lookup maps
projector-specific blending-weight maps
calibration metrics from repeated runs
photometric before/after blending images
example input and output images
optional MATLAB intermediate files
optional video playback examples
```

The data description is available in:

```text
DATA_DESCRIPTION.md
```

The reproducibility guide is available in:

```text
REPRODUCIBILITY.md
```

---

## Installation

The repository contains both MATLAB and Python components.

---

### Python Installation Using pip

Create and activate a virtual environment:

```bash
python -m venv seamlesscast_env
```

On Windows:

```bash
seamlesscast_env\Scripts\activate
```

On Linux or macOS:

```bash
source seamlesscast_env/bin/activate
```

Install dependencies:

```bash
pip install -r requirements.txt
```

---

### Python Installation Using conda

Create the conda environment:

```bash
conda env create -f environment.yml
```

Activate it:

```bash
conda activate seamlesscast
```

---

## Python Dependencies

Typical Python dependencies include:

```text
numpy
opencv-python
pandas
PySide6
moderngl
imageio
imageio-ffmpeg
screeninfo
scipy
matplotlib
```

The complete list is provided in:

```text
requirements.txt
environment.yml
```

---

## MATLAB Requirements

The MATLAB calibration modules were developed and tested using recent MATLAB releases.

Recommended MATLAB toolboxes:

```text
Image Processing Toolbox
Computer Vision Toolbox
```

More information is provided in:

```text
MATLAB_REQUIREMENTS.md
```

Some acquisition-related operations depend on the local projector-camera hardware configuration. However, the repository includes exported calibration data so that users can reproduce and inspect the computational playback stage without the original hardware.

---

## Quick Start

### 1. Inspect the Included Calibration Data

The main exported calibration files are typically stored in:

```text
data/player_calibration/
```

Typical files include:

```text
calibration_metadata.json
projector_01_xIn.csv
projector_01_yIn.csv
projector_01_weight.csv
projector_02_xIn.csv
projector_02_yIn.csv
projector_02_weight.csv
```

These files are generated by the MATLAB calibration module and used by the Python playback module.

---

### 2. Run or Inspect the Python Player

The Python player is located in:

```text
src/Player_Python/
```

Depending on the repository version, the playback script or graphical interface may be launched from this folder.

Before running the player, make sure that:

```text
the Python environment is activated
the dependencies are installed
the calibration metadata file exists
the lookup maps and weight maps are available
the example input image or video exists
```

---

### 3. Reproduce Playback from Exported Data

A typical playback reproduction uses:

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

The expected outputs are projector-specific corrected frames, such as:

```text
examples/projector_01_output.png
examples/projector_02_output.png
```

These frames are geometrically pre-warped and weighted using the exported calibration maps.

---

## Reproducibility

The repository supports reproducibility at two levels.

### Data-Level Reproducibility

Users can inspect:

```text
exported calibration metadata
lookup maps
blending-weight maps
calibration metrics
photometric evaluation images
example output images
```

This level does not require the original projector-camera hardware.

### Processing-Level Reproducibility

Users can run or inspect the MATLAB and Python modules to reproduce the main computational steps:

```text
loading calibration metadata
reading lookup maps
reading blending-weight maps
applying lookup-based warping
applying projector-specific blending weights
generating corrected projector-specific frames
checking calibration metrics
reviewing photometric before/after blending examples
```

Full live acquisition requires a local projector-camera setup and may not be exactly reproducible without similar hardware.

For details, see:

```text
REPRODUCIBILITY.md
```

---

## Results Included

The repository includes representative result files supporting the manuscript.

### Calibration Metrics

Calibration metrics from repeated runs are typically stored in:

```text
results/calibration_metrics/
```

These files support the repeatability analysis reported in the manuscript.

### Photometric Evaluation

Photometric evaluation images are typically stored in:

```text
results/photometric/
```

These images support the reported comparison between before-blending and after-blending overlap behavior.

---

## Code and Data Availability

The complete SeamlessCast source code, representative calibration data, exported JSON/CSV calibration files, lookup maps, blending-weight maps, documentation, and example outputs are made publicly available through this repository.

Repository:

```text
https://github.com/iaakhlaghi/SeamlessCast
```

Archived version with DOI:

```text
https://doi.org/10.5281/zenodo.20595959
```

DOI:

```text
10.5281/zenodo.20595959
```

---

## Citation

If you use SeamlessCast, its source code, or its associated data in your research, please cite the associated manuscript and this repository.

Suggested citation:

```text
Ahadi Akhlaghi, I., Sarbishaei, G., and Sarafraz Yazdi, H.
SeamlessCast: A Modular Calibration-to-Playback Framework for Scalable Multi-Projector Displays.
Submitted to The Visual Computer, 2026.
```

The repository citation metadata are provided in:

```text
CITATION.cff
```

After publication, please cite the final published article in *The Visual Computer*.

---

## License

This project is released under the MIT License.

See:

```text
LICENSE
```

for details.

---

## Notes on Hardware-Dependent Execution

Some parts of SeamlessCast depend on the local display and acquisition setup, including:

```text
number of connected projectors
projector screen indices
operating-system display arrangement
camera model and exposure settings
projector-camera geometry
projection-surface geometry
visibility of fiducial markers
```

Users may need to adjust projector identifiers, display settings, camera settings, or file paths before running the full live calibration workflow.

Nevertheless, the included data allow users to inspect and reproduce the main computational workflow from exported calibration maps to corrected playback frames.

---

## Contact

For questions about the code, data, or reproducibility, please contact:

```text
Iman Ahadi Akhlaghi
Department of Electrical Engineering and Biomedical Engineering
Sadjad University
Mashhad, Iran
Email:
i_a_akhlaghi@sadjad.ac.ir
i.a.akhlaghi@gmail.com
```

---

## Related Manuscript

```text
SeamlessCast: A Modular Calibration-to-Playback Framework for Scalable Multi-Projector Displays
```

submitted to:

```text
The Visual Computer
```

This repository was prepared to support transparency, reproducibility, and reuse of the framework described in the manuscript.
