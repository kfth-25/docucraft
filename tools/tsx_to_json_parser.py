#!/usr/bin/env python3
"""
Parser untuk convert presenton-templates/*.tsx → assets/templates/*.json
Membaca Zod schema + JSX layout → menghasilkan JSON layout untuk Flutter.
"""

import json, re, os
from pathlib import Path

TEMPLATE_ROOT = Path("presenton-templates")
OUTPUT_ROOT   = Path("assets/templates")

# CSS var → default color mapping
CSS_VAR_DEFAULTS = {
    "background-color": "#FFFFFF",
    "background-text": "#111827",
    "primary-color": "#1F8A2E",
    "primary-text": "#111827",
    "stroke": "#E5E7EB",
    "card-color": "#FFFFFF",
    "body-font-family": "Inter",
    "heading-font-family": "Inter",
}

# Tailwind spacing → px
TAILWIND_PX = {
    "px-12": 48, "px-10": 40, "px-6": 24, "px-4": 16, "px-2": 8,
    "pt-6": 24, "pt-4": 16, "pt-2": 8,
    "pb-10": 40, "pb-2": 8,
    "mt-5": 20, "mt-4": 16, "mt-6": 24, "mt-8": 32,
    "mb-2": 8, "mb-8": 32,
    "gap-3": 12, "gap-4": 16, "gap-8": 32, "gap-10": 40,
}

def extract_css_var(style_str):
    """Ekstrak warna dari 'var(--xxx, #HEX)' pattern."""
    m = re.search(r'var\(--([^,]+),\s*([^)]+)\)', style_str)
    if not m:
        # Cek langsung hex
        m2 = re.search(r'#([0-9A-Fa-f]{6})', style_str)
        if m2:
            return f"#{m2.group(1)}"
        return None
    var_name = m.group(1).strip()
    default = m.group(2).strip()
    if default.startswith('#'):
        return default
    if default.startswith("'") or default.startswith('"'):
        return default.strip("'\"")
    # Non-hex default (mis. 'rgba(0,0,0,0.1)') → fallback ke CSS_VAR_DEFAULTS
    return CSS_VAR_DEFAULTS.get(var_name, "#000000")

def resolve_color(colors_map, color_str):
    """Resolve warna dari CSS var ke hex final."""
    if not color_str:
        return None
    color_str = color_str.strip()
    if color_str.startswith('#'):
        return color_str
    # var(--xxx) tanpa default → cari di colors_map
    m = re.search(r'var\(--([^)]+)\)', color_str)
    if m:
        var_name = m.group(1).strip()
        if var_name in colors_map:
            return colors_map[var_name]
        return CSS_VAR_DEFAULTS.get(var_name, "#000000")
    # Langsung hex
    m2 = re.search(r'#([0-9A-Fa-f]{6})', color_str)
    if m2:
        return f"#{m2.group(1)}"
    return None

def extract_tailwind_classes(class_str):
    """Ekstrak posisi dari Tailwind className.

    Supports:
      - Arbitrary values:  top-[100px], left-[36px], w-[60%]
      - Tailwind defaults: top-10 (= 40px), p-6 (= 24px)
    """
    pos = {}
    # max-w-[1280px]
    m = re.search(r'max-w-\[(\d+)px\]', class_str)
    if m:
        pos['maxWidth'] = int(m.group(1))
    # max-h-[720px]
    m = re.search(r'max-h-\[(\d+)px\]', class_str)
    if m:
        pos['maxHeight'] = int(m.group(1))
    # text-[XXpx]
    text_matches = re.findall(r'text-\[(\d+)px\]', class_str)
    if text_matches:
        pos['fontSize'] = int(text_matches[0])
    # font-semibold / font-bold / font-medium
    if 'font-semibold' in class_str:
        pos['fontWeight'] = 'semibold'
    elif 'font-bold' in class_str:
        pos['fontWeight'] = 'bold'
    elif 'font-medium' in class_str:
        pos['fontWeight'] = 'medium'
    # rounded-sm / rounded-lg / rounded-full
    if 'rounded-full' in class_str:
        pos['borderRadius'] = 'full'
    elif 'rounded-lg' in class_str:
        pos['borderRadius'] = 12
    elif 'rounded-sm' in class_str:
        pos['borderRadius'] = 4
    # absolute positioning
    if 'absolute' in class_str:
        pos['absolute'] = True
    # top / left / right / bottom — arbitrary values: top-[XXpx]
    for side in ['top', 'left', 'right', 'bottom']:
        arb = re.search(rf'{side}-\[(\d+)px\]', class_str)
        if arb:
            pos[side] = int(arb.group(1))
        else:
            m = re.search(rf'{side}-(\d+)', class_str)
            if m:
                pos[side] = int(m.group(1)) * 4  # tailwind default spacing scale
    # w-[XX%] / h-[XX%]
    m = re.search(r'w-\[(\d+)%\]', class_str)
    if m:
        pos['widthPct'] = int(m.group(1))
    m = re.search(r'h-\[(\d+)%\]', class_str)
    if m:
        pos['heightPct'] = int(m.group(1))
    # w-[XXpx] / h-[XXpx]
    m = re.search(r'w-\[(\d+)px\]', class_str)
    if m:
        pos['widthPx'] = int(m.group(1))
    m = re.search(r'h-\[(\d+)px\]', class_str)
    if m:
        pos['heightPx'] = int(m.group(1))
    # gap-[XXpx]
    m = re.search(r'gap-\[(\d+)px\]', class_str)
    if m:
        pos['gapPx'] = int(m.group(1))
    return pos

def extract_zod_fields(content):
    """Ekstrak field Zod schema dengan default values."""
    fields = {}
    # Pattern 1: field-name: z.string().default("VALUE") — single line
    for m in re.finditer(r'(\w+):\s*z\.\w+\([^)]*\)\.default\(([^)]+)\)', content):
        name = m.group(1)
        default = m.group(2).strip().strip("'\"")
        fields[name] = default

    # Pattern 2: multi-line .default() — z.string().\n.default("VALUE")
    for m in re.finditer(r'(\w+):[\s\S]{0,200}?\.default\(\s*\n?\s*["\']([^"\']+)["\']\s*\)', content):
        name = m.group(1)
        if name not in fields:
            default = m.group(2).strip()
            fields[name] = default

    # Nested objects (introCard, media, etc)
    for m in re.finditer(r'(\w+):\s*z\.object\(\{', content):
        name = m.group(1)
        if name not in fields:
            fields[name] = {}
    return fields

def extract_colors_from_content(content):
    """Ekstrak semua CSS var colors dari content."""
    colors = {}
    for m in re.finditer(r'var\(--([^,]+),\s*([^)]+)\)', content):
        var_name = m.group(1).strip()
        default = m.group(2).strip()
        if default.startswith('#') or (default.startswith("'") and len(default) > 3):
            colors[var_name] = default.strip("'\"")
    return colors

def extract_font_family(content):
    """Ekstrak font family dari CSS var."""
    m = re.search(r'var\(--body-font-family,\s*([^)]+)\)', content)
    if not m:
        m = re.search(r'var\(--heading-font-family,\s*([^)]+)\)', content)
    if m:
        font = m.group(1).strip().strip("'\"")
        return font
    return "Inter"

def generate_elements_from_jsx(content, colors=None, schema_fields=None):
    """
    Generate elemen layout dari JSX content.
    Handles flex centering + absolute positioning.
    """
    if colors is None:
        colors = {}
    elements = []
    idx = 0

    # ── FLEX CONTAINER DETECTION ──
    # Find all div containers and detect if they use flex centering
    flex_containers = []  # list of (start, end, classes, style_info)
    for m in re.finditer(r'<div\s+className="([^"]*)"', content):
        classes = m.group(1)
        start = m.start()
        # Find the next <div closing or the template root closing
        # Look ahead for style info
        after = content[m.end():m.end()+400]
        style_m = re.search(r'style=\{\{([^}]+)\}\}', after)
        style_str = style_m.group(1) if style_m else ""
        # Parse container size from classes
        cw = 1280  # default
        ch = 720
        w_m = re.search(r'w-\[(\d+)px\]', classes)
        h_m = re.search(r'h-\[(\d+)px\]', classes)
        if w_m: cw = int(w_m.group(1))
        if h_m: ch = int(h_m.group(1))
        # Detect flex + centering
        is_flex = 'flex' in classes or 'grid' in classes
        center_x = 'justify-center' in classes or 'place-items-center' in classes
        center_y = 'items-center' in classes or 'place-items-center' in classes
        align_end_x = 'justify-end' in classes
        align_end_y = 'items-end' in classes
        # Detect text alignment within non-flex containers
        text_center = 'text-center' in classes
        text_right = 'text-right' in classes
        flex_containers.append({
            'start': start, 'classes': classes,
            'cw': cw, 'ch': ch,
            'is_flex': is_flex, 'center_x': center_x, 'center_y': center_y,
            'align_end_x': align_end_x, 'align_end_y': align_end_y,
            'text_center': text_center, 'text_right': text_right,
        })

    def _get_nearest_flex_context(pos):
        """Find nearest layout ancestor — any container with flex/centering/padding."""
        best = None
        last_candidate = None
        for fc in flex_containers:
            if fc['start'] < pos:
                # Container dengan flex/center/padding = layout context
                has_padding = bool(re.search(r'p[xy]?-\[(\d+)px\]', fc['classes']))
                if fc['is_flex'] or fc['center_x'] or fc['center_y'] or has_padding:
                    best = fc
                last_candidate = fc
        # Jika tidak ada layout context, gunakan container terakhir
        if best is None and last_candidate is not None:
            best = last_candidate
        return best

    # ── HEURISTIC: warna text default berdasarkan brightness canvas bg ──
    def _is_dark_bg(bg_hex):
        if not bg_hex: return False
        h = bg_hex.replace('#','')
        if len(h) < 6: return False
        r, g, b = int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)
        return (r*0.299 + g*0.587 + b*0.114) < 128
    dark_canvas = _is_dark_bg(colors.get('background-color'))

    # ── TEXT ELEMENT EXTRACTION ──
    text_elements = [
        ('h1', 48),
        ('h2', 36),
        ('h3', 28),
        ('p', 16),
        ('span', 14),
        ('button', 16),
    ]

    # Collect text elements with their vertical order within the flex context
    raw_texts = []  # (tag, content, classes, match_pos, default_size)

    for tag, default_size in text_elements:
        pattern = rf'<{tag}(?:[^>]*className="([^"]*)")?[^>]*>\s*([^<]{{1,1000}}?)\s*</{tag}>'
        for m in re.finditer(pattern, content):
            classes = m.group(1) or ""
            text_content = m.group(2).strip()
            if not text_content or len(text_content) < 2:
                continue

            # ── DEFAULT FIELD VALUES (fallback jika schema kosong) ──
            _DEFAULT_FIELDS = {
                'title': 'Presentation Title',
                'paragraph': 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
                'companyName': 'Company Name',
                'website': 'www.example.com',
                'name': 'John Doe',
                'date': 'January 2025',
                'subtitle': 'Subtitle text here',
                'description': 'Description text here',
                'introCard': {'enabled': True, 'name': 'John Doe', 'date': 'Jan 1, 2025'},
                '__companyName__': 'Company',
            }

            # ── RESOLVE: Replace {slideData?.xxx} dengan default value ──
            def resolve_expr(match):
                expr = match.group(0)
                # ── Pattern 1: __companyName__ atau __image_url__ ──
                dm = re.search(r'__([a-zA-Z_]+)__', expr)
                if dm:
                    field = dm.group(0)
                    if field in schema_fields:
                        return str(schema_fields[field])
                    if field in _DEFAULT_FIELDS and not isinstance(_DEFAULT_FIELDS[field], dict):
                        return str(_DEFAULT_FIELDS[field])
                # ── Pattern 2: nested slideData?.introCard?.name ──
                nested = re.findall(r'slideData(?:\s+as\s+any)?\??\.(\w+)', expr)
                if nested:
                    # Ambil last field (child) — introCard?.name -> "name"
                    last = nested[-1]
                    # Coba cari di schema_fields langsung
                    if last in schema_fields:
                        return str(schema_fields[last])
                    # Coba nested lookup
                    for nf in nested[:-1]:
                        if nf in schema_fields and isinstance(schema_fields[nf], dict):
                            sub = schema_fields[nf]
                            if last in sub:
                                return str(sub[last])
                    # Fallback ke _DEFAULT_FIELDS
                    if last in _DEFAULT_FIELDS and not isinstance(_DEFAULT_FIELDS[last], dict):
                        return str(_DEFAULT_FIELDS[last])
                # ── Pattern 3: simple slideData?.title ──
                fm = re.search(r'slideData(?:\s+as\s+any)?\??\.(\w+)', expr)
                if fm:
                    field = fm.group(1)
                    if field in schema_fields and isinstance(schema_fields[field], dict):
                        return str(schema_fields[field])
                    if field in schema_fields:
                        return str(schema_fields[field])
                    if field in _DEFAULT_FIELDS and not isinstance(_DEFAULT_FIELDS[field], dict):
                        return str(_DEFAULT_FIELDS[field])
                    # Fallback: use humanized field name
                    return field.replace('_', ' ').title()
                return ''

            text_content = re.sub(r'\{[^}]*slideData[^}]*\}', resolve_expr, text_content)
            # Bersihkan sisa expression lain
            text_content = re.sub(r'\{[^}]*\}', '', text_content).strip()
            if not text_content or len(text_content) < 2:
                continue

            pos_info = extract_tailwind_classes(classes)

            # ── INLINE STYLE COLOR ──
            # Baca style={{ color: "var(--xxx,#HEX)" }} atau style={{ color: "#HEX" }}
            # Dari posisi tag hingga penutupnya
            tag_end = content.find('>', m.start())
            inline_style = content[m.start():tag_end + 1] if tag_end != -1 else ''
            style_m = re.search(r'style=\{\{\s*color:\s*["\']?([^"\'}]+)["\']?\s*\}', inline_style)
            inline_color = None
            if style_m:
                color_expr = style_m.group(1).strip()
                cm = re.search(r'var\(--([^,]+),\s*([^)]+)\)', color_expr)
                if cm:
                    var_name, default = cm.group(1).strip(), cm.group(2).strip()
                    if default.startswith('#'):
                        inline_color = default
                    else:
                        inline_color = colors.get(var_name, CSS_VAR_DEFAULTS.get(var_name, '#111827'))
                elif color_expr.startswith('#'):
                    inline_color = color_expr

            # ── FLEX-AWARE POSITIONING ──
            fc = _get_nearest_flex_context(m.start())
            w = pos_info.get('widthPx', 400)
            h = pos_info.get('heightPx', default_size + 10)

            x = pos_info.get('left', 0) or 0
            y = pos_info.get('top', 0) or 0

            # Hitung margin atas dari elemen ini
            mt_m = re.search(r'mt-\[(\d+)px\]', classes)
            margin_top = int(mt_m.group(1)) if mt_m else 0

            if fc is not None and not pos_info.get('left') and not pos_info.get('top'):
                cw, ch = fc['cw'], fc['ch']
                if fc['center_x']:
                    x = (cw - w) // 2
                if fc['center_y']:
                    y = (ch - h) // 2
                elif fc['align_end_y']:
                    y = ch - h
                if fc['text_center'] and not fc['center_x']:
                    x = (cw - w) // 2
                # Container pakai padding → pakai padding sebagai offset
                if not fc['center_x'] and not fc['center_y']:
                    px = re.search(r'px-\[(\d+)px\]', fc['classes'])
                    py = re.search(r'py-\[(\d+)px\]', fc['classes'])
                    if px: x = int(px.group(1))
                    if py: y = int(py.group(1))
            # Margin atas → offset dari posisi saat ini
            y += margin_top

            if 'right' in pos_info and not pos_info.get('left'):
                x = 1280 - pos_info['right'] - w
            if 'bottom' in pos_info and not pos_info.get('top'):
                y = 720 - pos_info['bottom'] - h

            # Font size dari className
            font_size = default_size
            if 'fontSize' in pos_info:
                font_size = pos_info['fontSize']

            # Warna dari inline style ATAU className ATAU heuristic canvas bg
            text_color = inline_color if inline_color else ('#F5F5F5' if dark_canvas else '#111827')
            if inline_color is None:
                if 'text-white' in classes:
                    text_color = '#FFFFFF'
                elif 'text-on-surface' in classes:
                    text_color = '#191C1D'
                elif 'text-primary' in classes:
                    text_color = colors.get('primary-color', '#111827')
                elif 'text-gray-500' in classes or 'text-secondary' in classes:
                    text_color = '#6B7280'

            elements.append({
                "id": f"txt_{tag}_{idx}",
                "type": "text",
                "position": {"x": x, "y": y, "width": w, "height": h},
                "style": {
                    "color": text_color,
                    "fontSize": font_size,
                    "fontWeight": "normal"
                },
                "content": text_content
            })
            idx += 1

    # ── Extract div/section dengan background (shape/decoration) ──
    div_starts = list(re.finditer(r'<div[\s\n]+className="([^"]*)"', content))

    for m in div_starts:
        classes = m.group(1)
        # Cari style={{ }} dalam 300 karakter setelah className
        after = content[m.end():m.end() + 300]
        style_m = re.search(r'style=\{\{([^}]+)\}\}', after)
        styles = style_m.group(1) if style_m else ""

        pos_info = extract_tailwind_classes(classes)

        # Cek apakah punya background — ambil nilai setelah 'backgroundColor:'
        bg = None
        if 'backgroundColor' in styles:
            bg_match = re.search(r'backgroundColor:\s*[\'"]?var\(--([^,]+),\s*([^)\'"]+)[\'"]?', styles)
            if bg_match:
                var_name = bg_match.group(1).strip()
                default = bg_match.group(2).strip()
                # Resolve: cek colors map dulu, fallback default
                bg = colors.get(var_name, default if default.startswith('#') else "#000000")
            else:
                # Bisa jadi hex langsung
                hex_m = re.search(r'backgroundColor:\s*[\'"]?(#[0-9A-Fa-f]{6})', styles)
                if hex_m:
                    bg = hex_m.group(1)

        if 'absolute' in classes or bg:
            idx += 1
            el_type = 'shape' if bg and bg != 'transparent' else 'decoration'
            # Hitung posisi dari className
            x = pos_info.get('left', 0) or 0
            y = pos_info.get('top', 0) or 0
            w = pos_info.get('widthPx', 100)
            h = pos_info.get('heightPx', 50)

            # Handle right-based positioning: x = 1280 - right - width
            if 'right' in pos_info and not pos_info.get('left'):
                x = 1280 - pos_info['right'] - w
            # Handle bottom-based positioning: y = 720 - bottom - height
            if 'bottom' in pos_info and not pos_info.get('top'):
                y = 720 - pos_info['bottom'] - h
            # Handle widthPct: w = 1280 * pct / 100
            if pos_info.get('widthPct'):
                w = int(1280 * pos_info['widthPct'] / 100)
                if 'right' in pos_info and not pos_info.get('left'):
                    x = 1280 - pos_info['right'] - w
            # Handle heightPct
            if pos_info.get('heightPct'):
                h = int(720 * pos_info['heightPct'] / 100)

            elements.append({
                "id": f"el_{idx}",
                "type": el_type,
                "position": {"x": x, "y": y, "width": w, "height": h},
                "style": {
                    "color": resolve_color(colors, bg) or "#000000",
                    "borderRadius": pos_info.get('borderRadius', 0) if pos_info.get('borderRadius') != 'full' else 9999,
                }
            })

    return elements

def parse_tsx_file(tsx_path):
    """Parse 1 file .tsx → dict JSON layout."""
    content = tsx_path.read_text(encoding='utf-8', errors='replace')
    # Sanitize smart quotes → ASCII (invalid UTF-8 / JSON chars)
    content = (content
        .replace('‘', "'").replace('’', "'")   # ' '
        .replace('“', '"').replace('”', '"')   # " "
        .replace('–', '-').replace('—', '--')  # – —
        .replace(' ', ' '))                          # nbsp

    # Extract metadata — handle semua pattern:
    #   const layoutId = '...' atau "..."
    #   export const layoutName = '...' atau "..."
    #   export const slideLayoutId = '...' atau "..."  (ProductOverview, Code, dll)
    #   export const slideLayoutDescription = `...` (template literal, multi-line)
    Q = r'["\']'  # match single atau double quote
    layout_id = ""
    m = re.search(rf'(?:export\s+)?const\s+slideLayoutId\s*=\s*{Q}([^"\']+){Q}', content)
    if not m:
        m = re.search(rf'(?:export\s+)?const\s+(?:slide)?layoutId\s*=\s*{Q}([^"\']+){Q}', content)
    if not m:
        # Fallback: slug dari nama file (untuk Chart primitives, CodeBlockPanel, dll)
        m = re.search(r'export\s+const\s+(\w+)\s*=\s*z\.object', content)
    if m:
        layout_id = m.group(1) if 'layoutId' not in m.group(0) else layout_id
    if not layout_id:
        # Last resort: nama file sebagai layoutId
        layout_id = tsx_path.stem
        # Convert camelCase/PascalCase ke kebab-case
        layout_id = re.sub(r'(?<!^)(?=[A-Z])', '-', layout_id).lower()

    layout_name = ""
    m = re.search(rf'(?:export\s+)?const\s+slideLayoutName\s*=\s*{Q}([^"\']+){Q}', content)
    if not m:
        m = re.search(rf'(?:export\s+)?const\s+(?:slide)?layoutName\s*=\s*{Q}([^"\']+){Q}', content)
    if m:
        layout_name = m.group(1)
    if not layout_name:
        layout_name = tsx_path.stem.replace('_', ' ').replace('-', ' ').title()

    layout_desc = ""
    m = re.search(rf'(?:export\s+)?const\s+slideLayoutDescription\s*=\s*{Q}([^"\']+){Q}', content)
    if not m:
        m = re.search(rf'(?:export\s+)?const\s+(?:slide)?layoutDescription\s*=\s*{Q}([^"\']+){Q}', content)
    if m:
        layout_desc = m.group(1)
    if not layout_desc:
        # Template literal (backtick)
        m2 = re.search(r'(?:export\s+)?const\s+slideLayoutDescription\s*=\s*`([^`]+)`', content)
        if m2:
            layout_desc = m2.group(1).strip()
        else:
            m3 = re.search(r'//\s*(.+)', content)
            if m3:
                layout_desc = m3.group(1).strip()
            else:
                layout_desc = layout_name

    # Extract font
    font_family = extract_font_family(content)

    # Extract colors
    colors = extract_colors_from_content(content)
    bg_color = colors.get('background-color', CSS_VAR_DEFAULTS.get('background-color', '#FFFFFF'))

    # Extract schema fields
    schema_fields = extract_zod_fields(content)

    # Generate elements dari JSX
    elements = generate_elements_from_jsx(content, colors, schema_fields)

    return {
        "layoutId": layout_id,
        "name": layout_name,
        "description": layout_desc,
        "canvas": {
            "width": 1280,
            "height": 720,
            "backgroundColor": bg_color,
            "fontFamily": font_family,
        },
        "elements": elements,
        "_schema": schema_fields,  # metadata saja
        "_cssVars": colors,        # metadata saja
    }

def process_folder(folder_name):
    """Proses semua .tsx dalam 1 folder → JSON."""
    src_dir = TEMPLATE_ROOT / folder_name
    out_dir = OUTPUT_ROOT / folder_name
    out_dir.mkdir(parents=True, exist_ok=True)

    tsx_files = list(src_dir.glob("*.tsx"))
    results = []

    for tsx in tsx_files:
        try:
            data = parse_tsx_file(tsx)
            json_name = tsx.stem + ".json"
            out_path = out_dir / json_name

            # Simpan JSON
            with open(out_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)

            elem_count = len(data['elements'])
            results.append((tsx.name, json_name, elem_count))
            print(f"  ✅ {tsx.name:40s} → {json_name:30s} ({elem_count} elements)")
        except Exception as e:
            print(f"  ❌ {tsx.name:40s} → ERROR: {e}")

    return results

def main():
    import sys, io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    print("[OK] Parser React .tsx -> JSON")
    print("=" * 70)

    folders = sorted([f.name for f in TEMPLATE_ROOT.iterdir() if f.is_dir()])
    total_files = 0

    for folder in folders:
        print(f"\n>>> {folder}/")
        results = process_folder(folder)
        total_files += len(results)

    print(f"\n{'='*70}")
    print(f"Done! {total_files} files dikonversi")
    print(f"Output: {OUTPUT_ROOT}")

if __name__ == "__main__":
    main()
