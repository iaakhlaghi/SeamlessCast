from PySide6.QtCore import Qt
from PySide6.QtGui import QImage, QPixmap
from PySide6.QtWidgets import QLabel, QMainWindow


class ProjectorWindow(QMainWindow):
    def __init__(self, title="Projector Output", parent=None):
        super().__init__(parent)

        self.setWindowTitle(title)
        self.resize(800, 600)

        self.label = QLabel("Projector Output")
        self.label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.label.setStyleSheet("background-color: black; color: white;")
        self.setCentralWidget(self.label)

    def set_uv_map(self, uv_map):
        pass

    def update_frame(self, frame_rgb):
        if frame_rgb is None:
            return

        height, width, channels = frame_rgb.shape
        bytes_per_line = channels * width

        image = QImage(
            frame_rgb.data,
            width,
            height,
            bytes_per_line,
            QImage.Format.Format_RGB888,
        ).copy()

        pixmap = QPixmap.fromImage(image)

        scaled_pixmap = pixmap.scaled(
            self.label.size(),
            Qt.AspectRatioMode.KeepAspectRatio,
            Qt.TransformationMode.SmoothTransformation,
        )

        self.label.setPixmap(scaled_pixmap)