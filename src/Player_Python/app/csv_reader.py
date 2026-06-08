from pathlib import Path

import numpy as np


def read_csv_matrix(file_path: str | Path) -> np.ndarray:
    file_path = Path(file_path)

    if not file_path.exists():
        raise FileNotFoundError(f"CSV file not found:\n{file_path}")

    matrix = np.loadtxt(file_path, delimiter=",", dtype=np.float32)

    if matrix.ndim != 2:
        raise ValueError(f"CSV file is not a 2D matrix:\n{file_path}")

    return matrix


def load_projector_maps(calibration_folder: str | Path, projector):
    calibration_folder = Path(calibration_folder)

    x_in = read_csv_matrix(calibration_folder / projector.x_in_csv)
    y_in = read_csv_matrix(calibration_folder / projector.y_in_csv)
    weight = read_csv_matrix(calibration_folder / projector.weight_csv)

    if x_in.shape != y_in.shape:
        raise ValueError("xIn and yIn shapes are different.")

    if x_in.shape != weight.shape:
        raise ValueError("xIn/yIn and weight shapes are different.")

    return x_in, y_in, weight