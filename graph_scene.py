from manimlib import *
from manimlib.animation.creation import ShowCreation
import numpy as np

class GraphScene(Scene):
    def construct(self):
        # Title
        title = Text("Visualisasi Matematika dengan Keqo", font_size=48)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait(0.5)

        # --- 1. Grafik Fungsi Sinusoidal ---
        title1 = Text("1. Fungsi Sinusoidal: y = sin(x)", font_size=48)
        title1.to_edge(UP)
        self.play(Transform(title, title1))

        axes = Axes(
            x_range=[-2*PI, 2*PI, PI/2],
            y_range=[-1.5, 1.5, 0.5],
            width=10,
            height=4,
            axis_config={"include_tip": True, "include_numbers": True},
        )

        axes_labels = VGroup(
            Text("x").next_to(axes.x_axis.get_right(), RIGHT),
            Text("y").next_to(axes.y_axis.get_top(), UP)
        )

        sin_graph = axes.get_graph(lambda x: np.sin(x), color=BLUE, stroke_width=3)
        sin_label = Text("y = sin(x)").next_to(sin_graph, UP+RIGHT, buff=0.3).set_color(BLUE).scale(0.7)

        self.play(ShowCreation(axes), Write(axes_labels))
        self.play(ShowCreation(sin_graph), Write(sin_label))
        self.wait(0.5)

        # Add cosine for comparison
        cos_graph = axes.get_graph(lambda x: np.cos(x), color=RED, stroke_width=3)
        cos_label = Text("y = cos(x)").next_to(cos_graph, DOWN+RIGHT, buff=0.3).set_color(RED).scale(0.7)

        self.play(ShowCreation(cos_graph), Write(cos_label))
        self.wait(1)

        self.play(FadeOut(VGroup(sin_graph, cos_graph, sin_label, cos_label, axes, axes_labels)))

        # --- 2. Turunan (Derivative) ---
        title2 = Text("2. Turunan: f(x) = x^2, f'(x) = 2x", font_size=48)
        title2.to_edge(UP)
        self.play(Transform(title, title2))

        axes2 = Axes(
            x_range=[-3, 3, 1],
            y_range=[-1, 9, 1],
            width=10,
            height=5,
            axis_config={"include_tip": True, "include_numbers": True},
        )

        axes2_labels = VGroup(
            Text("x").next_to(axes2.x_axis.get_right(), RIGHT),
            Text("y").next_to(axes2.y_axis.get_top(), UP)
        )

        f_graph = axes2.get_graph(lambda x: x**2, color=BLUE, stroke_width=3)
        f_label = Text("f(x) = x^2").next_to(f_graph, UP+RIGHT, buff=0.3).set_color(BLUE).scale(0.7)

        df_graph = axes2.get_graph(lambda x: 2*x, color=RED, stroke_width=3)
        df_label = Text("f'(x) = 2x").next_to(df_graph, DOWN+LEFT, buff=0.3).set_color(RED).scale(0.7)

        self.play(ShowCreation(axes2), Write(axes2_labels))
        self.play(ShowCreation(f_graph), Write(f_label))
        self.wait(0.5)
        self.play(ShowCreation(df_graph), Write(df_label))
        self.wait(0.5)

        # Tangent line animation
        dot = Dot(axes2.c2p(1, 1), color=YELLOW)
        tangent = axes2.get_graph(lambda x: 2*x - 1, x_range=[0, 2], color=YELLOW, stroke_width=2)

        self.play(FadeIn(dot))
        self.play(ShowCreation(tangent))
        self.wait(0.5)

        # Move tangent along curve
        for x_val in [1.5, 2, 1, 0, -1, -1.5, 1]:
            new_tangent = axes2.get_graph(
                lambda x, xv=x_val: 2*xv*(x - xv) + xv**2,
                x_range=[x_val-1, x_val+1],
                color=YELLOW,
                stroke_width=2
            )
            new_dot = Dot(axes2.c2p(x_val, x_val**2), color=YELLOW)
            self.play(Transform(tangent, new_tangent), Transform(dot, new_dot), run_time=0.8)
        self.wait(0.5)

        self.play(FadeOut(VGroup(f_graph, df_graph, f_label, df_label, axes2, axes2_labels, dot, tangent)))

        # --- 3. Integral (Luas di bawah kurva) ---
        title3 = Text("3. Integral: Luas di bawah y = x^2 dari 0 sampai 2", font_size=40)
        title3.to_edge(UP)
        self.play(Transform(title, title3))

        axes3 = Axes(
            x_range=[-0.5, 3, 1],
            y_range=[-0.5, 5, 1],
            width=10,
            height=5,
            axis_config={"include_tip": True, "include_numbers": True},
        )

        axes3_labels = VGroup(
            Text("x").next_to(axes3.x_axis.get_right(), RIGHT),
            Text("y").next_to(axes3.y_axis.get_top(), UP)
        )

        f3_graph = axes3.get_graph(lambda x: x**2, color=BLUE, stroke_width=3)
        f3_graph.x_range = [-0.5, 3]  # Needed for get_area_under_graph

        # Area under curve
        area = axes3.get_area_under_graph(
            f3_graph,
            x_range=[0, 2],
            fill_color=GREEN,
            fill_opacity=0.4
        )

        integral_label = Text("Integral 0 to 2: x^2 dx = 8/3").to_edge(DOWN).scale(0.7)

        self.play(ShowCreation(axes3), Write(axes3_labels))
        self.play(ShowCreation(f3_graph))
        self.wait(0.3)
        self.play(FadeIn(area))
        self.play(Write(integral_label))
        self.wait(1.5)

        self.play(FadeOut(VGroup(f3_graph, area, axes3, axes3_labels, integral_label)))

        # --- 4. Fungsi Eksponensial & Logaritma ---
        title4 = Text("4. Eksponensial & Logaritma", font_size=48)
        title4.to_edge(UP)
        self.play(Transform(title, title4))

        axes4 = Axes(
            x_range=[-1, 4, 1],
            y_range=[-1, 8, 1],
            width=10,
            height=5,
            axis_config={"include_tip": True, "include_numbers": True},
        )

        axes4_labels = VGroup(
            Text("x").next_to(axes4.x_axis.get_right(), RIGHT),
            Text("y").next_to(axes4.y_axis.get_top(), UP)
        )

        exp_graph = axes4.get_graph(lambda x: np.exp(x), color=BLUE, stroke_width=3)
        exp_label = Text("y = e^x").next_to(exp_graph, UP+RIGHT, buff=0.3).set_color(BLUE).scale(0.7)

        log_graph = axes4.get_graph(lambda x: np.log(x), x_range=[0.01, 4], color=RED, stroke_width=3)
        log_label = Text("y = ln(x)").next_to(log_graph, DOWN+RIGHT, buff=0.3).set_color(RED).scale(0.7)

        # Identity line y=x
        identity = axes4.get_graph(lambda x: x, color=GREY, stroke_width=1, stroke_opacity=0.5)

        self.play(ShowCreation(axes4), Write(axes4_labels))
        self.play(ShowCreation(exp_graph), Write(exp_label))
        self.play(ShowCreation(log_graph), Write(log_label))
        self.play(ShowCreation(identity))
        self.wait(1)

        # Show reflection property
        self.play(
            exp_graph.animate.set_color(TEAL),
            log_graph.animate.set_color(TEAL),
        )
        self.wait(1)

        self.play(FadeOut(VGroup(exp_graph, log_graph, exp_label, log_label, axes4, axes4_labels, identity)))

        # --- 5. Fungsi Kuadratik dengan Vertex ---
        title5 = Text("5. Fungsi Kuadratik: Vertex Form", font_size=48)
        title5.to_edge(UP)
        self.play(Transform(title, title5))

        axes5 = Axes(
            x_range=[-4, 4, 1],
            y_range=[-1, 5, 1],
            width=10,
            height=5,
            axis_config={"include_tip": True, "include_numbers": True},
        )

        axes5_labels = VGroup(
            Text("x").next_to(axes5.x_axis.get_right(), RIGHT),
            Text("y").next_to(axes5.y_axis.get_top(), UP)
        )

        # f(x) = (x-1)^2 + 2, vertex at (1, 2)
        f5_graph = axes5.get_graph(lambda x: (x-1)**2 + 2, color=BLUE, stroke_width=3)
        vertex_dot = Dot(axes5.c2p(1, 2), color=RED, radius=0.1)
        vertex_label = Text("(1, 2)").next_to(vertex_dot, UP+RIGHT, buff=0.2).set_color(RED).scale(0.5)

        axis_sym = DashedLine(
            axes5.c2p(1, -0.5),
            axes5.c2p(1, 5),
            color=GREY,
            stroke_width=1
        )

        self.play(ShowCreation(axes5), Write(axes5_labels))
        self.play(ShowCreation(f5_graph))
        self.play(FadeIn(vertex_dot), Write(vertex_label))
        self.play(ShowCreation(axis_sym))
        self.wait(1)

        # Show vertex form formula
        formula = Text("f(x) = a(x-h)^2 + k, Vertex: (h, k)").to_edge(DOWN).scale(0.7)
        self.play(Write(formula))
        self.wait(1.5)

        self.play(FadeOut(VGroup(f5_graph, vertex_dot, vertex_label, axis_sym, axes5, axes5_labels, formula)))

        # --- 6. Persamaan Diferensial: Pertumbuhan Eksponensial ---
        title6 = Text("6. Model Pertumbuhan: dy/dt = ky", font_size=48)
        title6.to_edge(UP)
        self.play(Transform(title, title6))

        axes6 = Axes(
            x_range=[0, 5, 1],
            y_range=[0, 10, 1],
            width=10,
            height=5,
            axis_config={"include_tip": True, "include_numbers": True},
        )

        axes6_labels = VGroup(
            Text("t").next_to(axes6.x_axis.get_right(), RIGHT),
            Text("y").next_to(axes6.y_axis.get_top(), UP)
        )

        # Solution: y = y0 * e^(kt)
        k = 0.5
        y0 = 1
        exp_solution = axes6.get_graph(lambda t: y0 * np.exp(k*t), color=BLUE, stroke_width=3)
        sol_label = Text("y(t) = e^(0.5t)").next_to(exp_solution, UP+RIGHT, buff=0.3).set_color(BLUE).scale(0.7)

        # Show slope field concept with tangent lines
        tangents = VGroup()
        for t in np.linspace(0.2, 4.5, 10):
            y = y0 * np.exp(k*t)
            slope = k * y
            tangent_line = axes6.get_graph(
                lambda x, t0=t, y0=y, s=slope: s*(x - t0) + y0,
                x_range=[t-0.3, t+0.3],
                color=YELLOW,
                stroke_width=1.5
            )
            tangents.add(tangent_line)

        self.play(ShowCreation(axes6), Write(axes6_labels))
        self.play(ShowCreation(exp_solution), Write(sol_label))
        self.wait(0.3)
        self.play(ShowCreation(tangents))
        self.wait(1)

        # Equation
        deq = Text("dy/dt = ky => y = y0 * e^(kt)").to_edge(DOWN).scale(0.7)
        self.play(Write(deq))
        self.wait(1.5)

        self.play(FadeOut(VGroup(exp_solution, sol_label, axes6, axes6_labels, tangents, deq)))

        # --- Closing ---
        title_end = Text("Terima Kasih! 🎉", font_size=48)
        title_end.to_edge(UP)
        self.play(Transform(title, title_end))
        self.wait(1)
        self.play(FadeOut(VGroup(title)))
        self.wait(0.5)

if __name__ == "__main__":
    scene = GraphScene()
    scene.run()