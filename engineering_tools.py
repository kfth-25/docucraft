from manimlib import *
import numpy as np

class EngineeringToolsScene(Scene):
    def construct(self):
        # Title
        title = Text("Alat-Alat Teknik dengan Keqo", font_size=48)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait(0.5)

        # --- 1. Jangka Sorong (Vernier Caliper) ---
        self.show_caliper()
        self.wait(0.5)
        self.clear()

        # --- 2. Mikrometer Sekrup ---
        self.show_micrometer()
        self.wait(0.5)
        self.clear()

        # --- 3. Kunci Inggris (Adjustable Wrench) ---
        self.show_wrench()
        self.wait(0.5)
        self.clear()

        # --- 4. Multimeter Digital ---
        self.show_multimeter()
        self.wait(0.5)
        self.clear()

        # --- 5. Osiloskop ---
        self.show_oscilloscope()
        self.wait(0.5)
        self.clear()

        # --- 6. Tang Kombinasi ---
        self.show_pliers()
        self.wait(0.5)
        self.clear()

        # --- 7. Obeng Set ---
        self.show_screwdriver_set()
        self.wait(0.5)
        self.clear()

        # --- 8. Water Level / Spirit Level ---
        self.show_spirit_level()
        self.wait(0.5)
        self.clear()

        # Closing
        end_title = Text("Alat Teknik Lengkap! 🔧", font_size=48)
        end_title.to_edge(UP)
        self.play(Transform(title, end_title))
        self.wait(1)
        self.play(FadeOut(title))

    def show_caliper(self):
        title = Text("1. Jangka Sorong (Vernier Caliper)", font_size=40)
        title.to_edge(UP)
        self.play(Write(title))

        # Main scale (batang utama)
        main_scale = Rectangle(width=10, height=1.2, color=GREY_B, fill_opacity=0.3)
        main_scale.move_to(ORIGIN)

        # Scale markings
        scale_marks = VGroup()
        scale_numbers = VGroup()
        for i in range(0, 101, 5):  # 0-100mm, mark every 5mm
            x = -5 + i * 0.1
            if i % 10 == 0:
                # Major mark (1cm)
                mark = Line(UP * 0.3, DOWN * 0.3, color=WHITE, stroke_width=2)
                mark.move_to([x, 0, 0])
                num = Text(str(i//10), font_size=16).next_to(mark, DOWN, buff=0.2)
                scale_numbers.add(num)
            else:
                # Minor mark (5mm)
                mark = Line(UP * 0.15, DOWN * 0.15, color=WHITE, stroke_width=1)
                mark.move_to([x, 0, 0])
            scale_marks.add(mark)

        # Vernier scale (nonius) - sliding jaw
        vernier = Rectangle(width=2, height=1.2, color=BLUE_D, fill_opacity=0.5)
        vernier.move_to(main_scale.get_left() + RIGHT * 2.5)  # Start at 25mm

        vernier_marks = VGroup()
        for i in range(11):  # 0-10 divisions on vernier
            x = vernier.get_left()[0] + i * 0.18
            mark = Line(UP * 0.2, DOWN * 0.2, color=YELLOW, stroke_width=1.5)
            mark.move_to([x, 0, 0])
            vernier_marks.add(mark)

        # Fixed jaw (rahwang tetap)
        fixed_jaw = Rectangle(width=0.3, height=1.5, color=GREY_B, fill_opacity=0.8)
        fixed_jaw.move_to(main_scale.get_left() + LEFT * 0.15)

        # Moving jaw (rahwang geser)
        moving_jaw = Rectangle(width=0.3, height=1.5, color=BLUE_D, fill_opacity=0.8)
        moving_jaw.move_to(vernier.get_right() + RIGHT * 0.15)

        # Depth rod
        depth_rod = Line(main_scale.get_bottom() + DOWN * 0.1, main_scale.get_bottom() + DOWN * 2.5, color=GREY_C, stroke_width=3)

        # Label parts
        labels = VGroup(
            Text("Skala Utama (mm)").scale(0.5).next_to(main_scale, UP, buff=0.5),
            Text("Nonius (0.1 mm)").scale(0.5).set_color(YELLOW).next_to(vernier, UP, buff=1.5),
            Text("Rahwang Tetap").scale(0.5).next_to(fixed_jaw, LEFT, buff=0.5),
            Text("Rahwang Geser").scale(0.5).set_color(BLUE).next_to(moving_jaw, RIGHT, buff=0.5),
            Text("Batang Kedalaman").scale(0.5).next_to(depth_rod, RIGHT, buff=0.5),
        )

        # Assemble
        caliper = Group(main_scale, scale_marks, scale_numbers, vernier, vernier_marks,
                       fixed_jaw, moving_jaw, depth_rod)

        self.play(ShowCreation(main_scale), ShowCreation(scale_marks), Write(scale_numbers))
        self.play(ShowCreation(fixed_jaw), ShowCreation(moving_jaw))
        self.play(ShowCreation(vernier), ShowCreation(vernier_marks))
        self.play(ShowCreation(depth_rod))
        self.play(Write(labels))
        self.wait(1)

        # Animate measurement - slide vernier
        self.play(
            vernier.animate.shift(RIGHT * 3),  # Move to 55mm
            vernier_marks.animate.shift(RIGHT * 3),
            moving_jaw.animate.shift(RIGHT * 3),
            depth_rod.animate.shift(RIGHT * 3),
            run_time=2
        )
        self.wait(0.5)

        # Show reading
        reading = Text("Pembacaan: 55.0 mm", font_size=32, color=GREEN).to_edge(DOWN)
        self.play(Write(reading))
        self.wait(1.5)

        self.play(FadeOut(Group(caliper, labels, reading, title)))

    def show_micrometer(self):
        title = Text("2. Mikrometer Sekrup (0.01 mm)", font_size=40)
        title.to_edge(UP)
        self.play(Write(title))

        # Frame (badan)
        frame = VGroup()
        # C-shape frame
        frame_top = Rectangle(width=3, height=0.3, color=GREY_B, fill_opacity=0.8)
        frame_top.move_to(UP * 1.5)
        frame_bottom = Rectangle(width=3, height=0.3, color=GREY_B, fill_opacity=0.8)
        frame_bottom.move_to(DOWN * 1.5)
        frame_left = Rectangle(width=0.3, height=3.3, color=GREY_B, fill_opacity=0.8)
        frame_left.move_to(LEFT * 1.5)

        frame.add(frame_top, frame_bottom, frame_left)

        # Anvil (tempat benda tetap)
        anvil = Rectangle(width=0.5, height=0.8, color=GREY_C, fill_opacity=0.9)
        anvil.move_to(frame_left.get_right() + RIGHT * 0.25)

        # Spindle (spindel berputar)
        spindle = Rectangle(width=1.2, height=0.8, color=BLUE_D, fill_opacity=0.8)
        spindle.move_to(anvil.get_right() + RIGHT * 0.85)

        # Sleeve (skala mangkok)
        sleeve = Rectangle(width=1.5, height=0.6, color=GREY_A, fill_opacity=0.5)
        sleeve.move_to(spindle.get_center() + UP * 1.2)

        sleeve_marks = VGroup()
        sleeve_nums = VGroup()
        for i in range(0, 26, 5):  # 0-25mm
            x = sleeve.get_left()[0] + i * 0.06
            mark = Line(UP * 0.15, DOWN * 0.15, color=WHITE, stroke_width=2)
            mark.move_to([x, sleeve.get_center()[1], 0])
            sleeve_marks.add(mark)
            if i % 10 == 0 and i > 0:
                num = Text(str(i), font_size=14).next_to(mark, UP, buff=0.1)
                sleeve_nums.add(num)

        # Thimble (pemutar/skala nonius)
        thimble = Rectangle(width=1.5, height=0.6, color=BLUE_E, fill_opacity=0.7)
        thimble.move_to(sleeve.get_center())

        thimble_marks = VGroup()
        for i in range(50):  # 50 divisions = 0.5mm
            x = thimble.get_left()[0] + i * 0.03
            mark = Line(UP * 0.1, DOWN * 0.1, color=YELLOW, stroke_width=1)
            mark.move_to([x, thimble.get_center()[1], 0])
            thimble_marks.add(mark)
            if i % 10 == 0 and i > 0:
                num = Text(str(i), font_size=12, color=YELLOW).next_to(mark, DOWN, buff=0.1)
                thimble_marks.add(num)

        # Ratchet (ratchet/klik)
        ratchet = Circle(radius=0.4, color=GREY_C, fill_opacity=0.8)
        ratchet.move_to(spindle.get_right() + RIGHT * 0.6)

        # Lock nut
        lock = Rectangle(width=0.4, height=0.3, color=RED_E, fill_opacity=0.9)
        lock.move_to(frame_top.get_center() + DOWN * 0.3)

        labels = VGroup(
            Text("Frame (Badan)").scale(0.5).next_to(frame_left, LEFT, buff=0.5),
            Text("Anvil (Tetap)").scale(0.5).next_to(anvil, LEFT, buff=0.5),
            Text("Spindel (Geser)").scale(0.5).set_color(BLUE).next_to(spindle, RIGHT, buff=0.5),
            Text("Skala Mangkok (0.5mm)").scale(0.5).next_to(sleeve, UP, buff=0.5),
            Text("Nonius (0.01mm)").scale(0.5).set_color(YELLOW).next_to(thimble, DOWN, buff=0.5),
            Text("Ratchet").scale(0.5).next_to(ratchet, RIGHT, buff=0.5),
        )

        micro = Group(frame, anvil, spindle, sleeve, sleeve_marks, sleeve_nums,
                     thimble, thimble_marks, ratchet, lock)

        self.play(ShowCreation(frame), ShowCreation(anvil), ShowCreation(spindle))
        self.play(ShowCreation(sleeve), ShowCreation(sleeve_marks), Write(sleeve_nums))
        self.play(ShowCreation(thimble), ShowCreation(thimble_marks))
        self.play(ShowCreation(ratchet), ShowCreation(lock))
        self.play(Write(labels))
        self.wait(1)

        # Animate measurement - rotate thimble
        for _ in range(3):
            self.play(
                Rotate(thimble, angle=-PI/4, about_point=thimble.get_center()),
                Rotate(thimble_marks, angle=-PI/4, about_point=thimble.get_center()),
                spindle.animate.shift(RIGHT * 0.25),
                run_time=1
            )
            self.wait(0.3)

        reading = Text("Pembacaan: 12.34 mm", font_size=32, color=GREEN).to_edge(DOWN)
        self.play(Write(reading))
        self.wait(1.5)

        self.play(FadeOut(Group(micro, labels, reading, title)))

    def show_wrench(self):
        title = Text("3. Kunci Inggris (Adjustable Wrench)", font_size=40)
        title.to_edge(UP)
        self.play(Write(title))

        # Handle (gagang)
        handle = Rectangle(width=8, height=0.6, color=GREY_C, fill_opacity=0.8)
        handle.move_to(LEFT * 2)

        # Fixed jaw
        fixed_jaw = Polygon(
            [-4, -0.5, 0], [-4, 0.5, 0], [-3, 0.8, 0], [-3, -0.8, 0],
            color=GREY_B, fill_opacity=0.9
        )

        # Movable jaw
        movable_jaw = Polygon(
            [1, -0.5, 0], [1, 0.5, 0], [2, 0.8, 0], [2, -0.8, 0],
            color=BLUE_D, fill_opacity=0.9
        )

        # Worm gear (pengatur)
        worm = Circle(radius=0.25, color=GOLD, fill_opacity=0.9)
        worm.move_to(handle.get_center() + UP * 0.5 + RIGHT * 1.5)

        # Scale on handle
        scale_marks = VGroup()
        for i in range(9):
            x = -3.5 + i * 0.875
            mark = Line(UP * 0.15, DOWN * 0.15, color=WHITE, stroke_width=1.5)
            mark.move_to([x, handle.get_center()[1], 0])
            scale_marks.add(mark)

        labels = VGroup(
            Text("Rahwang Tetap").scale(0.5).next_to(fixed_jaw, LEFT, buff=0.5),
            Text("Rahwang Geser").scale(0.5).set_color(BLUE).next_to(movable_jaw, RIGHT, buff=0.5),
            Text("Pengatur (Cacing)").scale(0.5).set_color(GOLD).next_to(worm, UP, buff=0.5),
            Text("Skala Ukur").scale(0.5).next_to(handle, DOWN, buff=0.5),
        )

        wrench = Group(handle, fixed_jaw, movable_jaw, worm, scale_marks)

        self.play(ShowCreation(handle), ShowCreation(fixed_jaw), ShowCreation(movable_jaw))
        self.play(ShowCreation(worm), ShowCreation(scale_marks))
        self.play(Write(labels))
        self.wait(1)

        # Animate adjusting
        for _ in range(3):
            self.play(
                Rotate(worm, angle=PI, about_point=worm.get_center()),
                movable_jaw.animate.shift(LEFT * 0.5),
                run_time=1
            )
            self.play(
                Rotate(worm, angle=-PI, about_point=worm.get_center()),
                movable_jaw.animate.shift(RIGHT * 0.5),
                run_time=1
            )

        # Show gripping a bolt
        bolt = Circle(radius=0.4, color=GREY_B, fill_opacity=0.9)
        bolt.move_to(movable_jaw.get_left() + LEFT * 0.5)
        bolt_nut = RegularPolygon(n=6, radius=0.5, color=GREY_C, fill_opacity=0.9)
        bolt_nut.move_to(bolt)

        self.play(ShowCreation(bolt), ShowCreation(bolt_nut))
        self.wait(0.5)

        # Tighten
        self.play(
            Rotate(worm, angle=2*PI, about_point=worm.get_center()),
            movable_jaw.animate.shift(LEFT * 0.4),
            bolt_nut.animate.rotate(PI, about_point=bolt.get_center()),
            run_time=2
        )

        reading = Text("Mengencangkan Baut", font_size=32, color=GREEN).to_edge(DOWN)
        self.play(Write(reading))
        self.wait(1.5)

        self.play(FadeOut(Group(wrench, labels, bolt, bolt_nut, reading, title)))

    def show_multimeter(self):
        title = Text("4. Multimeter Digital", font_size=40)
        title.to_edge(UP)
        self.play(Write(title))

        # Body
        body = RoundedRectangle(width=4, height=6, corner_radius=0.3, color=GREY_E, fill_opacity=0.9)
        body.move_to(ORIGIN)

        # Display (LCD)
        display = Rectangle(width=3.2, height=1.5, color=BLACK, fill_opacity=1)
        display.move_to(body.get_top() + DOWN * 1.2)

        # Display text
        display_text = VGroup(
            Text("12.34", font_size=48, color=GREEN).move_to(display.get_center() + UP * 0.2),
            Text("V DC", font_size=20, color=GREEN).move_to(display.get_center() + DOWN * 0.3)
        )

        # Selector dial
        dial = Circle(radius=0.8, color=YELLOW_E, fill_opacity=0.8)
        dial.move_to(body.get_center() + DOWN * 0.5)

        dial_needle = Line(ORIGIN, UP * 0.6, color=RED, stroke_width=3)
        dial_needle.move_to(dial.get_center())

        # Dial positions
        dial_labels = VGroup()
        positions = [
            ("OFF", UP * 0.8),
            ("V~", UP * 0.4 + RIGHT * 0.7),
            ("V=", RIGHT * 0.8),
            ("A~", DOWN * 0.4 + RIGHT * 0.7),
            ("A=", DOWN * 0.8),
            ("Ω", DOWN * 0.4 + LEFT * 0.7),
            ("🔔", UP * 0.4 + LEFT * 0.7),
        ]
        for label, pos in positions:
            t = Text(label, font_size=14, color=BLACK).move_to(dial.get_center() + pos)
            dial_labels.add(t)

        # Ports
        ports = VGroup()
        port_labels = VGroup()
        port_positions = [
            (body.get_bottom() + UP * 0.8 + LEFT * 1.2, "COM", BLACK),
            (body.get_bottom() + UP * 0.8 + RIGHT * 0.2, "V/Ω", RED),
            (body.get_bottom() + UP * 0.8 + RIGHT * 1.6, "A", YELLOW),
        ]
        for pos, label, color in port_positions:
            port = Circle(radius=0.25, color=color, fill_opacity=0.8)
            port.move_to(pos)
            ports.add(port)
            port_labels.add(Text(label, font_size=12, color=WHITE).next_to(port, DOWN, buff=0.1))

        # Probe wires
        red_wire = Line(ports[1].get_bottom() + DOWN * 0.3, ports[1].get_bottom() + DOWN * 2, color=RED, stroke_width=4)
        black_wire = Line(ports[0].get_bottom() + DOWN * 0.3, ports[0].get_bottom() + DOWN * 2, color=BLACK, stroke_width=4)

        red_probe = Rectangle(width=0.2, height=0.6, color=RED, fill_opacity=1).move_to(red_wire.get_bottom() + DOWN * 0.3)
        black_probe = Rectangle(width=0.2, height=0.6, color=BLACK, fill_opacity=1).move_to(black_wire.get_bottom() + DOWN * 0.3)

        labels = VGroup(
            Text("Display LCD").scale(0.5).next_to(display, UP, buff=0.5),
            Text("Selector Dial").scale(0.5).next_to(dial, RIGHT, buff=0.5),
            Text("Port COM (Hitam)").scale(0.5).next_to(ports[0], LEFT, buff=0.5),
            Text("Port V/Ω (Merah)").scale(0.5).set_color(RED).next_to(ports[1], RIGHT, buff=0.5),
            Text("Port A (Kuning)").scale(0.5).set_color(YELLOW).next_to(ports[2], RIGHT, buff=0.5),
        )

        meter = Group(body, display, display_text, dial, dial_needle, dial_labels,
                     ports, port_labels, red_wire, black_wire, red_probe, black_probe)

        self.play(ShowCreation(body))
        self.play(ShowCreation(display), Write(display_text))
        self.play(ShowCreation(dial), ShowCreation(dial_needle), Write(dial_labels))
        self.play(ShowCreation(ports), Write(port_labels))
        self.play(ShowCreation(red_wire), ShowCreation(black_wire), ShowCreation(red_probe), ShowCreation(black_probe))
        self.play(Write(labels))
        self.wait(1)

        # Animate measuring voltage
        self.play(
            Rotate(dial_needle, angle=-PI/2, about_point=dial.get_center()),
            run_time=1
        )
        self.play(
            display_text[0].animate.become(Text("5.00", font_size=48, color=GREEN).move_to(display.get_center() + UP * 0.2)),
            run_time=0.5
        )
        self.wait(0.5)

        # Measure resistance
        self.play(
            Rotate(dial_needle, angle=PI, about_point=dial.get_center()),
            run_time=1
        )
        self.play(
            display_text[0].animate.become(Text("1.23k", font_size=48, color=GREEN).move_to(display.get_center() + UP * 0.2)),
            display_text[1].animate.become(Text("Ω", font_size=20, color=GREEN).move_to(display.get_center() + DOWN * 0.3)),
            run_time=0.5
        )
        self.wait(0.5)

        # Continuity test
        self.play(
            Rotate(dial_needle, angle=-PI/4, about_point=dial.get_center()),
            run_time=1
        )
        self.play(
            display_text[0].animate.become(Text("0.00", font_size=48, color=GREEN).move_to(display.get_center() + UP * 0.2)),
            display_text[1].animate.become(Text("🔊", font_size=20, color=GREEN).move_to(display.get_center() + DOWN * 0.3)),
            run_time=0.5
        )

        # Beep animation
        for _ in range(3):
            wave = Circle(radius=0.3, color=YELLOW, stroke_width=2).move_to(dial.get_center())
            self.play(ShowCreation(wave), wave.animate.scale(3).set_opacity(0), run_time=0.3)

        self.wait(1)
        self.play(FadeOut(Group(meter, labels, title)))

    def show_oscilloscope(self):
        title = Text("5. Osiloskop Digital (DSO)", font_size=40)
        title.to_edge(UP)
        self.play(Write(title))

        # Body
        body = RoundedRectangle(width=9, height=5.5, corner_radius=0.3, color=GREY_E, fill_opacity=0.9)
        body.move_to(ORIGIN)

        # Screen
        screen = Rectangle(width=7.5, height=4, color=BLACK, fill_opacity=1)
        screen.move_to(body.get_center() + UP * 0.2)

        # Grid
        grid = VGroup()
        for i in range(1, 10):  # Vertical grid (10 div)
            x = screen.get_left()[0] + i * 0.75
            line = DashedLine(screen.get_top(), screen.get_bottom(), color=GREEN_E, stroke_width=0.5)
            line.move_to([x, 0, 0])
            grid.add(line)
        for i in range(1, 8):  # Horizontal grid (8 div)
            y = screen.get_bottom()[1] + i * 0.5
            line = DashedLine(screen.get_left(), screen.get_right(), color=GREEN_E, stroke_width=0.5)
            line.move_to([0, y, 0])
            grid.add(line)

        # Center lines
        center_v = Line(screen.get_top(), screen.get_bottom(), color=GREEN_D, stroke_width=1)
        center_v.move_to([0, 0, 0])
        center_h = Line(screen.get_left(), screen.get_right(), color=GREEN_D, stroke_width=1)
        center_h.move_to([0, 0, 0])

        # Waveform - sine wave
        wave_points = []
        for x in np.linspace(-3.5, 3.5, 200):
            y = 1.5 * np.sin(2 * x)
            wave_points.append([x, y, 0])
        waveform = VMobject()
        waveform.set_points_as_corners(wave_points)
        waveform.set_color(YELLOW)
        waveform.set_stroke_width(2)
        waveform.move_to(screen.get_center())

        # Second waveform - square wave
        wave2_points = []
        for x in np.linspace(-3.5, 3.5, 200):
            y = 1.0 * np.sign(np.sin(4 * x))
            wave2_points.append([x, y - 1.5, 0])
        waveform2 = VMobject()
        waveform2.set_points_as_corners(wave2_points)
        waveform2.set_color(CYAN)
        waveform2.set_stroke_width(2)
        waveform2.move_to(screen.get_center())

        # Controls
        controls = VGroup()
        # Time/div knob
        t_div = Circle(radius=0.3, color=YELLOW_E, fill_opacity=0.8)
        t_div.move_to(body.get_bottom() + UP * 0.8 + LEFT * 2.5)
        t_label = Text("TIME/DIV", font_size=12).next_to(t_div, DOWN, buff=0.1)
        t_val = Text("1ms", font_size=14, color=WHITE).move_to(t_div.get_center())

        # Volt/div knobs
        v_div1 = Circle(radius=0.3, color=BLUE_E, fill_opacity=0.8)
        v_div1.move_to(body.get_bottom() + UP * 0.8 + LEFT * 0.5)
        v_label1 = Text("CH1 V/DIV", font_size=12).next_to(v_div1, DOWN, buff=0.1)
        v_val1 = Text("1V", font_size=14, color=WHITE).move_to(v_div1.get_center())

        v_div2 = Circle(radius=0.3, color=RED_E, fill_opacity=0.8)
        v_div2.move_to(body.get_bottom() + UP * 0.8 + RIGHT * 0.5)
        v_label2 = Text("CH2 V/DIV", font_size=12).next_to(v_div2, DOWN, buff=0.1)
        v_val2 = Text("2V", font_size=14, color=WHITE).move_to(v_div2.get_center())

        # Trigger level
        trig = Circle(radius=0.25, color=ORANGE, fill_opacity=0.8)
        trig.move_to(body.get_bottom() + UP * 0.8 + RIGHT * 2.5)
        trig_label = Text("TRIG", font_size=10).next_to(trig, DOWN, buff=0.1)

        controls.add(t_div, t_label, t_val, v_div1, v_label1, v_val1, v_div2, v_label2, v_val2, trig, trig_label)

        # Channel inputs
        ch1 = Circle(radius=0.3, color=YELLOW, fill_opacity=0.8)
        ch1.move_to(body.get_left() + RIGHT * 0.5 + DOWN * 2)
        ch1_label = Text("CH1", font_size=12, color=YELLOW).next_to(ch1, LEFT, buff=0.2)

        ch2 = Circle(radius=0.3, color=CYAN, fill_opacity=0.8)
        ch2.move_to(body.get_left() + RIGHT * 0.5 + DOWN * 2.7)
        ch2_label = Text("CH2", font_size=12, color=CYAN).next_to(ch2, LEFT, buff=0.2)

        # Measurements display
        meas = VGroup(
            Text("CH1: Freq=1.00kHz  Vpp=3.00V", font_size=16, color=YELLOW),
            Text("CH2: Freq=2.00kHz  Vpp=2.00V", font_size=16, color=CYAN),
            Text("Δt=250μs  1/Δt=4.00kHz", font_size=16, color=WHITE),
        ).arrange(DOWN, aligned_edge=LEFT).move_to(screen.get_right() + RIGHT * 2)

        labels = VGroup(
            Text("Layar (Grid 10x8 div)").scale(0.5).next_to(screen, UP, buff=0.5),
            Text("CH1 (Kuning) - Sine Wave").scale(0.5).set_color(YELLOW).next_to(screen, LEFT, buff=1.5),
            Text("CH2 (Cyan) - Square Wave").scale(0.5).set_color(CYAN).next_to(screen, LEFT, buff=3),
        )

        scope = Group(body, screen, grid, center_v, center_h, waveform, waveform2,
                     controls, ch1, ch1_label, ch2, ch2_label, meas)

        self.play(ShowCreation(body), ShowCreation(screen))
        self.play(ShowCreation(grid), ShowCreation(center_v), ShowCreation(center_h))
        self.play(ShowCreation(waveform), ShowCreation(waveform2))
        self.play(ShowCreation(controls), ShowCreation(ch1), ShowCreation(ch2), Write(ch1_label), Write(ch2_label))
        self.play(Write(meas), Write(labels))
        self.wait(1)

        # Animate waveforms
        self.play(
            waveform.animate.shift(LEFT * 0.5),
            waveform2.animate.shift(LEFT * 0.5),
            run_time=2, rate_func=linear
        )
        self.play(
            waveform.animate.shift(RIGHT * 1.0),
            waveform2.animate.shift(RIGHT * 1.0),
            run_time=2, rate_func=linear
        )
        self.play(
            waveform.animate.shift(LEFT * 0.5),
            waveform2.animate.shift(LEFT * 0.5),
            run_time=2, rate_func=linear
        )

        reading = Text("Mengukur Sinyal Gelombang", font_size=32, color=GREEN).to_edge(DOWN)
        self.play(Write(reading))
        self.wait(1.5)

        self.play(FadeOut(Group(scope, labels, reading, title)))

    def show_pliers(self):
        title = Text("6. Tang Kombinasi (Combination Pliers)", font_size=40)
        title.to_edge(UP)
        self.play(Write(title))

        # Left handle
        left_handle = Rectangle(width=6, height=0.5, color=BLUE_E, fill_opacity=0.8)
        left_handle.move_to(LEFT * 1.5 + UP * 0.3).rotate(-15 * DEGREES)

        # Right handle
        right_handle = Rectangle(width=6, height=0.5, color=RED_E, fill_opacity=0.8)
        right_handle.move_to(LEFT * 1.5 + DOWN * 0.3).rotate(15 * DEGREES)

        # Pivot point
        pivot = Circle(radius=0.25, color=GOLD, fill_opacity=1)
        pivot.move_to(LEFT * 3.5)

        # Jaws
        left_jaw = Polygon(
            [-3.5, 0, 0], [-3.5, 0.8, 0], [-2.5, 0.5, 0], [-2.5, -0.5, 0],
            color=GREY_B, fill_opacity=0.9
        )
        left_jaw.move_to(LEFT * 3.5 + UP * 0.3).rotate(-15 * DEGREES)

        right_jaw = Polygon(
            [-3.5, 0, 0], [-3.5, -0.8, 0], [-2.5, -0.5, 0], [-2.5, 0.5, 0],
            color=GREY_B, fill_opacity=0.9
        )
        right_jaw.move_to(LEFT * 3.5 + DOWN * 0.3).rotate(15 * DEGREES)

        # Cutting edge (mata potong)
        cut_edge = Line(LEFT * 3.5 + UP * 0.8, LEFT * 3.5 + DOWN * 0.8, color=ORANGE, stroke_width=4)
        cut_label = Text("Mata Potong", font_size=14, color=ORANGE).next_to(cut_edge, LEFT, buff=0.3)

        # Gripping teeth (gigi cengkeram)
        teeth = VGroup()
        for i in range(5):
            y = -0.3 + i * 0.15
            tooth = Line(LEFT * 3.0, LEFT * 2.7, color=WHITE, stroke_width=2)
            tooth.move_to([-3.0, y, 0])
            teeth.add(tooth)

        labels = VGroup(
            Text("Gagang (Isolator)").scale(0.5).next_to(left_handle, UP, buff=0.5),
            Text("Poros/Pivot").scale(0.5).set_color(GOLD).next_to(pivot, UP, buff=0.3),
            Text("Cengkeram").scale(0.5).next_to(left_jaw, LEFT, buff=0.5),
            cut_label,
        )

        pliers = Group(left_handle, right_handle, pivot, left_jaw, right_jaw, cut_edge, teeth)

        self.play(ShowCreation(left_handle), ShowCreation(right_handle))
        self.play(ShowCreation(pivot))
        self.play(ShowCreation(left_jaw), ShowCreation(right_jaw))
        self.play(ShowCreation(cut_edge), ShowCreation(teeth))
        self.play(Write(labels))
        self.wait(1)

        # Animate cutting
        wire = Rectangle(width=0.2, height=0.8, color=COPPER, fill_opacity=1)
        wire.move_to(LEFT * 3.0)

        self.play(ShowCreation(wire))
        self.wait(0.5)

        # Close jaws to cut
        self.play(
            left_handle.animate.rotate(15 * DEGREES, about_point=pivot.get_center()),
            right_handle.animate.rotate(-15 * DEGREES, about_point=pivot.get_center()),
            left_jaw.animate.rotate(15 * DEGREES, about_point=pivot.get_center()),
            right_jaw.animate.rotate(-15 * DEGREES, about_point=pivot.get_center()),
            run_time=0.5
        )
        self.play(
            wire.animate.scale(0).set_opacity(0),
            run_time=0.3
        )

        reading = Text("Memotong Kawat", font_size=32, color=GREEN).to_edge(DOWN)
        self.play(Write(reading))
        self.wait(1.5)

        self.play(FadeOut(Group(pliers, labels, wire, reading, title)))

    def show_screwdriver_set(self):
        title = Text("7. Set Obeng (Screwdriver Set)", font_size=40)
        title.to_edge(UP)
        self.play(Write(title))

        screwdrivers = VGroup()
        types = [
            ("Minus (Flat)", 0.8, BLUE, "—"),
            ("Plus (Phillips)", 0.8, GREEN, "+"),
            ("Star (Torx)", 0.6, ORANGE, "✱"),
            ("Hex (Allen)", 0.5, PURPLE, "⬡"),
            ("Pozidriv", 0.8, RED, "✚"),
        ]

        for i, (name, shaft_w, color, tip_shape) in enumerate(types):
            # Handle
            handle = Rectangle(width=1.2, height=2.5, color=GREY_D, fill_opacity=0.8)
            handle.move_to([-5 + i * 2.5, -1.5, 0])

            # Shaft
            shaft = Rectangle(width=shaft_w, height=4, color=GREY_C, fill_opacity=0.9)
            shaft.move_to(handle.get_top() + UP * 2.2)

            # Tip
            if tip_shape == "—":
                tip = Rectangle(width=1.5, height=0.15, color=color, fill_opacity=1)
            elif tip_shape == "+":
                tip = VGroup(
                    Rectangle(width=1.5, height=0.15, color=color, fill_opacity=1),
                    Rectangle(width=0.15, height=1.5, color=color, fill_opacity=1)
                )
            elif tip_shape == "✱":
                tip = VGroup(
                    Rectangle(width=1.5, height=0.15, color=color, fill_opacity=1).rotate(0),
                    Rectangle(width=1.5, height=0.15, color=color, fill_opacity=1).rotate(60 * DEGREES),
                    Rectangle(width=1.5, height=0.15, color=color, fill_opacity=1).rotate(120 * DEGREES),
                )
            elif tip_shape == "⬡":
                tip = RegularPolygon(n=6, radius=0.75, color=color, fill_opacity=1)
            else:  # Pozidriv
                tip = VGroup(
                    Rectangle(width=1.5, height=0.15, color=color, fill_opacity=1),
                    Rectangle(width=0.15, height=1.5, color=color, fill_opacity=1),
                    Rectangle(width=1.2, height=0.1, color=color, fill_opacity=1).rotate(45 * DEGREES),
                    Rectangle(width=1.2, height=0.1, color=color, fill_opacity=1).rotate(-45 * DEGREES),
                )
            tip.move_to(shaft.get_top() + UP * 0.2)

            # Label
            label = Text(name, font_size=14).next_to(handle, DOWN, buff=0.3)

            sd = Group(handle, shaft, tip, label)
            screwdrivers.add(sd)

        self.play(ShowCreation(screwdrivers))
        self.wait(1)

        # Animate using each on screws
        screws = VGroup()
        for i in range(5):
            screw_head = Circle(radius=0.5, color=GREY_B, fill_opacity=0.9)
            screw_head.move_to([-5 + i * 2.5, 2.5, 0])
            screws.add(screw_head)

        self.play(ShowCreation(screws))

        for i in range(5):
            sd = screwdrivers[i]
            screw = screws[i]
            # Move screwdriver to screw
            self.play(sd.animate.move_to(screw.get_center() + UP * 3), run_time=0.5)
            # Rotate to tighten
            self.play(Rotate(sd[2], angle=2*PI, about_point=sd[2].get_bottom()), run_time=1)
            self.play(sd.animate.move_to([-5 + i * 2.5, -1.5, 0]), run_time=0.5)

        reading = Text("Mengencangkan Berbagai Sekrup", font_size=32, color=GREEN).to_edge(DOWN)
        self.play(Write(reading))
        self.wait(1.5)

        self.play(FadeOut(Group(screwdrivers, screws, reading, title)))

    def show_spirit_level(self):
        title = Text("8. Water Level / Spirit Level", font_size=40)
        title.to_edge(UP)
        self.play(Write(title))

        # Body
        body = Rectangle(width=8, height=1.5, color=BLUE_E, fill_opacity=0.8)
        body.move_to(ORIGIN)

        # Vial horizontal (ban horizontal)
        vial_h = Rectangle(width=4, height=0.6, color=GREEN_A, fill_opacity=0.3)
        vial_h.move_to(body.get_center() + LEFT * 1.5)

        # Bubble
        bubble_h = Circle(radius=0.2, color=WHITE, fill_opacity=0.9)
        bubble_h.move_to(vial_h.get_center())

        # Vial vertical (ban vertikal)
        vial_v = Rectangle(width=0.6, height=3, color=GREEN_A, fill_opacity=0.3)
        vial_v.move_to(body.get_center() + RIGHT * 2.5 + UP * 0.5)

        bubble_v = Circle(radius=0.2, color=WHITE, fill_opacity=0.9)
        bubble_v.move_to(vial_v.get_center())

        # End caps
        cap_left = Rectangle(width=0.3, height=1.5, color=GREY_C, fill_opacity=1).move_to(body.get_left() + LEFT * 0.15)
        cap_right = Rectangle(width=0.3, height=1.5, color=GREY_C, fill_opacity=1).move_to(body.get_right() + RIGHT * 0.15)

        # Hanging holes
        hole1 = Circle(radius=0.15, color=BLACK, fill_opacity=1).move_to(body.get_left() + LEFT * 0.15 + UP * 0.5)
        hole2 = Circle(radius=0.15, color=BLACK, fill_opacity=1).move_to(body.get_right() + RIGHT * 0.15 + UP * 0.5)

        labels = VGroup(
            Text("Ban Horizontal").scale(0.5).next_to(vial_h, UP, buff=0.5),
            Text("Ban Vertikal").scale(0.5).next_to(vial_v, RIGHT, buff=0.5),
            Text("Gelembung Udara").scale(0.5).next_to(bubble_h, UP, buff=1),
            Text("Titik Tengah = Level").scale(0.5).set_color(GREEN).next_to(body, DOWN, buff=0.5),
        )

        level = Group(body, vial_h, bubble_h, vial_v, bubble_v, cap_left, cap_right, hole1, hole2)

        self.play(ShowCreation(body), ShowCreation(vial_h), ShowCreation(vial_v))
        self.play(ShowCreation(bubble_h), ShowCreation(bubble_v))
        self.play(ShowCreation(cap_left), ShowCreation(cap_right), ShowCreation(hole1), ShowCreation(hole2))
        self.play(Write(labels))
        self.wait(1)

        # Animate tilting - bubble moves
        self.play(
            level.animate.rotate(10 * DEGREES, about_point=ORIGIN),
            bubble_h.animate.shift(LEFT * 1.5),
            bubble_v.animate.shift(DOWN * 1.0),
            run_time=1
        )
        self.wait(0.5)

        self.play(
            level.animate.rotate(-20 * DEGREES, about_point=ORIGIN),
            bubble_h.animate.shift(RIGHT * 3.0),
            bubble_v.animate.shift(UP * 2.0),
            run_time=1
        )
        self.wait(0.5)

        # Return to level
        self.play(
            level.animate.rotate(10 * DEGREES, about_point=ORIGIN),
            bubble_h.animate.move_to(vial_h.get_center()),
            bubble_v.animate.move_to(vial_v.get_center()),
            run_time=1
        )

        reading = Text("Level Sempurna ✓", font_size=32, color=GREEN).to_edge(DOWN)
        self.play(Write(reading))
        self.wait(1.5)

        self.play(FadeOut(Group(level, labels, reading, title)))


if __name__ == "__main__":
    scene = EngineeringToolsScene()
    scene.run()