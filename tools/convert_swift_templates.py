# DocuCraft — Swift template converter (TSX → JSON layout)
# Menghasilkan posisi absolut deterministik dari aturan layout Swift:
#   px-12 = 48px padding kiri/kanan, pt-6 = 24px header, gap = 24/32/40
# Semua nilai dihitung dari satu sumber aturan agar konsisten antar file.

import json, os

W, H = 1280, 720
PAD = 48            # px-12
GAP_SM = 24         # gap-6
GAP_MD = 32         # gap-8
GAP_LG = 40         # gap-10
HEADER_Y = 24       # pt-6
HEADER_H = 36       # diamond 12 + pt-6

FOOTER_Y = 674      # bottom-8 = 720-32-14(text)
FOOTER_LINE_Y = 687 # line 2px di tengah text
DIAMOND_BR = {"x": 1224, "y": 660}  # bottom-7 (28) right-6 (24), 32px

def shape(id_, x, y, w, h, color, radius=0, rot=None):
    el = {"id": id_, "type": "shape", "position": {"x": x, "y": y, "width": w, "height": h},
          "style": {"color": color, "borderRadius": radius}}
    if rot: el["rotation"] = rot
    return el

def text(id_, x, y, w, h, content, size, color, weight="normal", align=None, lh=None, ls=None):
    style = {"color": color, "fontSize": size, "fontWeight": weight}
    if align: style["textAlign"] = align
    if lh: style["lineHeight"] = lh
    if ls: style["letterSpacing"] = ls
    return {"id": id_, "type": "text", "position": {"x": x, "y": y, "width": w, "height": h},
            "style": style, "content": content}

def image(id_, x, y, w, h, src):
    return {"id": id_, "type": "image", "position": {"x": x, "y": y, "width": w, "height": h},
            "style": {}, "content": src}

def card(id_, x, y, w, h, items, bg="#BFF4FF", color="#111827", fs=16, radius=18):
    return {"id": id_, "type": "card", "position": {"x": x, "y": y, "width": w, "height": h},
            "style": {"backgroundColor": bg, "borderRadius": radius, "color": color, "fontSize": fs},
            "items": items}

def footer(elements, line_color="#111827"):
    elements.append(text("txt_website", PAD, FOOTER_Y, 140, 14, "www.yourwebsite.com", 14, "#6B7280"))
    elements.append(shape("line_footer", PAD + 164, FOOTER_LINE_Y, W - 2*PAD - 164, 2, line_color))
    elements.append(shape("diamond_bottom_right", DIAMOND_BR["x"], DIAMOND_BR["y"], 32, 32, "#111827", rot="45deg"))

def header(elements):
    elements.append(shape("header_diamond", PAD, HEADER_Y, 12, 12, "#111827", rot="45deg"))

def base(layout_id, name, description, font="Albert Sans"):
    return {
        "layoutId": layout_id, "name": name, "description": description,
        "canvas": {"width": W, "height": H, "backgroundColor": "#FFFFFF", "fontFamily": font},
        "elements": [shape("bg_white", 0, 0, W, H, "#FFFFFF")],
        "_schema": {}, "_cssVars": {
            "background-color": "#FFFFFF", "background-text": "#111827",
            "primary-color": "#BFF4FF", "primary-text": "#111827",
            "card-color": "#FFFFFF", "stroke": "#E5E7EB",
        },
    }

UNSPLASH = "https://images.unsplash.com/photo-1522199710521-72d69614c702?w=1200&q=80&auto=format&fit=crop"

# ─────────────────────────── 1. IntroSlideLayout ───────────────────────────
def intro():
    d = base("IntroSlideLayout", "Intro Slide Layout",
             "Intro slide with header, title, subtitle, body, image. If used for last slide, then intro card should be disabled.")
    e = d["elements"]
    header(e)
    e.append(text("txt_title", PAD, 76, 664, 68, "Pitch Deck", 64, "#111827", "semibold", lh=1.05))
    e.append(text("txt_paragraph", PAD, 164, 620, 52, "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.", 16, "#6B7280", lh=1.6))
    e.append(shape("introCard_bg", PAD, 240, 300, 48, "#BFF4FF", 2))
    e.append(shape("introCard_accent", PAD + 16, 252, 8, 24, "#111827"))
    e.append(text("txt_introCard_name", PAD + 40, 255, 140, 18, "John Doe", 16, "#111827", "semibold"))
    e.append(text("txt_introCard_date", PAD + 127, 257, 100, 16, "Jan 1, 2025", 14, "#6B7280"))
    for i in range(3):
        e.append(shape(f"diamond_right_{i+1}", 782, 32 + i*24, 12, 12, "#111827", rot="45deg"))
    e.append(image("img_right_panel", 819, 0, 461, 520, UNSPLASH))
    footer(e, "#E5E7EB")
    d["_schema"] = {"title": "Pitch Deck",
                    "paragraph": "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
                    "introCard": {"enabled": True, "name": "John Doe", "date": "Jan 1, 2025"},
                    "website": "www.yourwebsite.com"}
    return d

# ─────────────────────────── 2. MetricsNumbers ───────────────────────────
def metrics():
    d = base("metrics-numbers", "Metrics Numbers", "Swift: Our Impact in Numbers with three stacked metric cards")
    e = d["elements"]
    header(e)
    e.append(shape("line_center_separator", 640, 0, 1, H, "#0000001A"))
    e.append(text("txt_title", PAD, 84, 420, 106, "Our Impact in Numbers", 48, "#111827", "semibold", lh=1.1))
    e.append(shape("dot_left_circle", PAD, 240, 20, 20, "#111827", 9999))
    e.append(text("txt_leftTitle", PAD + 36, 236, 280, 48, "Proven Results\nThrough Data", 20, "#111827", "semibold", lh=1.2))
    e.append(text("txt_leftBody", PAD, 300, 360, 58, "Lorem ipsum dolor sit amet, consectetur adipiscing elit.", 16, "#6B7280", lh=1.8))
    e.append({"id": "circle_decor", "type": "decoration",
              "position": {"x": 1168, "y": 80, "width": 220, "height": 220},
              "style": {"color": "#00000033", "borderRadius": 9999, "borderColor": "#00000033", "borderWidth": 1}})
    CW = (W - 2*PAD - GAP_MD)          # 1184-32 = 1152 (grid content)
    LX = CW * 0.42                      # left col width
    RX = PAD + int(LX) + GAP_MD         # right col start = 48+484+32 = 564
    RW = W - PAD - RX                   # right col width = 1280-48-564 = 668
    metrics_data = [
        ("10K+", "Total", "Users", "active users across multiple industries"),
        ("150%", "Revenue", "Growth", "year-over-year revenue growth"),
        ("95%", "Customer", "Satisfaction", "retention rate with an average rating of 4.8/5"),
    ]
    for i, (v, l1, l2, desc) in enumerate(metrics_data):
        e.append(card(f"metric_card_{i+1}", RX, 84 + i*184, RW, 160, [{"value": v, "line1": l1, "line2": l2, "description": desc}]))
    footer(e)
    d["_schema"] = {"title": "Our Impact in Numbers", "leftTitle": "Proven Results\nThrough Data",
                    "leftBody": "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
                    "metrics": [{"value": v, "line1": l1, "line2": l2, "description": de} for v, l1, l2, de in metrics_data],
                    "website": "www.yourwebsite.com"}
    return d

# ─────────────────────────── 3. SimpleBulletPointsLayout ───────────────────────────
def simple_bullets():
    d = base("simple-bullet-points-layout", "Simple Bullet Points", "Bullet Points with title and description")
    e = d["elements"]
    header(e)
    e.append(text("txt_title_left", PAD, 100, 568, 106, "Our Commitment", 56, "#111827", "semibold", lh=1.05))
    e.append(text("txt_statement", PAD, 248, 520, 58, "Lorem ipsum dolor sit amet, consectetur adipiscing elit.", 16, "#6B7280", lh=1.8))
    CW = (W - 2*PAD - GAP_LG)   # 1152-40 = 1112
    RX = PAD + int(CW * 0.48)   # right col start = 48+533 = 581
    for i in range(4):
        y = 108 + i*140
        e.append(text(f"txt_point{i+1}_title", RX, y, 500, 28, "Your Title Here", 24, "#111827", "semibold"))
        e.append(text(f"txt_point{i+1}_body", RX, y + 36, 500, 72, "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa.", 16, "#6B7280", lh=1.8))
    footer(e)
    body = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa."
    d["_schema"] = {"title": "Our Commitment", "statement": "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
                    "points": [{"title": "Your Title Here", "body": body} for _ in range(4)],
                    "website": "www.yourwebsite.com"}
    return d

# ─────────────────────────── 4. BulletsWithIconsTitleDescription ───────────────────────────
def bullets_icons():
    d = base("bullet-with-icons-title-description", "Bullet With Icons Title Description",
             "Bullet with icons with title and description and title and description for whole")
    e = d["elements"]
    header(e)
    e.append(text("txt_title_left", PAD, 96, 652, 106, "Our Infographic", 56, "#111827", "semibold", lh=1.05))
    e.append(text("txt_sideHeading", PAD + 688, 100, 300, 20, "Lorem ipsum dolor sit amet,", 16, "#111827", "semibold"))
    e.append(text("txt_sideParagraph", PAD + 688, 132, 300, 56, "Concise paragraph describing context. Keep it short and readable across one or two lines.", 14, "#6B7280", lh=1.6))
    icons = ["https://presenton-public.s3.ap-southeast-1.amazonaws.com/static/icons/bold/graduation-cap-bold.svg",
             "https://presenton-public.s3.ap-southeast-1.amazonaws.com/static/icons/bold/user-bold.svg",
             "https://presenton-public.s3.ap-southeast-1.amazonaws.com/static/icons/bold/calendar-blank-bold.svg",
             "https://presenton-public.s3.ap-southeast-1.amazonaws.com/static/icons/bold/x-bold.svg"]
    col_w = 260; gap = 32
    total = 4*col_w + 3*gap          # 1136
    start_x = (W - total) // 2       # 72
    CY = 310
    for i, url in enumerate(icons):
        x = start_x + i*(col_w+gap)
        cx = x + (col_w-160)//2
        e.append(shape(f"circle_icon_{i+1}", cx, CY, 160, 160, "#BFF4FF", 9999))
        e.append(text(f"txt_icon_title_{i+1}", x, CY+176, col_w, 20, "Lorem ipsum dolor", 16, "#111827", "semibold", align="center"))
        e.append(text(f"txt_icon_desc_{i+1}", x, CY+202, col_w, 48, f"Concise supporting text under the {'first' if i==0 else 'second' if i==1 else 'third' if i==2 else 'fourth'} icon explaining the point.", 13, "#6B7280", lh=1.6, align="center"))
    footer(e)
    d["_schema"] = {"title": "Our Infographic", "sideHeading": "Lorem ipsum dolor sit amet,",
                    "sideParagraph": "Concise paragraph describing context. Keep it short and readable across one or two lines.",
                    "items": [{"title": "Lorem ipsum dolor", "description": f"Concise supporting text under the {w} icon explaining the point."} for w in ("first", "second", "third", "fourth")],
                    "website": "www.yourwebsite.com"}
    return d

# ─────────────────────────── 5. IconBulletListDescription ───────────────────────────
def icon_bullets():
    d = base("icon-bullet-list-description-slide", "Icon Bullet List Description", "Bullet list with title, description, and icon")
    e = d["elements"]
    header(e)
    e.append(text("txt_title", PAD, 84, 900, 106, "Key Product Features", 48, "#111827", "semibold", lh=1.1))
    e.append(text("txt_description", PAD, 208, 760, 50, "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean commodo ligula eget dolor.", 16, "#6B7280", lh=1.6))
    e.append(shape("cyan_band", 0, 560, W, 160, "#BFF4FF"))
    features = [("Customizable Workflows", "Lorem ipsum dolor sit amet, dolor sit amet."),
                ("Multi-Device Access", "Lorem ipsum dolor sit amet."),
                ("Scalable Architecture", "Lorem ipsum dolor sit amet."),
                ("Detailed Reports", "Lorem ipsum dolor sit amet.")]
    col_w = 260; gap = 32
    total = 4*col_w + 3*gap
    start_x = (W - total) // 2
    CY = 320
    for i, (t, b) in enumerate(features):
        x = start_x + i*(col_w+gap)
        e.append(card(f"card_{i+1}", x, CY, col_w, 210, [{"value": "", "line1": t, "line2": "", "description": b}], radius=22, fs=18))
    footer(e)
    d["_schema"] = {"title": "Key Product Features",
                    "description": "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean commodo ligula eget dolor.",
                    "features": [{"title": t, "body": b} for t, b in features],
                    "website": "www.yourwebsite.com"}
    return d

# ─────────────────────────── 6. ImageListDescription ───────────────────────────
def image_list():
    d = base("image-list-description-slide", "Image List Description",
             "List of Images with subtitle and description with one description for the entire page")
    e = d["elements"]
    header(e)
    e.append(text("txt_titleLine1", PAD, 92, 356, 62, "Meet Our", 56, "#111827", "semibold", lh=1.05))
    e.append(text("txt_titleLine2", PAD, 154, 356, 62, "Team", 56, "#111827", "semibold", lh=1.05))
    e.append(text("txt_description", PAD, 278, 300, 80, "Lorem ipsum dolor sit amet, consectetur adipiscing elit.", 16, "#6B7280", lh=1.8))
    CW = (W - 2*PAD - 2*GAP_LG)   # 1280-96-80 = 1104
    RX = PAD + int(CW * 0.36)     # 48+397 = 445
    col_w = (CW - 2*GAP_LG) // 3  # (1104-80)/3 = 341
    for i in range(3):
        x = RX + i*(col_w + GAP_LG)
        e.append(image(f"img_card_{i+1}_photo", x, 92, col_w, 180, UNSPLASH))
        e.append(shape(f"card_{i+1}_panel", x, 272, col_w, 88, "#BFF4FF", 28))
        e.append(text(f"txt_card_{i+1}_title", x + 24, 282, col_w-48, 24, ["Sample Title", "Another Item", "Third Item"][i], 20, "#111827", "semibold"))
        e.append(text(f"txt_card_{i+1}_desc", x + 24, 312, col_w-48, 28, ["Short description for the image or item.", "Concise supporting text.", "Concise supporting text."][i], 14, "#6B7280", lh=1.7))
    footer(e, "#E5E7EB")
    d["_schema"] = {"titleLine1": "Meet Our", "titleLine2": "Team",
                    "description": "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
                    "items": [{"title": "Sample Title", "description": "Short description for the image or item."},
                              {"title": "Another Item", "description": "Concise supporting text."},
                              {"title": "Third Item", "description": "Concise supporting text."}],
                    "website": "www.yourwebsite.com"}
    return d

# ─────────────────────────── 7. TableOfContents ───────────────────────────
def toc():
    d = base("SwiftTableOfContents", "Table Of Contents", "Swift: Table of contents with up to 10 items (title + description)")
    e = d["elements"]
    header(e)
    e.append(text("txt_title", PAD, 84, 800, 106, "Table of Contents", 48, "#111827", "semibold", lh=1.1))
    items = [("Introduction", "A brief description of our company and goals."),
             ("Our Team", "Leadership and core contributors."),
             ("Timeline", "High-level execution plan and milestones."),
             ("Recommendations", "Key suggestions based on initial requirements."),
             ("Solution", "What we propose and why it works."),
             ("Market", "Audience, segments, and opportunity size."),
             ("Business Model", "How we create and capture value."),
             ("Conclusion", "Closing notes and next steps."),
             ("Business Model", "How we create and capture value."),
             ("Conclusion", "Closing notes and next steps.")]
    CW = (W - 2*PAD - 2*GAP_MD)  # 1184-64 = 1120
    col_w = (CW - GAP_MD) // 2   # (1120-32)/2 = 544
    for i, (t, de) in enumerate(items[:10]):
        col = i // 5
        row = i % 5
        x = PAD + col*(col_w + GAP_MD)
        y = 210 + row*92
        e.append(text(f"num_{i+1:02d}", x, y, 72, 50, f"{i+1:02d}", 48, "#BFF4FF", "semibold"))
        e.append(text(f"toc_item_{i+1}_title", x + 88, y + 2, 340, 28, t, 22, "#111827", "semibold", lh=1.2))
        e.append(text(f"toc_item_{i+1}_desc", x + 88, y + 36, 340, 24, de, 14, "#6B7280", lh=1.6))
        e.append(shape(f"toc_item_{i+1}_divider", x, y + 74, col_w, 1, "#E5E7EB"))
    footer(e)
    d["_schema"] = {"title": "Table of Contents", "items": [{"title": t, "description": de} for t, de in items],
                    "website": "www.yourwebsite.com"}
    return d

# ─────────────────────────── 8. Timeline ───────────────────────────
def timeline():
    d = base("Timeline", "Timeline", "Timeline of cards with title, subtitle banner")
    e = d["elements"]
    header(e)
    for i in range(3):
        e.append(shape(f"diamond_right_{i+1}", 1224, 64 + i*24, 12, 12, "#111827", rot="45deg"))
    e.append(text("txt_title", 240, 92, 800, 106, "Our Journey at a Glance", 48, "#111827", "semibold", lh=1.1, align="center"))
    e.append(shape("subtitle_banner", 280, 220, 720, 44, "#BFF4FF", 6))
    e.append(text("txt_subtitle", 300, 231, 680, 22, "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa.", 16, "#6B7280", align="center"))
    CW = W - 2*PAD
    line_y = 420
    e.append(shape("timeline_line", PAD, line_y, CW, 4, "#BFF4FF"))
    items = [("2018", "Founded in 2020"), ("2019", "First Product in 2021"),
             ("2020", "Key Milestone in 2022"), ("2021", "Global Expansion in 2024")]
    gap = GAP_LG
    col_w = 260
    total = 4*col_w + 3*gap
    start_x = (W - total) // 2
    for i, (yr, hd) in enumerate(items):
        cx = start_x + i*(col_w + gap) + col_w//2
        e.append(shape(f"year_badge_{i+1}", cx-40, 340, 80, 36, "#111827", 6))
        e.append(text(f"txt_year_{i+1}", cx-28, 348, 56, 20, yr, 16, "#FFFFFF", "semibold", align="center"))
        e.append(shape(f"dot_{i+1}", cx-10, line_y-8, 20, 20, "#FFFFFF", 9999))
        e.append(card(f"card_{i+1}", cx-col_w//2, line_y+28, col_w, 150,
                      [{"value": "", "line1": hd, "line2": "", "description": "Lorem ipsum dolor"}],
                      bg="#FFFFFF", radius=16, fs=18))
    footer(e)
    d["_schema"] = {"title": "Our Journey at a Glance",
                    "subtitle": "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa.",
                    "items": [{"year": yr, "heading": hd, "body": "Lorem ipsum dolor"} for yr, hd in items],
                    "website": "www.yourwebsite.com"}
    return d

# ─────────────────────────── 9. TableorChart ───────────────────────────
def table_or_chart():
    d = base("tableorChart", "Table Or Chart", "Swift: Generic data table with option to render a chart (bar, horizontalBar, line, pie)")
    e = d["elements"]
    header(e)
    e.append(text("txt_title", PAD, 84, 900, 106, "Data Table or Chart", 48, "#111827", "semibold", lh=1.1))
    e.append(text("txt_description", PAD, 208, 900, 50, "Present structured information in a flexible table or visualize it with a chart.", 16, "#6B7280", lh=1.6))
    TW = W - 2*PAD          # 1184
    TX, TY = PAD, 300
    e.append(shape("table_wrapper", TX, TY, TW, 280, "#BFF4FF", 12))
    e.append(shape("table_bg", TX+20, TY+20, TW-40, 240, "#FFFFFF", 8))
    rows = [("Row A", "✓", "-"), ("Row B", "Text", "123"), ("Row C", "More text", "456")]
    hdr_y = TY + 20
    row_h = 48
    e.append(shape("table_header_row", TX+20, hdr_y, TW-40, 44, "#BFF4FF"))
    for c in range(3):
        e.append(text(f"txt_col_{c+1}", TX+40+c*312, hdr_y+10, 300, 20, f"Column {c+1}", 14, "#111827", "semibold"))
    for r, (c1, c2, c3) in enumerate(rows):
        y = hdr_y + 44 + r*row_h
        bg = "#BFF4FF" if r % 2 == 0 else "#F3F4F6"
        e.append(shape(f"table_row_{r+1}", TX+20, y, TW-40, row_h, bg))
        for c, val in enumerate((c1, c2, c3)):
            e.append(text(f"txt_r{r+1}c{c+1}", TX+40+c*312, y+12, 300, 20, val, 14, "#6B7280"))
    footer(e)
    d["_schema"] = {"title": "Data Table or Chart",
                    "description": "Present structured information in a flexible table or visualize it with a chart.",
                    "mode": "table",
                    "columns": ["Column 1", "Column 2", "Column 3"],
                    "rows": [{"cells": [c1, c2, c3]} for c1, c2, c3 in rows],
                    "chart": {"type": "line", "data": [{"label": "A", "value": 60}, {"label": "B", "value": 42}, {"label": "C", "value": 75}, {"label": "D", "value": 30}], "showLabels": True},
                    "website": "www.yourwebsite.com"}
    return d

GENERATORS = {
    "IntroSlideLayout": intro,
    "MetricsNumbers": metrics,
    "SimpleBulletPointsLayout": simple_bullets,
    "BulletsWithIconsTitleDescription": bullets_icons,
    "IconBulletListDescription": icon_bullets,
    "ImageListDescription": image_list,
    "TableOfContents": toc,
    "Timeline": timeline,
    "TableorChart": table_or_chart,
}

def main():
    out_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "templates", "swift")
    out_dir = os.path.abspath(out_dir)
    for name, gen in GENERATORS.items():
        data = gen()
        path = os.path.join(out_dir, f"{name}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"Wrote {name}.json ({len(data['elements'])} elements)")

if __name__ == "__main__":
    main()
