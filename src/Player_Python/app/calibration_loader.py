import json
from pathlib import Path

from app.models import CalibrationData, ProjectorInfo


def load_calibration_folder(folder_path: str) -> CalibrationData:
    folder = Path(folder_path)
    metadata_file = folder / "calibration_metadata.json"

    if not metadata_file.exists():
        raise FileNotFoundError(
            f"calibration_metadata.json was not found in:\n{folder}"
        )

    with open(metadata_file, "r", encoding="utf-8") as f:
        metadata = json.load(f)

    projectors = []

    for item in metadata.get("projectors", []):
        projector = ProjectorInfo(
            index=int(item.get("index", 0)),
            screen_id=int(item.get("screen_id", 0)),
            native_width=int(item.get("native_width", 0)),
            native_height=int(item.get("native_height", 0)),
            image_size=item.get("image_size", []),
            x_in_csv=item.get("xIn_csv", ""),
            y_in_csv=item.get("yIn_csv", ""),
            weight_csv=item.get("weight_csv", ""),
        )

        validate_projector_files(folder, projector)
        projectors.append(projector)

    return CalibrationData(
        folder=folder,
        version=str(metadata.get("version", "")),
        created_at=str(metadata.get("created_at", "")),
        working_size=metadata.get("working_size", []),
        content_scale=float(metadata.get("content_scale", 1.0)),
        content_offset=metadata.get("content_offset", [0, 0]),
        interpolation=str(metadata.get("interpolation", "")),
        out_of_bounds_value=float(metadata.get("out_of_bounds_value", 0)),
        num_projectors=int(metadata.get("num_projectors", len(projectors))),
        projectors=projectors,
    )


def validate_projector_files(folder: Path, projector: ProjectorInfo) -> None:
    required_files = [
        projector.x_in_csv,
        projector.y_in_csv,
        projector.weight_csv,
    ]

    for file_name in required_files:
        if not file_name:
            raise ValueError(
                f"Missing CSV filename for projector {projector.index}"
            )

        file_path = folder / file_name
        if not file_path.exists():
            raise FileNotFoundError(
                f"Required calibration file was not found:\n{file_path}"
            )