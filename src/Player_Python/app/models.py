from dataclasses import dataclass
from pathlib import Path


@dataclass
class ProjectorInfo:
    index: int
    screen_id: int
    native_width: int
    native_height: int
    image_size: list
    x_in_csv: str
    y_in_csv: str
    weight_csv: str


@dataclass
class CalibrationData:
    folder: Path
    version: str
    created_at: str
    working_size: list
    content_scale: float
    content_offset: list
    interpolation: str
    out_of_bounds_value: float
    num_projectors: int
    projectors: list[ProjectorInfo]