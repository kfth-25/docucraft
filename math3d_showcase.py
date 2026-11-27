from manimlib import *
import numpy as np

class Math3DShowcase(ThreeDScene):
    def construct(self):
        # ===== INTRO =====
        self.show_intro()

        # ===== 1. SUMBU KOORDINAT 3D MODERN =====
        self.show_axes_3d()

        # ===== 2. PERMUKAAN PARAMETRIK BERWARNA =====
        self.show_parametric_surfaces()

        # ===== 3. KURVA 3D YANG MENARIK =====
        self.show_space_curves()

        # ===== 4. VEKTOR & OPERASI =====
        self.show_vectors_3d()

        # ===== 5. BIDANG & IRISAN =====
        self.show_planes_intersection()

        # ===== 6. ANIMASI MORPHING =====
        self.show_morphing()

        # ===== OUTRO =====
        self.show_outro()

    def show_intro(self):
        title = Text("Matematika 3D Visualisasi", font_size=56, color=WHITE)
        subtitle = Text("dengan ManimGL + Keqo", font_size=32, color=BLUE_C)
        subtitle.next_to(title, DOWN, buff=0.5)

        self.play(Write(title), run_time=1.5)
        self.play(FadeIn(subtitle, shift=UP), run_time=1)
        self.wait(1)
        self.play(FadeOut(VGroup(title, subtitle)))

    def show_axes_3d(self):
        section_title = Text("1. Sistem Koordinat 3D", font_size=40, color=YELLOW)
        section_title.to_edge(UP)
        self.play(Write(section_title))

        # Axes dengan styling modern
        axes = ThreeDAxes(
            x_range=[-4, 4, 1],
            y_range=[-4, 4, 1],
            z_range=[-3, 3, 1],
            width=10,
            height=8,
            depth=6,
            axis_config={
                "include_tip": True,
                "include_numbers": True,
                "stroke_width": 2,
                "tip_config": {"width": 0.25, "length": 0.25},
            },
            x_axis_config={"color": RED},
            y_axis_config={"color": GREEN},
            z_axis_config={"color": BLUE},
        )

        # Labels sumbu
        x_label = Text("x", font_size=28, color=RED).next_to(axes.x_axis.get_end(), RIGHT)
        y_label = Text("y", font_size=28, color=GREEN).next_to(axes.y_axis.get_end(), UP)
        z_label = Text("z", font_size=28, color=BLUE).next_to(axes.z_axis.get_end(), OUT)

        # Grid planes
        xy_plane = Rectangle(width=8, height=8, color=RED_E, fill_opacity=0.05, stroke_width=0.5)
        xy_plane.move_to(ORIGIN)

        yz_plane = Rectangle(width=8, height=6, color=GREEN_E, fill_opacity=0.05, stroke_width=0.5)
        yz_plane.move_to(ORIGIN).rotate(90*DEGREES, axis=Y_AXIS)

        xz_plane = Rectangle(width=8, height=6, color=BLUE_E, fill_opacity=0.05, stroke_width=0.5)
        xz_plane.move_to(ORIGIN).rotate(-90*DEGREES, axis=X_AXIS)

        planes = VGroup(xy_plane, yz_plane, xz_plane)

        # Build
        self.play(ShowCreation(axes), run_time=2)
        self.play(Write(VGroup(x_label, y_label, z_label)))
        self.play(FadeIn(planes), run_time=1.5)

        # Camera positions
        self.play(self.frame.animate.reorient(phi_degrees=70, theta_degrees=-45), run_time=2)
        self.wait(0.5)

        # Ambient rotation
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360*DEGREES), run_time=4, rate_func=linear)
        self.wait(2)

        # Reset camera
        self.play(self.frame.animate.reorient(phi_degrees=70, theta_degrees=-45), run_time=2)
        self.wait(0.5)

        self.play(FadeOut(VGroup(axes, x_label, y_label, z_label, planes, section_title)))

    def show_parametric_surfaces(self):
        section_title = Text("2. Permukaan Parametrik", font_size=40, color=YELLOW)
        section_title.to_edge(UP)
        self.play(Write(section_title))

        axes = ThreeDAxes(
            x_range=[-3, 3, 1],
            y_range=[-3, 3, 1],
            z_range=[-2, 2, 1],
            width=9,
            height=7,
            depth=5,
        )

        # Surface 1: z = sin(x) * cos(y)
        surf1 = ParametricSurface(
            lambda u, v: axes.c2p(u, v, np.sin(u) * np.cos(v)),
            u_range=[-PI, PI],
            v_range=[-PI, PI],
            resolution=(50, 50),
            color=BLUE_C,
            opacity=0.8,
        )

        self.play(ShowCreation(axes), run_time=1.5)
        self.play(ShowCreation(surf1), run_time=3)

        label1 = Text("z = sin(x) · cos(y)", font_size=28, color=BLUE_C).to_edge(DOWN)
        self.play(FadeIn(label1))

        self.play(self.frame.animate.reorient(phi_degrees=65*DEGREES, theta_degrees=-30*DEGREES), run_time=2)
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360*DEGREES), run_time=5, rate_func=linear)

        # Transition to surface 2
        self.play(FadeOut(label1))

        # Surface 2: Paraboloid z = x^2 + y^2
        surf2 = ParametricSurface(
            lambda u, v: axes.c2p(u, v, u**2 + v**2),
            u_range=[-1.5, 1.5],
            v_range=[-1.5, 1.5],
            resolution=(40, 40),
            color=GREEN_C,
            opacity=0.8,
        )

        label2 = Text("z = x² + y² (Paraboloid)", font_size=28, color=GREEN_C).to_edge(DOWN)
        self.play(Transform(surf1, surf2), FadeIn(label2), run_time=2)
        self.wait(1)

        self.play(self.frame.animate.reorient(phi_degrees=60*DEGREES, theta_degrees=-45*DEGREES), run_time=2)
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360*DEGREES), run_time=5, rate_func=linear)

        self.play(FadeOut(label2))

        # Surface 3: Saddle / Hyperbolic paraboloid z = x^2 - y^2
        surf3 = ParametricSurface(
            lambda u, v: axes.c2p(u, v, u**2 - v**2),
            u_range=[-1.5, 1.5],
            v_range=[-1.5, 1.5],
            resolution=(40, 40),
            color=ORANGE,
            opacity=0.8,
        )

        label3 = Text("z = x² - y² (Saddle)", font_size=28, color=ORANGE).to_edge(DOWN)
        self.play(Transform(surf1, surf3), FadeIn(label3), run_time=2)
        self.wait(1)

        self.play(self.frame.animate.reorient(phi_degrees=55*DEGREES, theta_degrees=-60*DEGREES), run_time=2)
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360*DEGREES), run_time=5, rate_func=linear)

        self.play(FadeOut(label3))

        # Surface 4: Torus
        surf4 = ParametricSurface(
            lambda u, v: axes.c2p(
                (2 + np.cos(v)) * np.cos(u),
                (2 + np.cos(v)) * np.sin(u),
                np.sin(v)
            ),
            u_range=[0, TAU],
            v_range=[0, TAU],
            resolution=(40, 40),
            color=PURPLE_C,
            opacity=0.8,
        )

        label4 = Text("Torus (Donat)", font_size=28, color=PURPLE_C).to_edge(DOWN)
        self.play(Transform(surf1, surf4), FadeIn(label4), run_time=2)
        self.wait(1)

        self.play(self.frame.animate.reorient(phi_degrees=60*DEGREES, theta_degrees=-30*DEGREES), run_time=2)
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360*DEGREES), run_time=5, rate_func=linear)

        self.play(FadeOut(label4))

        # Surface 5: Sphere with texture
        surf5 = ParametricSurface(
            lambda u, v: axes.c2p(
                1.5 * np.sin(u) * np.cos(v),
                1.5 * np.sin(u) * np.sin(v),
                1.5 * np.cos(u)
            ),
            u_range=[0, PI],
            v_range=[0, TAU],
            resolution=(40, 40),
            color=TEAL_C,
            opacity=0.8,
        )

        label5 = Text("Bola (Sphere)", font_size=28, color=TEAL_C).to_edge(DOWN)
        self.play(Transform(surf1, surf5), FadeIn(label5), run_time=2)
        self.wait(1)

        self.play(self.frame.animate.reorient(phi_degrees=70, theta_degrees=-45), run_time=2)
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360*DEGREES), run_time=4, rate_func=linear)

        self.play(FadeOut(VGroup(surf1, axes, label5, section_title)))

    def show_space_curves(self):
        section_title = Text("3. Kurva Ruang (Space Curves)", font_size=40, color=YELLOW)
        section_title.to_edge(UP)
        self.play(Write(section_title))

        axes = ThreeDAxes(
            x_range=[-3, 3, 1],
            y_range=[-3, 3, 1],
            z_range=[-3, 5, 1],
            width=9,
            height=7,
            depth=5,
        )

        self.play(ShowCreation(axes), run_time=1.5)

        # Helix
        helix = ParametricCurve(
            lambda t: axes.c2p(np.cos(t), np.sin(t), t/2),
            t_range=[0, 4*TAU],
            color=YELLOW,
            stroke_width=5,
        )

        label = Text("Helix: r(t) = (cos t, sin t, t/2)", font_size=24, color=YELLOW).to_edge(DOWN)
        self.play(ShowCreation(helix), run_time=3, rate_func=linear)
        self.play(FadeIn(label))

        self.play(self.frame.animate.reorient(phi_degrees=60*DEGREES, theta_degrees=-45*DEGREES), run_time=2)
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360*DEGREES), run_time=4, rate_func=linear)

        self.play(FadeOut(label), FadeOut(helix))

        # Lissajous 3D
        lissajous = ParametricCurve(
            lambda t: axes.c2p(
                np.sin(3*t),
                np.sin(4*t),
                np.sin(5*t)
            ),
            t_range=[0, TAU],
            color=CYAN,
            stroke_width=5,
        )

        label2 = Text("Lissajous 3D: (sin 3t, sin 4t, sin 5t)", font_size=24, color=CYAN).to_edge(DOWN)
        self.play(ShowCreation(lissajous), run_time=3, rate_func=linear)
        self.play(FadeIn(label2))

        self.play(self.frame.animate.reorient(phi_degrees=70*DEGREES, theta_degrees=-30*DEGREES), run_time=2)
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360*DEGREES), run_time=5, rate_func=linear)

        self.play(FadeOut(label2), FadeOut(lissajous))

        # Trefoil Knot
        knot = ParametricCurve(
            lambda t: axes.c2p(
                np.sin(t) + 2*np.sin(2*t),
                np.cos(t) - 2*np.cos(2*t),
                -np.sin(3*t)
            ),
            t_range=[0, TAU],
            color=PINK,
            stroke_width=6,
        )

        label3 = Text("Trefoil Knot", font_size=24, color=PINK).to_edge(DOWN)
        self.play(ShowCreation(knot), run_time=3, rate_func=linear)
        self.play(FadeIn(label3))

        self.play(self.frame.animate.reorient(phi_degrees=65*DEGREES, theta_degrees=-60*DEGREES), run_time=2)
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360*DEGREES), run_time=5, rate_func=linear)

        self.play(FadeOut(VGroup(axes, knot, label3, section_title)))

    def show_vectors_3d(self):
        section_title = Text("4. Vektor 3D & Operasi", font_size=40, color=YELLOW)
        section_title.to_edge(UP)
        self.play(Write(section_title))

        axes = ThreeDAxes(
            x_range=[-3, 3, 1],
            y_range=[-3, 3, 1],
            z_range=[-3, 3, 1],
            width=9,
            height=7,
            depth=5,
        )

        self.play(ShowCreation(axes), run_time=1.5)

        # Vector definitions
        v1 = Arrow3D(axes.c2p(0,0,0), axes.c2p(2, 1, 1), color=BLUE, thickness=0.05)
        v2 = Arrow3D(axes.c2p(0,0,0), axes.c2p(-1, 2, 1), color=RED, thickness=0.05)
        v3 = Arrow3D(axes.c2p(0,0,0), axes.c2p(1, 3, 2), color=GOLD, thickness=0.05)  # v1+v2

        v1_label = Text("v₁ = (2, 1, 1)", font_size=20, color=BLUE).move_to(axes.c2p(2.3, 1.2, 1.2))
        v2_label = Text("v₂ = (-1, 2, 1)", font_size=20, color=RED).move_to(axes.c2p(-1.3, 2.3, 1.2))
        v3_label = Text("v₁ + v₂ = (1, 3, 2)", font_size=20, color=GOLD).move_to(axes.c2p(1.3, 3.3, 2.2))

        # Projections
        v1_xy = Arrow3D(axes.c2p(0,0,0), axes.c2p(2, 1, 0), color=BLUE_A, thickness=0.03)
        v1_xy.set_opacity(0.4)
        v2_xy = Arrow3D(axes.c2p(0,0,0), axes.c2p(-1, 2, 0), color=RED_A, thickness=0.03)
        v2_xy.set_opacity(0.4)

        proj_labels = VGroup(
            Text("Proyeksi XY", font_size=16, color=GREY).move_to(axes.c2p(0, 0, -2.5))
        )

        self.play(
            ShowCreation(v1), ShowCreation(v2),
            Write(v1_label), Write(v2_label),
            run_time=1.5
        )
        self.wait(0.5)

        # Show addition
        self.play(
            ShowCreation(v3),
            Write(v3_label),
            run_time=1.5
        )
        self.wait(0.5)

        # Show projections
        self.play(
            ShowCreation(v1_xy), ShowCreation(v2_xy),
            Write(proj_labels),
            run_time=1
        )

        # Parallelogram
        para = VGroup()
        # v1
        l1 = DashedLine(axes.c2p(2, 1, 1), axes.c2p(1, 3, 2), color=BLUE, stroke_width=1)
        # v2
        l2 = DashedLine(axes.c2p(-1, 2, 1), axes.c2p(1, 3, 2), color=RED, stroke_width=1)
        para.add(l1, l2)

        self.play(ShowCreation(para), run_time=1)

        formula = Text("v₁ + v₂ = (2-1, 1+2, 1+1) = (1, 3, 2)", font_size=24, color=GOLD).to_edge(DOWN)
        self.play(Write(formula))
        self.wait(1)

        # Cross product
        self.play(FadeOut(VGroup(v1_xy, v2_xy, proj_labels, para, formula)))

        # v1 × v2
        cross = Arrow3D(axes.c2p(0,0,0), axes.c2p(-1, -3, 5), color=PURPLE, thickness=0.05)
        cross_label = Text("v₁ × v₂ = (-1, -3, 5)", font_size=20, color=PURPLE).move_to(axes.c2p(-1.3, -3.3, 5.2))

        cross_formula = Text(
            "v₁ × v₂ = |i  j  k|\n    |2  1  1| = (-1, -3, 5)\n    |-1 2  1|",
            font_size=20, color=PURPLE
        ).to_edge(DOWN).shift(LEFT*3)

        self.play(ShowCreation(cross), Write(cross_label), run_time=1.5)
        self.play(Write(cross_formula))
        self.wait(1.5)

        self.play(FadeOut(VGroup(axes, v1, v2, v3, v1_label, v2_label, v3_label, cross, cross_label, cross_formula, section_title)))

    def show_planes_intersection(self):
        section_title = Text("5. Bidang & Irisan", font_size=40, color=YELLOW)
        section_title.to_edge(UP)
        self.play(Write(section_title))

        axes = ThreeDAxes(
            x_range=[-3, 3, 1],
            y_range=[-3, 3, 1],
            z_range=[-3, 3, 1],
            width=9,
            height=7,
            depth=5,
        )

        self.play(ShowCreation(axes), run_time=1.5)

        # Plane 1: z = 2x + y
        plane1 = ParametricSurface(
            lambda u, v: axes.c2p(u, v, 2*u + v),
            u_range=[-2, 2],
            v_range=[-2, 2],
            resolution=(20, 20),
            color=BLUE_C,
            fill_opacity=0.4,
            stroke_width=0.5,
            stroke_color=BLUE_E,
        )

        p1_label = Text("P₁: z = 2x + y", font_size=20, color=BLUE_C).move_to(axes.c2p(2.5, 2, 2))

        # Plane 2: z = x - y
        plane2 = ParametricSurface(
            lambda u, v: axes.c2p(u, v, u - v),
            u_range=[-2, 2],
            v_range=[-2, 2],
            resolution=(20, 20),
            color=RED_C,
            fill_opacity=0.4,
            stroke_width=0.5,
            stroke_color=RED_E,
        )

        p2_label = Text("P₂: z = x - y", font_size=20, color=RED_C).move_to(axes.c2p(2.5, -2, 2))

        self.play(ShowCreation(plane1), ShowCreation(plane2), run_time=2)
        self.play(Write(VGroup(p1_label, p2_label)))

        # Intersection line
        # Solve: 2x + y = x - y => x + 2y = 0 => x = -2y
        # z = 2(-2y) + y = -3y
        intersection = ParametricCurve(
            lambda t: axes.c2p(-2*t, t, -3*t),
            t_range=[-1.5, 1.5],
            color=GOLD,
            stroke_width=6,
        )

        i_label = Text("Irisan: x = -2t, y = t, z = -3t", font_size=20, color=GOLD).to_edge(DOWN)

        self.play(ShowCreation(intersection), run_time=2)
        self.play(Write(i_label))
        self.wait(1)

        # Animate intersection
        self.play(self.frame.animate.reorient(phi_degrees=60*DEGREES, theta_degrees=-45*DEGREES), run_time=2)
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360*DEGREES), run_time=5, rate_func=linear)

        self.play(FadeOut(i_label))

        # Add third plane
        # Plane 3: x + y + z = 0
        plane3 = ParametricSurface(
            lambda u, v: axes.c2p(u, v, -u - v),
            u_range=[-2, 2],
            v_range=[-2, 2],
            resolution=(20, 20),
            color=GREEN_C,
            fill_opacity=0.3,
            stroke_width=0.5,
            stroke_color=GREEN_E,
        )

        p3_label = Text("P₃: x + y + z = 0", font_size=20, color=GREEN_C).move_to(axes.c2p(-2.5, 2, 2))

        self.play(ShowCreation(plane3), Write(p3_label), run_time=1.5)

        # Triple intersection point
        # x = -2y, z = -3y, x + y + z = -2y + y - 3y = -4y = 0 => y = 0
        # So intersection at (0,0,0)
        triple_pt = Dot3D(axes.c2p(0,0,0), color=WHITE, radius=0.1)
        triple_label = Text("Titik Perpotongan: (0,0,0)", font_size=20, color=WHITE).to_edge(DOWN)

        self.play(FadeIn(triple_pt), Write(triple_label), run_time=1)
        self.wait(1)

        self.play(self.frame.animate.reorient(phi_degrees=55*DEGREES, theta_degrees=-30*DEGREES), run_time=2)
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360*DEGREES), run_time=5, rate_func=linear)

        self.play(FadeOut(VGroup(axes, plane1, plane2, plane3, p1_label, p2_label, p3_label, intersection, triple_pt, triple_label, section_title)))

    def show_morphing(self):
        section_title = Text("6. Morphing Permukaan", font_size=40, color=YELLOW)
        section_title.to_edge(UP)
        self.play(Write(section_title))

        axes = ThreeDAxes(
            x_range=[-2, 2, 1],
            y_range=[-2, 2, 1],
            z_range=[-2, 2, 1],
            width=8,
            height=6,
            depth=4,
        )

        self.play(ShowCreation(axes), run_time=1.5)

        # Sphere -> Cube -> Torus -> Sphere
        # Sphere
        sphere = ParametricSurface(
            lambda u, v: axes.c2p(
                1.2 * np.sin(u) * np.cos(v),
                1.2 * np.sin(u) * np.sin(v),
                1.2 * np.cos(u)
            ),
            u_range=[0, PI],
            v_range=[0, TAU],
            resolution=(30, 30),
            color=BLUE_C,
            opacity=0.8,
        )

        # Cube-like surface
        cube = ParametricSurface(
            lambda u, v: axes.c2p(
                1.2 * np.sign(np.cos(u)) * abs(np.cos(u))**(0.5) * np.cos(v),
                1.2 * np.sign(np.sin(u)) * abs(np.sin(u))**(0.5) * np.cos(v),
                1.2 * np.sin(v)
            ),
            u_range=[0, TAU],
            v_range=[-PI/2, PI/2],
            resolution=(40, 40),
            color=GREEN_C,
            opacity=0.8,
        )

        # Torus
        torus = ParametricSurface(
            lambda u, v: axes.c2p(
                (1.5 + 0.5*np.cos(v)) * np.cos(u),
                (1.5 + 0.5*np.cos(v)) * np.sin(u),
                0.5 * np.sin(v)
            ),
            u_range=[0, TAU],
            v_range=[0, TAU],
            resolution=(30, 30),
            color=ORANGE,
            opacity=0.8,
        )

        shapes = VGroup(sphere, cube, torus)
        for s in shapes:
            s.move_to(ORIGIN)

        self.play(ShowCreation(sphere), run_time=2)
        self.wait(0.5)

        # Morph sphere -> cube
        self.play(Transform(sphere, cube), run_time=2)
        self.wait(0.5)

        # Morph cube -> torus
        self.play(Transform(sphere, torus), run_time=2)
        self.wait(0.5)

        # Morph torus -> sphere
        self.play(Transform(sphere, ParametricSurface(
            lambda u, v: axes.c2p(
                1.2 * np.sin(u) * np.cos(v),
                1.2 * np.sin(u) * np.sin(v),
                1.2 * np.cos(u)
            ),
            u_range=[0, PI],
            v_range=[0, TAU],
            resolution=(30, 30),
            color=PURPLE_C,
            opacity=0.8,
        )), run_time=2)
        self.wait(1)

        # Rotate camera around
        self.play(self.frame.animate.reorient(phi_degrees=60*DEGREES, theta_degrees=-45*DEGREES), run_time=2)
        self.play(self.frame.animate.increment_euler_angles(dtheta=-360*DEGREES), run_time=6, rate_func=linear)

        self.play(FadeOut(VGroup(sphere, axes, section_title)))

    def show_outro(self):
        title = Text("Terima Kasih! 🎉", font_size=56, color=WHITE)
        subtitle = Text("Matematika 3D itu Menyenangkan!", font_size=32, color=BLUE_C)
        subtitle.next_to(title, DOWN, buff=0.5)
        branding = Text("Powered by Keqo", font_size=24, color=GREY).next_to(subtitle, DOWN, buff=1)

        self.play(Write(title), run_time=1.5)
        self.play(FadeIn(subtitle, shift=UP), run_time=1)
        self.play(FadeIn(branding, shift=UP), run_time=1)
        self.wait(2)
        self.play(FadeOut(VGroup(title, subtitle, branding)))


if __name__ == "__main__":
    scene = Math3DShowcase()
    scene.run()