import threading
from pathlib import Path

from PySide6.QtCore import QFile, QTimer
from PySide6.QtUiTools import QUiLoader
from PySide6.QtWidgets import (
    QFileDialog,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QTableWidget,
    QTableWidgetItem,
    QTextEdit,
    QVBoxLayout,
)

from app.calibration_loader import load_calibration_folder
from app.csv_reader import load_projector_maps
from app.gl_video_widget import GLVideoWidget
from app.legacy_cv2_player import PlayerControl, play_video_from_calibration
from app.video_source import VideoSource
from app.warp_utils import create_uv_map


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()

        self.calibration_data = None
        self.video_source = VideoSource()
        self.test_uv_map = None

        self.loaded_video_path = None
        self.loaded_calibration_folder = None
        self.player_control = PlayerControl()

        self.timer = QTimer()
        self.timer.timeout.connect(self.update_video_frame)

        self.load_ui()
        self.setup_widgets()
        self.connect_signals()

    def load_ui(self):
        ui_path = Path(__file__).parent / "ui" / "main_window.ui"

        ui_file = QFile(str(ui_path))
        if not ui_file.open(QFile.OpenModeFlag.ReadOnly):
            raise RuntimeError(f"Could not open UI file:\n{ui_path}")

        loader = QUiLoader()
        loaded_window = loader.load(ui_file, self)
        ui_file.close()

        if loaded_window is None:
            raise RuntimeError(f"Could not load UI file:\n{ui_path}")

        self.setWindowTitle(loaded_window.windowTitle())
        self.resize(loaded_window.size())

        central_widget = loaded_window.takeCentralWidget()
        self.setCentralWidget(central_widget)

    def setup_widgets(self):
        self.load_calibration_button = self.findChild(
            QPushButton, "loadCalibrationButton"
        )
        self.load_video_button = self.findChild(
            QPushButton, "loadVideoButton"
        )
        self.play_button = self.findChild(
            QPushButton, "playButton"
        )
        self.pause_button = self.findChild(
            QPushButton, "pauseButton"
        )
        self.stop_button = self.findChild(
            QPushButton, "stopButton"
        )
        self.start_cv2_output_button = self.findChild(
            QPushButton, "startCv2OutputButton"
        )
        self.stop_cv2_output_button = self.findChild(
            QPushButton, "stopCv2OutputButton"
        )

        self.zoom_in_button = self.findChild(
            QPushButton, "zoomInButton"
        )
        self.zoom_out_button = self.findChild(
            QPushButton, "zoomOutButton"
        )
        self.left_button = self.findChild(
            QPushButton, "leftButton"
        )
        self.right_button = self.findChild(
            QPushButton, "rightButton"
        )
        self.up_button = self.findChild(
            QPushButton, "upButton"
        )
        self.down_button = self.findChild(
            QPushButton, "downButton"
        )
        self.reset_view_button = self.findChild(
            QPushButton, "resetViewButton"
        )

        self.info_box = self.findChild(QTextEdit, "infoBox")
        self.projector_table = self.findChild(
            QTableWidget, "projectorTable"
        )

        self.projector_table.setColumnCount(7)
        self.projector_table.setHorizontalHeaderLabels(
            [
                "Index",
                "Screen ID",
                "Native Width",
                "Native Height",
                "Image Size",
                "xIn CSV",
                "Weight CSV",
            ]
        )

        self.video_widget = GLVideoWidget()
        self.video_widget.setMinimumHeight(192)

        preview_layout = self.findChild(QVBoxLayout, "previewLayout")
        preview_layout.addWidget(self.video_widget)

    def connect_signals(self):
        self.load_calibration_button.clicked.connect(
            self.load_calibration
        )
        self.load_video_button.clicked.connect(
            self.load_video
        )
        self.play_button.clicked.connect(
            self.play_video
        )
        self.pause_button.clicked.connect(
            self.pause_video
        )
        self.stop_button.clicked.connect(
            self.stop_video
        )

        self.start_cv2_output_button.clicked.connect(
            self.start_cv2_projector_output
        )
        self.stop_cv2_output_button.clicked.connect(
            self.stop_cv2_output
        )

        self.zoom_in_button.clicked.connect(self.zoom_in)
        self.zoom_out_button.clicked.connect(self.zoom_out)
        self.left_button.clicked.connect(
            lambda: self.move_content(-20, 0)
        )
        self.right_button.clicked.connect(
            lambda: self.move_content(20, 0)
        )
        self.up_button.clicked.connect(
            lambda: self.move_content(0, -20)
        )
        self.down_button.clicked.connect(
            lambda: self.move_content(0, 20)
        )
        self.reset_view_button.clicked.connect(self.reset_view)

    def load_calibration(self):
        folder_path = QFileDialog.getExistingDirectory(
            self,
            "Select MATLAB Player Calibration Folder",
            "",
        )

        if not folder_path:
            return

        try:
            self.calibration_data = load_calibration_folder(folder_path)
        except Exception as exc:
            QMessageBox.critical(
                self,
                "Calibration Load Error",
                str(exc),
            )
            return

        self.loaded_calibration_folder = folder_path
        self.update_calibration_view()

    def load_video(self):
        file_path, _ = QFileDialog.getOpenFileName(
            self,
            "Select Video File",
            "",
            "Video Files (*.mp4 *.avi *.mov *.mkv);;All Files (*.*)",
        )

        if not file_path:
            return

        try:
            self.video_source.open(file_path)
        except Exception as exc:
            QMessageBox.critical(
                self,
                "Video Load Error",
                str(exc),
            )
            return

        self.loaded_video_path = file_path
        self.statusBar().showMessage(f"Video loaded: {file_path}")
        self.show_first_video_frame()

    def play_video(self):
        if self.video_source.cap is None:
            QMessageBox.warning(
                self,
                "No Video",
                "Please load a video first.",
            )
            return

        interval_ms = int(1000 / self.video_source.fps)
        self.timer.start(interval_ms)

    def pause_video(self):
        self.timer.stop()

    def stop_video(self):
        self.timer.stop()

        if self.video_source.cap is not None:
            self.video_source.cap.set(1, 0)
            self.video_source.current_frame_index = 0
            self.show_first_video_frame()

    def show_first_video_frame(self):
        if self.video_source.cap is None:
            return

        self.video_source.cap.set(1, 0)
        frame_rgb = self.video_source.read_frame()

        if frame_rgb is not None:
            self.video_widget.update_frame(frame_rgb)

    def update_video_frame(self):
        frame_rgb = self.video_source.read_frame()

        if frame_rgb is not None:
            self.video_widget.update_frame(frame_rgb)

    def update_calibration_view(self):
        calib = self.calibration_data

        info_text = (
            f"Folder: {calib.folder}\n"
            f"Version: {calib.version}\n"
            f"Created at: {calib.created_at}\n"
            f"Working size: {calib.working_size}\n"
            f"Content scale: {calib.content_scale}\n"
            f"Content offset: {calib.content_offset}\n"
            f"Interpolation: {calib.interpolation}\n"
            f"Out-of-bounds value: {calib.out_of_bounds_value}\n"
            f"Number of projectors: {calib.num_projectors}"
        )

        self.info_box.setPlainText(info_text)

        self.projector_table.setRowCount(len(calib.projectors))

        for row, projector in enumerate(calib.projectors):
            values = [
                projector.index,
                projector.screen_id,
                projector.native_width,
                projector.native_height,
                str(projector.image_size),
                projector.x_in_csv,
                projector.weight_csv,
            ]

            for col, value in enumerate(values):
                self.projector_table.setItem(
                    row,
                    col,
                    QTableWidgetItem(str(value)),
                )

        self.projector_table.resizeColumnsToContents()

        try:
            first_projector = calib.projectors[0]
            x_in, y_in, weight = load_projector_maps(
                calib.folder,
                first_projector,
            )

            self.test_uv_map = create_uv_map(x_in, y_in)

            self.statusBar().showMessage(
                f"Loaded first projector maps: "
                f"xIn={x_in.shape}, yIn={y_in.shape}, "
                f"weight={weight.shape}"
            )

        except Exception as exc:
            QMessageBox.warning(
                self,
                "CSV Load Warning",
                str(exc),
            )

    def start_cv2_projector_output(self):
        if not self.loaded_video_path:
            QMessageBox.warning(
                self,
                "No Video",
                "Please load a video first.",
            )
            return

        if not self.loaded_calibration_folder:
            QMessageBox.warning(
                self,
                "No Calibration",
                "Please load a calibration folder first.",
            )
            return

        self.player_control = PlayerControl()

        thread = threading.Thread(
            target=play_video_from_calibration,
            args=(
                self.loaded_video_path,
                self.loaded_calibration_folder,
            ),
            kwargs={
                "frame_step": 1,
                "content_scale": 0.85,
                "content_offset": (-100, 350),
                "control": self.player_control,
            },
            daemon=True,
        )

        thread.start()

    def zoom_in(self):
        scale, _, _ = self.player_control.get_state()
        self.player_control.set_scale(scale * 1.05)

    def zoom_out(self):
        scale, _, _ = self.player_control.get_state()
        self.player_control.set_scale(scale / 1.05)

    def move_content(self, dx, dy):
        self.player_control.move(dx, dy)

    def reset_view(self):
        self.player_control.reset_view()

    def stop_cv2_output(self):
        self.player_control.stop()