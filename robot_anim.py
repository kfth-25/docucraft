from manimlib import *
import numpy as np

class RobotScene(Scene):
    def construct(self):
        # Title
        title = Text("Robot Animation dengan Keqo", font_size=48)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait(0.5)

        # Build robot parts
        self.build_robot()

        # Animate robot
        self.animate_robot()

        # Closing
        self.play(FadeOut(Group(self.robot, title)))
        end_text = Text("Robot selesai! 🤖", font_size=48)
        self.play(Write(end_text))
        self.wait(1)
        self.play(FadeOut(end_text))

    def build_robot(self):
        # Body parts
        # Head
        head = Square(side_length=1.2, color=BLUE_E, fill_opacity=0.8)
        head.move_to(UP * 2.5)

        # Eyes
        left_eye = Circle(radius=0.15, color=YELLOW, fill_opacity=1).move_to(head.get_center() + LEFT * 0.3 + UP * 0.2)
        right_eye = Circle(radius=0.15, color=YELLOW, fill_opacity=1).move_to(head.get_center() + RIGHT * 0.3 + UP * 0.2)

        # Antenna
        antenna_base = Line(head.get_top(), head.get_top() + UP * 0.5, color=GREY, stroke_width=4)
        antenna_tip = Circle(radius=0.1, color=RED, fill_opacity=1).move_to(head.get_top() + UP * 0.6)

        # Body
        body = Rectangle(width=2, height=2.5, color=BLUE_D, fill_opacity=0.8)
        body.move_to(ORIGIN)

        # Body details
        chest_light = Circle(radius=0.3, color=GREEN, fill_opacity=0.9).move_to(body.get_center() + UP * 0.5)
        panel = Rectangle(width=1.5, height=1, color=GREY_E, fill_opacity=0.5).move_to(body.get_center() + DOWN * 0.3)

        # Left arm
        l_upper_arm = Rectangle(width=0.4, height=1.2, color=BLUE_E, fill_opacity=0.8)
        l_upper_arm.move_to(body.get_left() + LEFT * 0.7 + UP * 0.5).rotate(-30 * DEGREES)
        l_lower_arm = Rectangle(width=0.35, height=1, color=BLUE_D, fill_opacity=0.8)
        l_lower_arm.move_to(l_upper_arm.get_bottom() + DOWN * 0.5 + LEFT * 0.1).rotate(-20 * DEGREES)
        l_hand = Circle(radius=0.25, color=GREY_C, fill_opacity=0.8).move_to(l_lower_arm.get_bottom() + DOWN * 0.3)

        # Right arm
        r_upper_arm = Rectangle(width=0.4, height=1.2, color=BLUE_E, fill_opacity=0.8)
        r_upper_arm.move_to(body.get_right() + RIGHT * 0.7 + UP * 0.5).rotate(30 * DEGREES)
        r_lower_arm = Rectangle(width=0.35, height=1, color=BLUE_D, fill_opacity=0.8)
        r_lower_arm.move_to(r_upper_arm.get_bottom() + DOWN * 0.5 + RIGHT * 0.1).rotate(20 * DEGREES)
        r_hand = Circle(radius=0.25, color=GREY_C, fill_opacity=0.8).move_to(r_lower_arm.get_bottom() + DOWN * 0.3)

        # Left leg
        l_upper_leg = Rectangle(width=0.5, height=1.3, color=BLUE_E, fill_opacity=0.8)
        l_upper_leg.move_to(body.get_bottom() + LEFT * 0.5 + DOWN * 0.8)
        l_lower_leg = Rectangle(width=0.45, height=1.2, color=BLUE_D, fill_opacity=0.8)
        l_lower_leg.move_to(l_upper_leg.get_bottom() + DOWN * 0.7)
        l_foot = Rectangle(width=0.7, height=0.3, color=GREY_B, fill_opacity=0.9).move_to(l_lower_leg.get_bottom() + DOWN * 0.2)

        # Right leg
        r_upper_leg = Rectangle(width=0.5, height=1.3, color=BLUE_E, fill_opacity=0.8)
        r_upper_leg.move_to(body.get_bottom() + RIGHT * 0.5 + DOWN * 0.8)
        r_lower_leg = Rectangle(width=0.45, height=1.2, color=BLUE_D, fill_opacity=0.8)
        r_lower_leg.move_to(r_upper_leg.get_bottom() + DOWN * 0.7)
        r_foot = Rectangle(width=0.7, height=0.3, color=GREY_B, fill_opacity=0.9).move_to(r_lower_leg.get_bottom() + DOWN * 0.2)

        # Store references for animation
        self.head = head
        self.left_eye = left_eye
        self.right_eye = right_eye
        self.antenna_base = antenna_base
        self.antenna_tip = antenna_tip
        self.body = body
        self.chest_light = chest_light
        self.panel = panel
        self.l_upper_arm = l_upper_arm
        self.l_lower_arm = l_lower_arm
        self.l_hand = l_hand
        self.r_upper_arm = r_upper_arm
        self.r_lower_arm = r_lower_arm
        self.r_hand = r_hand
        self.l_upper_leg = l_upper_leg
        self.l_lower_leg = l_lower_leg
        self.l_foot = l_foot
        self.r_upper_leg = r_upper_leg
        self.r_lower_leg = r_lower_leg
        self.r_foot = r_foot

        # Group all parts
        self.robot = Group(
            head, left_eye, right_eye, antenna_base, antenna_tip,
            body, chest_light, panel,
            l_upper_arm, l_lower_arm, l_hand,
            r_upper_arm, r_lower_arm, r_hand,
            l_upper_leg, l_lower_leg, l_foot,
            r_upper_leg, r_lower_leg, r_foot
        )

        # Show robot assembly
        self.play(ShowCreation(head), ShowCreation(left_eye), ShowCreation(right_eye))
        self.play(ShowCreation(antenna_base), ShowCreation(antenna_tip))
        self.play(ShowCreation(body), ShowCreation(chest_light), ShowCreation(panel))
        self.play(
            ShowCreation(l_upper_arm), ShowCreation(l_lower_arm), ShowCreation(l_hand),
            ShowCreation(r_upper_arm), ShowCreation(r_lower_arm), ShowCreation(r_hand),
        )
        self.play(
            ShowCreation(l_upper_leg), ShowCreation(l_lower_leg), ShowCreation(l_foot),
            ShowCreation(r_upper_leg), ShowCreation(r_lower_leg), ShowCreation(r_foot),
        )
        self.wait(0.5)

    def animate_robot(self):
        # Blink eyes
        for _ in range(3):
            self.play(
                self.left_eye.animate.scale(0.1).set_color(BLUE_E),
                self.right_eye.animate.scale(0.1).set_color(BLUE_E),
                run_time=0.1
            )
            self.play(
                self.left_eye.animate.scale(10).set_color(YELLOW),
                self.right_eye.animate.scale(10).set_color(YELLOW),
                run_time=0.1
            )
            self.wait(0.3)

        # Wave right arm
        for _ in range(3):
            self.play(
                self.r_upper_arm.animate.rotate(-60 * DEGREES, about_point=self.r_upper_arm.get_top()),
                self.r_lower_arm.animate.rotate(-40 * DEGREES, about_point=self.r_lower_arm.get_top()),
                run_time=0.4
            )
            self.play(
                self.r_upper_arm.animate.rotate(60 * DEGREES, about_point=self.r_upper_arm.get_top()),
                self.r_lower_arm.animate.rotate(40 * DEGREES, about_point=self.r_lower_arm.get_top()),
                run_time=0.4
            )

        # Chest light pulse
        for _ in range(4):
            self.play(self.chest_light.animate.scale(1.5).set_opacity(0.3), run_time=0.3)
            self.play(self.chest_light.animate.scale(1/1.5).set_opacity(0.9), run_time=0.3)

        # Robot dance - move body side to side
        for _ in range(2):
            self.play(self.robot.animate.shift(RIGHT * 1), run_time=0.5)
            self.play(self.robot.animate.shift(LEFT * 2), run_time=0.5)
            self.play(self.robot.animate.shift(RIGHT * 1), run_time=0.5)

        # Jump
        self.play(self.robot.animate.shift(UP * 1.5), run_time=0.4, rate_func=there_and_back)
        self.play(self.robot.animate.shift(UP * 1.5), run_time=0.4, rate_func=there_and_back)

        # Antenna wiggle
        for _ in range(4):
            self.play(self.antenna_tip.animate.shift(LEFT * 0.2), run_time=0.2)
            self.play(self.antenna_tip.animate.shift(RIGHT * 0.4), run_time=0.2)
            self.play(self.antenna_tip.animate.shift(LEFT * 0.2), run_time=0.2)

        # Leg walking motion
        for _ in range(4):
            self.play(
                self.l_lower_leg.animate.shift(UP * 0.3),
                self.r_lower_leg.animate.shift(DOWN * 0.3),
                self.l_foot.animate.shift(UP * 0.3),
                self.r_foot.animate.shift(DOWN * 0.3),
                run_time=0.3
            )
            self.play(
                self.l_lower_leg.animate.shift(DOWN * 0.3),
                self.r_lower_leg.animate.shift(UP * 0.3),
                self.l_foot.animate.shift(DOWN * 0.3),
                self.r_foot.animate.shift(UP * 0.3),
                run_time=0.3
            )

        # Spin around
        self.play(Rotate(self.robot, angle=2*PI, about_point=ORIGIN), run_time=3)
        self.wait(0.5)

        # Final pose - arms up
        self.play(
            self.l_upper_arm.animate.rotate(-90 * DEGREES, about_point=self.l_upper_arm.get_top()),
            self.r_upper_arm.animate.rotate(90 * DEGREES, about_point=self.r_upper_arm.get_top()),
            run_time=0.5
        )
        self.wait(0.5)


if __name__ == "__main__":
    scene = RobotScene()
    scene.run()