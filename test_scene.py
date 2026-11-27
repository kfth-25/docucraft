from manimlib import *

class TestScene(Scene):
    def construct(self):
        # Create a simple circle
        circle = Circle(radius=1, stroke_color=BLUE, fill_opacity=0.5)

        # Create a square
        square = Square(side_length=2, stroke_color=GREEN, fill_opacity=0.5)
        square.shift(RIGHT * 3)

        # Create text
        text = Text("ManimGL Works!", font_size=48)
        text.shift(DOWN * 2)

        # Animations
        self.play(ShowCreation(circle))
        self.wait(0.5)
        self.play(circle.animate.shift(LEFT * 3))
        self.wait(0.5)
        self.play(ShowCreation(square))
        self.wait(0.5)
        self.play(Write(text))
        self.wait(1)

        # Transform circle to square
        self.play(Transform(circle, square))
        self.wait(1)

        # Fade out
        self.play(FadeOut(circle), FadeOut(text))
        self.wait(0.5)

if __name__ == "__main__":
    scene = TestScene()
    scene.run()