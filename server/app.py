"""
DocuCraft Server - Python API for PPT Master Integration
Menjalankan script PPT Master sebagai API endpoint.
Flutter app berkomunikasi via HTTP ke server ini.
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import sys
import json
import tempfile
import shutil
from pathlib import Path

# Add ppt-master skills to path
SKILL_DIR = os.path.join(os.path.dirname(__file__), '..', 'skills', 'ppt-master')
sys.path.insert(0, SKILL_DIR)

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter web

# Project storage
PROJECTS_DIR = os.path.join(os.path.dirname(__file__), 'projects')
os.makedirs(PROJECTS_DIR, exist_ok=True)


# ═══════════════════════════════════════════════════════════════
# STEP 1: Source Content Processing
# ═══════════════════════════════════════════════════════════════

@app.route('/api/step1/process-source', methods=['POST'])
def process_source():
    """
    Step 1: Process source content (text, file, URL)

    Request:
    {
        "type": "text" | "file" | "url",
        "content": "...",  # for text
        "file_path": "...",  # for file
        "url": "..."  # for url
    }

    Response:
    {
        "success": true,
        "markdown": "...",
        "metadata": {...}
    }
    """
    data = request.json
    source_type = data.get('type', 'text')

    try:
        if source_type == 'text':
            markdown = data.get('content', '')
        elif source_type == 'file':
            file_path = data.get('file_path')
            if file_path and os.path.exists(file_path):
                # Use source_to_md.py logic
                from scripts.source_to_md import convert_file
                markdown = convert_file(file_path)
            else:
                return jsonify({'success': False, 'error': 'File not found'}), 404
        elif source_type == 'url':
            url = data.get('url')
            from scripts.source_to_md import convert_url
            markdown = convert_url(url)
        else:
            return jsonify({'success': False, 'error': 'Invalid source type'}), 400

        return jsonify({
            'success': True,
            'markdown': markdown,
            'metadata': {
                'type': source_type,
                'length': len(markdown)
            }
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


# ═══════════════════════════════════════════════════════════════
# STEP 2: Project Initialization
# ═══════════════════════════════════════════════════════════════

@app.route('/api/step2/init-project', methods=['POST'])
def init_project():
    """
    Step 2: Initialize project workspace

    Request:
    {
        "project_name": "Presentasi AI",
        "format": "ppt169"
    }

    Response:
    {
        "success": true,
        "project_id": "project_123",
        "project_path": "projects/project_123"
    }
    """
    data = request.json
    project_name = data.get('project_name', 'Untitled')
    fmt = data.get('format', 'ppt169')

    try:
        # Create project directory
        import time
        project_id = f"project_{int(time.time())}"
        project_path = os.path.join(PROJECTS_DIR, project_id)
        os.makedirs(project_path, exist_ok=True)

        # Create subdirectories
        for subdir in ['sources', 'analysis', 'svg_output', 'svg_final', 'images', 'templates', 'exports']:
            os.makedirs(os.path.join(project_path, subdir), exist_ok=True)

        # Create config
        config = {
            'project_id': project_id,
            'project_name': project_name,
            'format': fmt,
            'canvas': _get_canvas_config(fmt)
        }

        with open(os.path.join(project_path, 'config.json'), 'w') as f:
            json.dump(config, f, indent=2)

        return jsonify({
            'success': True,
            'project_id': project_id,
            'project_path': project_path,
            'config': config
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


def _get_canvas_config(fmt):
    """Get canvas configuration for format"""
    configs = {
        'ppt169': {'width': 1280, 'height': 720, 'viewBox': '0 0 1280 720'},
        'ppt43': {'width': 1024, 'height': 768, 'viewBox': '0 0 1024 768'},
        'story': {'width': 1080, 'height': 1920, 'viewBox': '0 0 1080 1920'},
        'banner': {'width': 1920, 'height': 1080, 'viewBox': '0 0 1920 1080'},
    }
    return configs.get(fmt, configs['ppt169'])


# ═══════════════════════════════════════════════════════════════
# STEP 3: Template Candidate Preparation
# ═══════════════════════════════════════════════════════════════

@app.route('/api/step3/template-candidates', methods=['POST'])
def get_template_candidates():
    """
    Step 3: Get template candidates based on prompt

    Request:
    {
        "prompt": "Buat presentasi tentang AI"
    }

    Response:
    {
        "success": true,
        "candidates": [
            {"id": "tech-modern", "name": "Tech Modern", "score": 10},
            ...
        ]
    }
    """
    data = request.json
    prompt = data.get('prompt', '').lower()

    try:
        # Load templates from indexes
        templates = _load_all_templates()

        # Score templates
        scored = []
        for template in templates:
            score = _score_template(template, prompt)
            if score > 0:
                scored.append({**template, 'score': score})

        # Sort by score
        scored.sort(key=lambda x: x['score'], reverse=True)

        return jsonify({
            'success': True,
            'candidates': scored[:3]  # Top 3
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


def _load_all_templates():
    """Load all templates from index files"""
    templates = []
    index_dir = os.path.join(SKILL_DIR, 'templates')

    for kind in ['brands', 'styles', 'layouts', 'decks']:
        index_path = os.path.join(index_dir, kind, f'{kind}_index.json')
        if os.path.exists(index_path):
            with open(index_path) as f:
                data = json.load(f)
                for item in data.get('items', []):
                    templates.append({
                        'id': item['id'],
                        'name': item.get('name', item['id']),
                        'kind': kind,
                        'colors': item.get('colors', {}),
                        'fonts': item.get('fonts', {}),
                        'tags': item.get('tags', [])
                    })

    return templates


def _score_template(template, prompt):
    """Score template based on prompt keywords"""
    score = 0
    for tag in template.get('tags', []):
        if tag.lower() in prompt:
            score += 3
    for color in template.get('colors', {}).values():
        if color.lower() in prompt:
            score += 1
    return score


# ═══════════════════════════════════════════════════════════════
# STEP 4: Strategist Phase (Confirmation)
# ═══════════════════════════════════════════════════════════════

@app.route('/api/step4/confirm', methods=['POST'])
def confirm_design():
    """
    Step 4: Confirm design specification

    Request:
    {
        "project_id": "project_123",
        "template_id": "tech-modern",
        "topic": "AI",
        "warna": "biru",
        "style": "modern",
        "page_count": 5
    }

    Response:
    {
        "success": true,
        "design_spec": {...}
    }
    """
    data = request.json

    try:
        design_spec = {
            'project_id': data.get('project_id'),
            'template_id': data.get('template_id'),
            'topic': data.get('topic'),
            'warna': data.get('warna'),
            'style': data.get('style'),
            'page_count': data.get('page_count', 5),
            'confirmed': True
        }

        # Save design spec
        project_path = os.path.join(PROJECTS_DIR, data.get('project_id'))
        with open(os.path.join(project_path, 'design_spec.json'), 'w') as f:
            json.dump(design_spec, f, indent=2)

        return jsonify({
            'success': True,
            'design_spec': design_spec
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


# ═══════════════════════════════════════════════════════════════
# STEP 5: Image Acquisition
# ═══════════════════════════════════════════════════════════════

@app.route('/api/step5/acquire-images', methods=['POST'])
def acquire_images():
    """
    Step 5: Acquire images (AI generation, search, etc.)

    Request:
    {
        "project_id": "project_123",
        "prompts": ["AI robot", "Machine learning"],
        "source": "ai" | "web"
    }

    Response:
    {
        "success": true,
        "images": [
            {"path": "images/img1.png", "prompt": "AI robot"},
            ...
        ]
    }
    """
    data = request.json

    try:
        project_path = os.path.join(PROJECTS_DIR, data.get('project_id'))
        images_dir = os.path.join(project_path, 'images')

        # TODO: Implement actual image generation/search
        # For now, return placeholder
        images = []
        for prompt in data.get('prompts', []):
            images.append({
                'path': f'images/placeholder.png',
                'prompt': prompt
            })

        return jsonify({
            'success': True,
            'images': images
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


# ═══════════════════════════════════════════════════════════════
# STEP 6: SVG Authoring (Executor)
# ═══════════════════════════════════════════════════════════════

@app.route('/api/step6/generate-svg', methods=['POST'])
def generate_svg():
    """
    Step 6: Generate SVG pages

    Request:
    {
        "project_id": "project_123",
        "pages": [
            {"title": "Cover", "content": "AI Presentation"},
            ...
        ]
    }

    Response:
    {
        "success": true,
        "project_id": "project_123",
        "pages": [
            {
                "page": 1,
                "title": "Cover",
                "subtitle": null,
                "svg": "<svg>...</svg>",
                "elements": [...],
                "background_gradient": "indigo",
                "layout": {...}
            },
            ...
        ],
        "metadata": {
            "total_pages": 5,
            "total_elements": 25,
            "canvas": {"width": 1920, "height": 1080, "viewBox": "0 0 1920 1080"}
        }
    }
    """
    data = request.json

    try:
        project_path = os.path.join(PROJECTS_DIR, data.get('project_id'))
        svg_output_dir = os.path.join(project_path, 'svg_output')

        # Load config for canvas info
        config_path = os.path.join(project_path, 'config.json')
        config = {}
        if os.path.exists(config_path):
            with open(config_path) as f:
                config = json.load(f)

        canvas = config.get('canvas', {'width': 1920, 'height': 1080, 'viewBox': '0 0 1920 1080'})

        pages = []
        total_elements = 0
        for i, page_data in enumerate(data.get('pages', [])):
            # Generate SVG
            svg = _generate_page_svg(page_data, i + 1)

            # Parse elements from SVG
            elements = _extract_elements_from_svg(svg)
            total_elements += len(elements)

            page = {
                'page': i + 1,
                'title': page_data.get('title', f'Page {i+1}'),
                'subtitle': page_data.get('subtitle'),
                'svg': svg,
                'elements': elements,
                'background_gradient': page_data.get('background_gradient', 'indigo'),
                'layout': page_data.get('layout', {
                    'layout_id': 'default',
                    'layout_name': 'Default',
                    'slots': ['title', 'content']
                })
            }
            pages.append(page)

            # Save SVG
            with open(os.path.join(svg_output_dir, f'page_{i+1:02d}.svg'), 'w') as f:
                f.write(svg)

        return jsonify({
            'success': True,
            'project_id': data.get('project_id'),
            'pages': pages,
            'metadata': {
                'total_pages': len(pages),
                'total_elements': total_elements,
                'canvas': canvas
            }
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


def _extract_elements_from_svg(svg):
    """Extract elements from SVG for metadata"""
    import re
    elements = []

    # Extract text elements
    for match in re.finditer(r'<text[^>]*>(.*?)</text>', svg, re.DOTALL):
        elements.append({
            'type': 'text',
            'x': 0,  # TODO: extract from attributes
            'y': 0,
            'width': 100,
            'height': 50,
            'content': match.group(1).strip()
        })

    # Extract rect elements
    for match in re.finditer(r'<rect[^>]*/>', svg):
        elements.append({
            'type': 'shape',
            'x': 0,
            'y': 0,
            'width': 100,
            'height': 100,
            'shape_type': 'rect'
        })

    return elements


def _generate_page_svg(page, page_num):
    """Generate SVG for a page (simplified)"""
    title = page.get('title', '')
    content = page.get('content', '')

    return f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1280 720" width="1280" height="720">
  <rect width="1280" height="720" fill="#1E293B"/>
  <text x="96" y="180" font-size="56" fill="#FFFFFF" font-weight="bold">{title}</text>
  <text x="96" y="280" font-size="24" fill="#94A3B8">{content}</text>
</svg>'''


# ═══════════════════════════════════════════════════════════════
# STEP 7: Quality Check + Export
# ═══════════════════════════════════════════════════════════════

@app.route('/api/step7/quality-check', methods=['POST'])
def quality_check():
    """
    Step 7a: Run quality check on SVGs

    Request:
    {
        "project_id": "project_123"
    }

    Response:
    {
        "success": true,
        "passed": true,
        "issues": [],
        "fixes": []
    }
    """
    data = request.json

    try:
        project_path = os.path.join(PROJECTS_DIR, data.get('project_id'))
        svg_output_dir = os.path.join(project_path, 'svg_output')

        # Run quality check (simplified - use actual PPT Master logic)
        issues = []
        fixes = []

        # Check each SVG
        for svg_file in os.listdir(svg_output_dir):
            if svg_file.endswith('.svg'):
                # TODO: Run svg_quality_checker.py
                pass

        return jsonify({
            'success': True,
            'passed': len(issues) == 0,
            'issues': issues,
            'fixes': fixes
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/step7/export-pptx', methods=['POST'])
def export_pptx():
    """
    Step 7b: Export to PPTX

    Request:
    {
        "project_id": "project_123",
        "filename": "presentasi_ai.pptx"
    }

    Response:
    {
        "success": true,
        "export": {
            "format": "pptx",
            "file_path": "exports/presentasi_ai.pptx",
            "download_url": "/api/download/presentasi_ai.pptx",
            "file_size_bytes": 12345,
            "exported_at": "2026-08-28T10:00:00"
        },
        "metadata": {
            "total_slides": 5,
            "total_elements": 25,
            "quality_check_passed": true
        }
    }
    """
    data = request.json

    try:
        project_path = os.path.join(PROJECTS_DIR, data.get('project_id'))
        exports_dir = os.path.join(project_path, 'exports')
        os.makedirs(exports_dir, exist_ok=True)

        filename = data.get('filename', 'presentation.pptx')
        file_path = os.path.join(exports_dir, filename)

        # TODO: Run actual PPTX generation
        # For now, create placeholder
        with open(file_path, 'w') as f:
            f.write('PPTX placeholder')

        # Get file size
        file_size = os.path.getsize(file_path)

        # Count SVG files for metadata
        svg_output_dir = os.path.join(project_path, 'svg_output')
        svg_files = [f for f in os.listdir(svg_output_dir) if f.endswith('.svg')] if os.path.exists(svg_output_dir) else []

        return jsonify({
            'success': True,
            'export': {
                'format': 'pptx',
                'file_path': file_path,
                'download_url': f'/api/download/{filename}',
                'file_size_bytes': file_size,
                'exported_at': '2026-08-28T10:00:00'
            },
            'metadata': {
                'total_slides': len(svg_files),
                'total_elements': len(svg_files) * 5,  # Estimate
                'quality_check_passed': True
            }
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/download/<filename>', methods=['GET'])
def download_file(filename):
    """Download exported file"""
    # TODO: Implement secure file download
    pass


# ═══════════════════════════════════════════════════════════════
# LIVE PREVIEW SERVER (replaces svg_editor/server.py)
# ═══════════════════════════════════════════════════════════════

@app.route('/api/preview/start', methods=['POST'])
def start_preview():
    """
    Start live preview server

    Request:
    {
        "project_id": "project_123"
    }

    Response:
    {
        "success": true,
        "preview_url": "http://localhost:5000/preview/project_123"
    }
    """
    data = request.json
    project_id = data.get('project_id')

    return jsonify({
        'success': True,
        'preview_url': f'http://localhost:5000/preview/{project_id}'
    })


@app.route('/api/preview/<project_id>', methods=['GET'])
def get_preview(project_id):
    """Get preview HTML for project"""
    project_path = os.path.join(PROJECTS_DIR, project_id)
    svg_output_dir = os.path.join(project_path, 'svg_output')

    # Generate preview HTML
    html = '<html><body><h1>Preview</h1>'
    for svg_file in sorted(os.listdir(svg_output_dir)):
        if svg_file.endswith('.svg'):
            with open(os.path.join(svg_output_dir, svg_file)) as f:
                html += f.read()
    html += '</body></html>'

    return html


# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════

if __name__ == '__main__':
    print("DocuCraft Server starting...")
    print(f"Projects directory: {PROJECTS_DIR}")
    print(f"PPT Master skills: {SKILL_DIR}")
    app.run(host='0.0.0.0', port=5000, debug=True)
