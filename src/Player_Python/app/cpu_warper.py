import cv2
import numpy as np


class CPUWarper:
    def __init__(self):
        self.map_x = None
        self.map_y = None
        self.weight = None

    def set_maps(self, x_in, y_in, weight=None):
        self.map_x = (x_in.astype(np.float32) - 1.0)
        self.map_y = (y_in.astype(np.float32) - 1.0)

        self.weight = weight

    def warp_frame(self, frame_rgb):
        if self.map_x is None or self.map_y is None:
            return frame_rgb

        warped = cv2.remap(
            frame_rgb,
            self.map_x,
            self.map_y,
            interpolation=cv2.INTER_LINEAR,
            borderMode=cv2.BORDER_CONSTANT,
            borderValue=(0, 0, 0),
        )

        if self.weight is not None:
            w = self.weight.astype(np.float32)

            if w.ndim == 2:
                w = w[:, :, None]

            warped = (
                warped.astype(np.float32) * w
            ).astype(np.uint8)

        return warped