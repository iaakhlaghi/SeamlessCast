import moderngl
import numpy as np

from PySide6.QtOpenGLWidgets import QOpenGLWidget


class GLVideoWidget(QOpenGLWidget):
    def __init__(self, parent=None):
        super().__init__(parent)

        self.pending_uv_map = None
        self.ctx = None
        self.qt_framebuffer = None
        self.program = None
        self.vao = None
        self.vbo = None

        self.video_texture = None
        self.uv_texture = None

        self.frame_width = 0
        self.frame_height = 0
        self.uv_width = 0
        self.uv_height = 0

        self.use_uv_map = False
        self.swap_red_blue = False

    def initializeGL(self):
        self.ctx = moderngl.create_context()

        vertex_shader = """
        #version 330

        in vec2 in_position;
        in vec2 in_texcoord;

        out vec2 v_texcoord;

        void main()
        {
            gl_Position = vec4(in_position, 0.0, 1.0);
            v_texcoord = in_texcoord;
        }
        """

        fragment_shader = """
        #version 330

        uniform sampler2D video_texture;
        uniform sampler2D uv_texture;
        uniform int use_uv_map;
        uniform int swap_red_blue;

        in vec2 v_texcoord;

        out vec4 fragColor;

        void main()
        {
            vec2 sample_uv = v_texcoord;

            if (use_uv_map == 1)
            {
                sample_uv = v_texcoord;
            }

            if (
                sample_uv.x < 0.0 || sample_uv.x > 1.0 ||
                sample_uv.y < 0.0 || sample_uv.y > 1.0
            )
            {
                fragColor = vec4(0.0, 0.0, 0.0, 1.0);
                return;
            }

            vec4 color = texture(video_texture, sample_uv);

            if (swap_red_blue == 1)
            {
                color = color.bgra;
            }

            fragColor = color;
        }
        """

        self.program = self.ctx.program(
            vertex_shader=vertex_shader,
            fragment_shader=fragment_shader,
        )

        initial_vertices = np.array(
            [
                -1.0, -1.0, 0.0, 1.0,
                 1.0, -1.0, 1.0, 1.0,
                -1.0,  1.0, 0.0, 0.0,

                 1.0, -1.0, 1.0, 1.0,
                 1.0,  1.0, 1.0, 0.0,
                -1.0,  1.0, 0.0, 0.0,
            ],
            dtype="f4",
        )

        self.vbo = self.ctx.buffer(initial_vertices.tobytes())

        self.vao = self.ctx.vertex_array(
            self.program,
            [
                (
                    self.vbo,
                    "2f 2f",
                    "in_position",
                    "in_texcoord",
                )
            ],
        )

        self.program["video_texture"].value = 0
        self.program["uv_texture"].value = 1
        self.program["use_uv_map"].value = 0
        self.program["swap_red_blue"].value = 0
        if self.pending_uv_map is not None:
            self.set_uv_map(self.pending_uv_map)
            self.pending_uv_map = None

    def resizeGL(self, width, height):
        if self.ctx is not None:
            self.ctx.viewport = (0, 0, width, height)
            self.update_geometry()

    def paintGL(self):
        if self.ctx is None:
            return

        self.qt_framebuffer = self.ctx.detect_framebuffer(
            glo=self.defaultFramebufferObject()
        )
        self.qt_framebuffer.use()

        self.ctx.clear(0.0, 0.0, 0.0)

        if self.video_texture is not None and self.vao is not None:
            self.video_texture.use(0)

            self.program["swap_red_blue"].value = 1 if self.swap_red_blue else 0

            self.vao.render(moderngl.TRIANGLES)

    def update_frame(self, frame_rgb):
        if frame_rgb is None:
            return

        if self.ctx is None:
            return

        frame_rgb = np.ascontiguousarray(frame_rgb)

        height, width, _ = frame_rgb.shape

        if (
            self.video_texture is None
            or width != self.frame_width
            or height != self.frame_height
        ):
            if self.video_texture is not None:
                self.video_texture.release()

            self.video_texture = self.ctx.texture(
                (width, height),
                3,
                frame_rgb.tobytes(),
            )

            self.video_texture.filter = (
                moderngl.LINEAR,
                moderngl.LINEAR,
            )

            self.video_texture.repeat_x = False
            self.video_texture.repeat_y = False

            self.frame_width = width
            self.frame_height = height

            self.update_geometry()
        else:
            self.video_texture.write(frame_rgb.tobytes())

        self.update()

    def set_uv_map(self, uv_map):
        if uv_map is None:
            return

        uv_map = np.ascontiguousarray(
            uv_map.astype(np.float32)
        )

        if self.ctx is None:
            self.pending_uv_map = uv_map
            return

        height, width, channels = uv_map.shape

        if channels != 2:
            raise ValueError(
                "UV map must have shape (height, width, 2)."
            )

        if self.uv_texture is not None:
            self.uv_texture.release()

        self.uv_texture = self.ctx.texture(
            (width, height),
            2,
            uv_map.tobytes(),
            dtype="f4",
        )

        self.uv_texture.filter = (
            moderngl.LINEAR,
            moderngl.LINEAR,
        )

        self.uv_texture.repeat_x = False
        self.uv_texture.repeat_y = False

        self.uv_width = width
        self.uv_height = height

        self.use_uv_map = True

        self.update_geometry()
        self.update()

    def set_use_uv_map(self, enabled: bool):
        self.use_uv_map = enabled
        self.update_geometry()
        self.update()

    def set_swap_red_blue(self, enabled: bool):
        self.swap_red_blue = enabled
        self.update()
    
    def update_geometry(self):
        if self.vbo is None:
            return

        widget_width = max(1, self.width())
        widget_height = max(1, self.height())
        widget_aspect = widget_width / widget_height

        if self.use_uv_map and self.uv_width > 0 and self.uv_height > 0:
            content_aspect = self.uv_width / self.uv_height
        elif self.frame_width > 0 and self.frame_height > 0:
            content_aspect = self.frame_width / self.frame_height
        else:
            content_aspect = widget_aspect

        if content_aspect > widget_aspect:
            scale_x = 1.0
            scale_y = widget_aspect / content_aspect
        else:
            scale_x = content_aspect / widget_aspect
            scale_y = 1.0

        vertices = np.array(
            [
                -scale_x, -scale_y, 0.0, 1.0,
                 scale_x, -scale_y, 1.0, 1.0,
                -scale_x,  scale_y, 0.0, 0.0,

                 scale_x, -scale_y, 1.0, 1.0,
                 scale_x,  scale_y, 1.0, 0.0,
                -scale_x,  scale_y, 0.0, 0.0,
            ],
            dtype="f4",
        )

        self.vbo.write(vertices.tobytes())