import cv2


class VideoSource:
    def __init__(self):
        self.cap = None
        self.file_path = None
        self.fps = 30.0
        self.frame_count = 0
        self.current_frame_index = 0

    def open(self, file_path: str) -> None:
        self.release()

        self.cap = cv2.VideoCapture(file_path)

        if not self.cap.isOpened():
            raise RuntimeError(f"Could not open video file:\n{file_path}")

        self.file_path = file_path
        self.fps = self.cap.get(cv2.CAP_PROP_FPS)

        if not self.fps or self.fps <= 1:
            self.fps = 30.0

        self.frame_count = int(self.cap.get(cv2.CAP_PROP_FRAME_COUNT))
        self.current_frame_index = 0

    def read_frame(self):
        if self.cap is None:
            return None

        ok, frame_bgr = self.cap.read()

        if not ok:
            self.current_frame_index = 0
            self.cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
            ok, frame_bgr = self.cap.read()

            if not ok:
                return None

        self.current_frame_index = int(self.cap.get(cv2.CAP_PROP_POS_FRAMES))

        frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        return frame_rgb

    def release(self) -> None:
        if self.cap is not None:
            self.cap.release()

        self.cap = None
        self.file_path = None
        self.frame_count = 0
        self.current_frame_index = 0