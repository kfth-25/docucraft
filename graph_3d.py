from manimlib import *
from manimlib.mobject.mobject import Group
import numpy as np

class Graph3DScene(ThreeDScene):
    def construct(self):
        # Title
        title = Text("Visualisasi 3D dengan Keqo", font_size=48)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait(0.5)

        # --- 1. Sumbu Koordinat 3D ---
        title1 = Text("1. Sumbu Koordinat 3D", font_size=48)
        title1.to_edge(UP)
        self.play(Transform(title, title1))

        axes = ThreeDAxes(
            x_range=[-3, 3, 1],
            y_range=[-3, 3, 1],
            z_range=[-2, 2, 1],
            width=8,
            height=6,
            depth=4,
            axis_config={"include_tip": True, "include_numbers": True},
        )

        axes_labels = VGroup(
            Text("x").next_to(axes.x_axis.get_right(), RIGHT),
            Text("y").next_to(axes.y_axis.get_top(), UP),
            Text("z").next_to(axes.z_axis.get_top(), OUT)
        )

        self.play(ShowCreation(axes), Write(axes_labels))

        # Rotate camera to show 3D - using frame.reorient()
        self.play(self.frame.animate.reorient(
            theta_degrees=-45,
            phi_degrees=70,
        ), run_time=2)
        self.wait(1)

        # Rotate around
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360 * DEGREES), run_time=4, rate_func=linear)
        self.wait(1)

        self.play(FadeOut(Group(axes, axes_labels)))

        # --- 2. Permukaan 3D: z = sin(x) * cos(y) ---
        title2 = Text("2. Permukaan: z = sin(x) * cos(y)", font_size=40)
        title2.to_edge(UP)
        self.play(Transform(title, title2))

        axes2 = ThreeDAxes(
            x_range=[-3, 3, 1],
            y_range=[-3, 3, 1],
            z_range=[-1.5, 1.5, 0.5],
            width=8,
            height=6,
            depth=4,
        )

        surface = ParametricSurface(
            lambda u, v: axes2.c2p(u, v, np.sin(u) * np.cos(v)),
            u_range=[-3, 3],
            v_range=[-3, 3],
            resolution=(30, 30),
            color=BLUE,
            opacity=0.7,
                    )

        self.play(ShowCreation(axes2))
        self.play(ShowCreation(surface))

        self.play(self.frame.animate.reorient(
            theta_degrees=-30,
            phi_degrees=60,
        ), run_time=2)
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360 * DEGREES), run_time=5, rate_func=linear)

        self.play(FadeOut(Group(axes2, surface)))

        # --- 3. Permukaan: Paraboloid z = x^2 + y^2 ---
        title3 = Text("3. Paraboloid: z = x^2 + y^2", font_size=48)
        title3.to_edge(UP)
        self.play(Transform(title, title3))

        axes3 = ThreeDAxes(
            x_range=[-2, 2, 1],
            y_range=[-2, 2, 1],
            z_range=[0, 4, 1],
            width=8,
            height=6,
            depth=4,
        )

        paraboloid = ParametricSurface(
            lambda u, v: axes3.c2p(u, v, u**2 + v**2),
            u_range=[-2, 2],
            v_range=[-2, 2],
            resolution=(25, 25),
            color=GREEN,
            opacity=0.7,
                    )

        self.play(ShowCreation(axes3))
        self.play(ShowCreation(paraboloid))

        self.play(self.frame.animate.reorient(
            theta_degrees=-45,
            phi_degrees=60,
        ), run_time=2)
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360 * DEGREES), run_time=4, rate_func=linear)

        self.play(FadeOut(Group(axes3, paraboloid)))

        # --- 4. Kurva 3D: Helix ---
        title4 = Text("4. Kurva 3D: Helix", font_size=48)
        title4.to_edge(UP)
        self.play(Transform(title, title4))

        axes4 = ThreeDAxes(
            x_range=[-2, 2, 1],
            y_range=[-2, 2, 1],
            z_range=[-2, 6, 1],
            width=8,
            height=6,
            depth=4,
        )

        helix = ParametricCurve(
            lambda t: axes4.c2p(np.cos(t), np.sin(t), t / 2),
            t_range=[0, 8 * PI, 0.05],
            color=RED,
            stroke_width=4,
        )

        self.play(ShowCreation(axes4))
        self.play(ShowCreation(helix), run_time=3)

        self.play(self.frame.animate.reorient(
            theta_degrees=-45,
            phi_degrees=60,
        ), run_time=2)
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360 * DEGREES), run_time=4, rate_func=linear)

        self.play(FadeOut(Group(axes4, helix)))

        # --- 5. Vektor 3D ---
        title5 = Text("5. Vektor 3D & Operasi", font_size=48)
        title5.to_edge(UP)
        self.play(Transform(title, title5))

        axes5 = ThreeDAxes(
            x_range=[-3, 3, 1],
            y_range=[-3, 3, 1],
            z_range=[-3, 3, 1],
            width=8,
            height=6,
            depth=4,
        )

        # Vectors
        v1 = Arrow3D(axes5.c2p(0, 0, 0), axes5.c2p(2, 1, 1), color=BLUE)
        v2 = Arrow3D(axes5.c2p(0, 0, 0), axes5.c2p(-1, 2, 1), color=RED)
        v3 = Arrow3D(axes5.c2p(0, 0, 0), axes5.c2p(1, 3, 2), color=YELLOW)  # v1 + v2

        v1_label = Text("v1").scale(0.5).move_to(axes5.c2p(2.2, 1.2, 1.2))
        v2_label = Text("v2").scale(0.5).move_to(axes5.c2p(-1.2, 2.2, 1.2))
        v3_label = Text("v1+v2").scale(0.5).move_to(axes5.c2p(1.2, 3.2, 2.2))

        self.play(ShowCreation(axes5))
        self.play(ShowCreation(v1), Write(v1_label))
        self.play(ShowCreation(v2), Write(v2_label))
        self.wait(0.5)
        self.play(ShowCreation(v3), Write(v3_label))
        self.wait(1)

        self.play(self.frame.animate.reorient(
            theta_degrees=-45,
            phi_degrees=60,
        ), run_time=2)
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360 * DEGREES), run_time=4, rate_func=linear)

        self.play(FadeOut(Group(axes5, v1, v2, v3, v1_label, v2_label, v3_label)))

        # --- 6. Bidang (Plane) ---
        title6 = Text("6. Bidang: 2x + 3y - z = 4", font_size=48)
        title6.to_edge(UP)
        self.play(Transform(title, title6))

        axes6 = ThreeDAxes(
            x_range=[-3, 3, 1],
            y_range=[-3, 3, 1],
            z_range=[-3, 3, 1],
            width=8,
            height=6,
            depth=4,
        )

        # Plane: 2x + 3y - z = 4 => z = 2x + 3y - 4
        plane = ParametricSurface(
            lambda u, v: axes6.c2p(u, v, 2*u + 3*v - 4),
            u_range=[-2, 2],
            v_range=[-2, 2],
            resolution=(20, 20),
            color=TEAL,
            opacity=0.5,
                    )

        self.play(ShowCreation(axes6))
        self.play(ShowCreation(plane))

        self.play(self.frame.animate.reorient(
            theta_degrees=-45,
            phi_degrees=60,
        ), run_time=2)
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360 * DEGREES), run_time=4, rate_func=linear)

        self.play(FadeOut(Group(axes6, plane)))

        # --- Closing ---
        title_end = Text("Terima Kasih! 🎉", font_size=48)
        title_end.to_edge(UP)
        self.play(Transform(title, title_end))
        self.wait(1)
        self.play(FadeOut(title))
        self.wait(0.5)


if __name__ == "__main__":
    scene = Graph3DScene()
    scene.run()