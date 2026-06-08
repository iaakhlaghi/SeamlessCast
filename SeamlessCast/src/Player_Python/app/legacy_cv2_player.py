import json
import math
import os
import time

import cv2
import numpy as np
from screeninfo import get_monitors
from dataclasses import dataclass, field
import threading

@dataclass
class PlayerControl:
    content_scale: float = 0.85
    offset_x: int = -100
    offset_y: int = 350
    stop_requested: bool = False
    _lock: threading.Lock = field(default_factory=threading.Lock)

    def get_state(self):
        with self._lock:
            return (
                self.content_scale,
                [self.offset_x, self.offset_y],
                self.stop_requested,
            )

    def set_scale(self, value):
        with self._lock:
            self.content_scale = max(0.05, float(value))

    def move(self, dx, dy):
        with self._lock:
            self.offset_x += int(dx)
            self.offset_y += int(dy)

    def reset_view(self):
        with self._lock:
            self.content_scale = 0.85
            self.offset_x = -100
            self.offset_y = 350

    def stop(self):
        with self._lock:
            self.stop_requested = True

def load_player_calibration_data(calibration_dir):
    metadata_file = os.path.join(calibration_dir, "calibration_metadata.json")

    if not os.path.isfile(metadata_file):
        raise FileNotFoundError(
            f"Calibration metadata file was not found: {metadata_file}"
        )

    with open(metadata_file, "r", encoding="utf-8") as f:
        metadata = json.load(f)

    calib = dict(metadata)
    calib["warpLUT"] = []
    calib["weightMaps"] = []

    for projector in metadata["projectors"]:
        x_file = os.path.join(calibration_dir, projector["xIn_csv"])
        y_file = os.path.join(calibration_dir, projector["yIn_csv"])
        w_file = os.path.join(calibration_dir, projector["weight_csv"])

        x_in = np.loadtxt(x_file, delimiter=",").astype(np.float32)
        y_in = np.loadtxt(y_file, delimiter=",").astype(np.float32)

        weight_map = np.loadtxt(w_file, delimiter=",").astype(np.float32)

        if weight_map.max() > 1.5:
            weight_map = weight_map / 255.0

        weight_map = np.clip(weight_map, 0.0, 1.0)
        weight_map_uint8 = np.round(weight_map * 255.0).astype(np.uint8)

        if weight_map_uint8.ndim == 2:
            weight_map_uint8 = cv2.merge(
                [weight_map_uint8, weight_map_uint8, weight_map_uint8]
            )

        map_x = x_in - 1.0
        map_y = y_in - 1.0

        map1, map2 = cv2.convertMaps(
            map_x,
            map_y,
            cv2.CV_16SC2,
        )

        calib["warpLUT"].append(
            {
                "map1": map1,
                "map2": map2,
            }
        )

        calib["weightMaps"].append(weight_map_uint8)

    return calib


def play_video_from_calibration(
    video_file,
    calibration_dir,
    frame_step=1,
    content_scale=0.85,
    content_offset=(-100, 350),
    control=None,
):

    cv2.destroyAllWindows()
    cv2.setUseOptimized(True)

    calib = load_player_calibration_data(calibration_dir)

    video_reader = cv2.VideoCapture(video_file)

    if not video_reader.isOpened():
        raise FileNotFoundError(f"Could not open video file: {video_file}")

    num_projectors = calib["num_projectors"]
    window_names = [None] * num_projectors

    prepare_plan = None
    is_first_displayed_frame = True
    frame_counter = 0

    last_scale = None
    last_offset = None

    while True:
        if control is not None:
            current_scale, current_offset, stop_requested = control.get_state()

        if stop_requested:
            break

        if current_scale != last_scale or current_offset != last_offset:
            content_scale = current_scale
            content_offset = current_offset
            prepare_plan = None
            last_scale = current_scale
            last_offset = list(current_offset)
        
        ret, frame_raw = video_reader.read()

        if not ret:
            break

        frame_counter += 1

        if ((frame_counter - 1) % frame_step) != 0:
            continue

        if prepare_plan is None:
            prepare_plan = build_output_prepare_plan(
                frame_raw.shape,
                calib["working_size"],
                content_scale,
                content_offset,
            )

        frame_prepared = prepare_output_image_fast(
            frame_raw,
            prepare_plan,
        )

        for i in range(num_projectors):
            frame_warped = apply_warp_lookup(
                frame_prepared,
                calib["warpLUT"][i],
            )

            frame_weighted = apply_weight_map_uint8(
                frame_warped,
                calib["weightMaps"][i],
            )

            screen_index = calib["projectors"][i]["screen_id"]

            if is_first_displayed_frame:
                window_names[i] = initialize_projector_video_window(
                    frame_weighted,
                    screen_index,
                    i,
                )
            else:
                cv2.imshow(window_names[i], frame_weighted)

        is_first_displayed_frame = False

        key = cv2.waitKey(1) & 0xFF

        if key == ord("q") or key == 27:
            break

    video_reader.release()
    cv2.destroyAllWindows()


def build_output_prepare_plan(
    input_shape,
    target_size,
    content_scale=1.0,
    content_offset=(0, 0),
):
    target_height = int(target_size[0])
    target_width = int(target_size[1])

    img_height = int(input_shape[0])
    img_width = int(input_shape[1])
    num_channels = int(input_shape[2])

    offset_x = matlab_round(content_offset[0])
    offset_y = matlab_round(content_offset[1])

    base_scale = min(
        target_height / img_height,
        target_width / img_width,
    )

    scale = base_scale * content_scale

    new_height = max(1, matlab_round(img_height * scale))
    new_width = max(1, matlab_round(img_width * scale))

    center_row_start = math.floor((target_height - new_height) / 2)
    center_col_start = math.floor((target_width - new_width) / 2)

    target_row_start = center_row_start + offset_y
    target_col_start = center_col_start + offset_x

    target_row_end = target_row_start + new_height
    target_col_end = target_col_start + new_width

    visible_target_row_start = max(0, target_row_start)
    visible_target_col_start = max(0, target_col_start)

    visible_target_row_end = min(target_height, target_row_end)
    visible_target_col_end = min(target_width, target_col_end)

    is_visible = not (
        visible_target_row_start >= visible_target_row_end
        or visible_target_col_start >= visible_target_col_end
    )

    if is_visible:
        source_row_start = visible_target_row_start - target_row_start
        source_col_start = visible_target_col_start - target_col_start

        source_row_end = source_row_start + (
            visible_target_row_end - visible_target_row_start
        )
        source_col_end = source_col_start + (
            visible_target_col_end - visible_target_col_start
        )
    else:
        source_row_start = source_row_end = 0
        source_col_start = source_col_end = 0

    interpolation = cv2.INTER_AREA if scale < 1.0 else cv2.INTER_LINEAR

    canvas = np.zeros(
        (target_height, target_width, num_channels),
        dtype=np.uint8,
    )

    return {
        "new_height": new_height,
        "new_width": new_width,
        "interpolation": interpolation,
        "is_visible": is_visible,
        "visible_target_row_start": visible_target_row_start,
        "visible_target_row_end": visible_target_row_end,
        "visible_target_col_start": visible_target_col_start,
        "visible_target_col_end": visible_target_col_end,
        "source_row_start": source_row_start,
        "source_row_end": source_row_end,
        "source_col_start": source_col_start,
        "source_col_end": source_col_end,
        "canvas": canvas,
    }


def prepare_output_image_fast(img, plan):
    resized_img = cv2.resize(
        img,
        (plan["new_width"], plan["new_height"]),
        interpolation=plan["interpolation"],
    )

    canvas = plan["canvas"]
    canvas.fill(0)

    if not plan["is_visible"]:
        return canvas

    vrs = plan["visible_target_row_start"]
    vre = plan["visible_target_row_end"]
    vcs = plan["visible_target_col_start"]
    vce = plan["visible_target_col_end"]

    srs = plan["source_row_start"]
    sre = plan["source_row_end"]
    scs = plan["source_col_start"]
    sce = plan["source_col_end"]

    canvas[vrs:vre, vcs:vce, :] = resized_img[srs:sre, scs:sce, :]

    return canvas


def apply_warp_lookup(frame, lut):
    return cv2.remap(
        frame,
        lut["map1"],
        lut["map2"],
        interpolation=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=0,
    )


def apply_weight_map_uint8(frame_uint8, weight_map_uint8):
    return cv2.multiply(
        frame_uint8,
        weight_map_uint8,
        scale=1.0 / 255.0,
        dtype=cv2.CV_8U,
    )


def initialize_projector_video_window(img, screen_index, projector_number):
    monitors = get_monitors()

    if screen_index < 1 or screen_index > len(monitors):
        screen_index = 1

    monitor = monitors[screen_index - 1]

    window_name = f"Projector Video Display {projector_number + 1}"

    cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)
    cv2.moveWindow(window_name, monitor.x, monitor.y)
    cv2.resizeWindow(window_name, monitor.width, monitor.height)

    cv2.imshow(window_name, img)
    cv2.waitKey(100)

    cv2.setWindowProperty(
        window_name,
        cv2.WND_PROP_FULLSCREEN,
        cv2.WINDOW_FULLSCREEN,
    )

    cv2.imshow(window_name, img)
    cv2.waitKey(1)

    return window_name


def matlab_round(x):
    x = float(x)

    if x >= 0:
        return int(math.floor(x + 0.5))

    return int(math.ceil(x - 0.5))