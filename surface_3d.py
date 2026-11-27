from manimlib import *
from manimlib.mobject.mobject import Group
import numpy as np

class Surface3DScene(ThreeDScene):
    def construct(self):
        # Title
        title = Text("Permukaan 3D: z = sin(x) * cos(y)", font_size=48)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait(0.5)

        # 3D Axes
        axes = ThreeDAxes(
            x_range=[-3, 3, 1],
            y_range=[-3, 3, 1],
            z_range=[-1.5, 1.5, 0.5],
            width=10,
            height=7,
            depth=5,
        )

        # Axis labels
        axes_labels = VGroup(
            Text("x").next_to(axes.x_axis.get_right(), RIGHT).scale(0.7),
            Text("y").next_to(axes.y_axis.get_top(), UP).scale(0.7),
            Text("z").next_to(axes.z_axis.get_top(), OUT).scale(0.7)
        )

        # Surface: z = sin(x) * cos(y)
        surface = ParametricSurface(
            lambda u, v: axes.c2p(u, v, np.sin(u) * np.cos(v)),
            u_range=[-3, 3],
            v_range=[-3, 3],
            resolution=(40, 40),
            color=BLUE,
            opacity=0.8,
        )

        # Wireframe version for reference
        wireframe = ParametricSurface(
            lambda u, v: axes.c2p(u, v, np.sin(u) * np.cos(v)),
            u_range=[-3, 3],
            v_range=[-3, 3],
            resolution=(20, 20),
            color=WHITE,
            opacity=0.1,
        )

        # Show axes first
        self.play(ShowCreation(axes), Write(axes_labels))
        self.wait(0.5)

        # Animate camera to good viewing angle
        self.play(self.frame.animate.reorient(
            theta_degrees=-40,
            phi_degrees=65,
        ), run_time=2)

        # Create surface
        self.play(ShowCreation(surface), run_time=3)
        self.wait(1)

        # Add wireframe
        self.play(FadeIn(wireframe))
        self.wait(1)

        # Rotate around the surface
        self.play(
            self.frame.animate.increment_euler_angles(dtheta=-720 * DEGREES),
            run_time=8,
            rate_func=linear
        )
        self.wait(1)

        # Show cross-sections
        # x = 0 cross section (y-z plane)
        cross_x0 = ParametricCurve(
            lambda v: axes.c2p(0, v, np.sin(0) * np.cos(v)),
            t_range=[-3, 3, 0.1],
            color=RED,
            stroke_width=4,
        )

        # y = 0 cross section (x-z plane)
        cross_y0 = ParametricCurve(
            lambda u: axes.c2p(u, 0, np.sin(u) * np.cos(0)),
            t_range=[-3, 3, 0.1],
            color=GREEN,
            stroke_width=4,
        )

        cross_labels = VGroup(
            Text("x=0").scale(0.5).move_to(axes.c2p(0, 3.2, 0)),
            Text("y=0").scale(0.5).move_to(axes.c2p(3.2, 0, 0))
        )

        self.play(ShowCreation(cross_x0), ShowCreation(cross_y0), Write(cross_labels))
        self.wait(1)

        # Rotate more to show cross sections
        self.play(
            self.frame.animate.increment_euler_angles(dtheta=-360 * DEGREES),
            run_time=4,
            rate_func=linear
        )

        # Formula display
        formula = Text("z = sin(x) · cos(y)").to_edge(DOWN).scale(0.8)
        self.play(Write(formula))
        self.wait(2)

        # Fade out everything
        self.play(FadeOut(Group(surface, wireframe, axes, axes_labels, cross_x0, cross_y0, cross_labels, formula)))
        self.wait(0.5)

        # Closing
        end_title = Text("Keqo 3D", font_size=48)
        end_title.to_edge(UP)
        self.play(Transform(title, end_title))
        self.wait(1)
        self.play(FadeOut(title))


if __name__ == "__main__":
    scene = Surface3DScene()
    scene.run()