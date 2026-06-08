import numpy as np


def create_uv_map(x_in, y_in):
    height, width = x_in.shape

    u = (x_in - 1.0) / max(1.0, (width - 1.0))
    v = (y_in - 1.0) / max(1.0, (height - 1.0))

    uv = np.dstack([u, v]).astype(np.float32)

    return uv