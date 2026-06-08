import moderngl

from PySide6.QtOpenGL import QOpenGLWindow


class ProjectorGLWindow(QOpenGLWindow):
    def __init__(self):
        super().__init__()

        self.ctx = None

        self.setTitle("IAA_Player - Projector OpenGL Output")
        self.resize(800, 600)

    def initializeGL(self):
        self.ctx = moderngl.create_context()
        print("Projector OpenGL initialized")

    def resizeGL(self, width, height):
        if self.ctx is not None:
            self.ctx.viewport = (0, 0, width, height)

    def paintGL(self):
        if self.ctx is None:
            return

        self.ctx.clear(0.0, 0.2, 0.8)