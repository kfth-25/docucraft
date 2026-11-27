/**
 * Local Bridge Server — Flutter App → Claude Code
 *
 * Menghubungkan Flutter app ke Claude Code (yang digunakan AION UI).
 * Flutter app kirim prompt via HTTP, server forward ke Claude Code via CLI.
 *
 * Usage:
 *   node server.js
 *   Server runs at http://localhost:3001
 *
 * Endpoints:
 *   POST /generate — Generate PPT dari prompt
 *   POST /health — Check server status
 */

const http = require('http');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const PORT = 3001;
const CLAUDE_CODE_PATH = process.env.CLAUDE_CODE_PATH || 'claude';
const SKILLS_DIR = path.join(__dirname, '..', 'skills');

// ── Request Logger ──
function logRequest(method, url, body) {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${method} ${url}`);
  if (body && body.prompt) {
    console.log(`  Prompt: ${body.prompt.substring(0, 100)}...`);
  }
}

// ── Parse JSON Body ──
function parseBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', chunk => data += chunk);
    req.on('end', () => {
      try {
        resolve(data ? JSON.parse(data) : {});
      } catch (e) {
        reject(e);
      }
    });
  });
}

// ── Send JSON Response ──
function sendJson(res, statusCode, data) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  });
  res.end(JSON.stringify(data));
}

// ── Call Claude Code via CLI ──
async function callClaudeCode(prompt, options = {}) {
  const {
    outputFormat = 'text', // 'text' or 'json'
    maxTurns = 10,
    allowedTools = ['Read', 'Write', 'Edit', 'Bash', 'Glob', 'Grep'],
  } = options;

  return new Promise((resolve, reject) => {
    const args = [
      '--print',
      '--output-format', outputFormat,
      '--max-turns', String(maxTurns),
      '--allowedTools', allowedTools.join(','),
      '--skill', 'ppt-master',
      prompt,
    ];

    console.log(`  → Spawning: ${CLAUDE_CODE_PATH} ${args.join(' ')}`);

    const child = spawn(CLAUDE_CODE_PATH, args, {
      cwd: path.join(__dirname, '..'),
      env: {
        ...process.env,
        ANTHROPIC_BASE_URL: process.env.ANTHROPIC_BASE_URL || 'http://127.0.0.1:20128/v1',
        // Key TIDAK di-hardcode — set ANTHROPIC_AUTH_TOKEN di environment.
        ANTHROPIC_AUTH_TOKEN: process.env.ANTHROPIC_AUTH_TOKEN || '',
      },
      timeout: 300000, // 5 minutes
    });

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', data => {
      stdout += data.toString();
    });

    child.stderr.on('data', data => {
      stderr += data.toString();
    });

    child.on('close', code => {
      if (code !== 0) {
        console.error(`  ✗ Claude Code exited with code ${code}`);
        console.error(`  stderr: ${stderr.substring(0, 500)}`);
        reject(new Error(`Claude Code failed (code ${code}): ${stderr}`));
      } else {
        console.log(`  ✓ Claude Code completed (${stdout.length} chars)`);
        resolve(stdout);
      }
    });

    child.on('error', err => {
      console.error(`  ✗ Failed to spawn Claude Code: ${err.message}`);
      reject(err);
    });
  });
}

// ── Routes ──
const server = http.createServer(async (req, res) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    sendJson(res, 200, {});
    return;
  }

  const url = new URL(req.url, `http://localhost:${PORT}`);

  try {
    // ── Health Check ──
    if (url.pathname === '/health' && req.method === 'GET') {
      logRequest(req.method, req.url);
      sendJson(res, 200, {
        status: 'ok',
        service: 'Flutter-Claude Bridge',
        version: '1.0.0',
        skillsDir: SKILLS_DIR,
        skillsExist: fs.existsSync(SKILLS_DIR),
      });
      return;
    }

    // ── Generate PPT ──
    if (url.pathname === '/generate' && req.method === 'POST') {
      const body = await parseBody(req);
      logRequest(req.method, req.url, body);

      if (!body.prompt) {
        sendJson(res, 400, { error: 'Missing "prompt" field' });
        return;
      }

      try {
        const result = await callClaudeCode(body.prompt, {
          outputFormat: body.outputFormat || 'text',
          maxTurns: body.maxTurns || 10,
        });

        sendJson(res, 200, {
          success: true,
          result: result,
          prompt: body.prompt,
        });
      } catch (err) {
        sendJson(res, 500, {
          success: false,
          error: err.message,
        });
      }
      return;
    }

    // ── Get SVG Output ──
    if (url.pathname === '/svg' && req.method === 'GET') {
      logRequest(req.method, req.url);

      // Look for generated SVG files in projects/
      const projectsDir = path.join(__dirname, '..', 'projects');
      if (!fs.existsSync(projectsDir)) {
        sendJson(res, 404, { error: 'No projects directory' });
        return;
      }

      const svgFiles = [];
      function findSvg(dir) {
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        for (const entry of entries) {
          const fullPath = path.join(dir, entry.name);
          if (entry.isDirectory()) {
            findSvg(fullPath);
          } else if (entry.name.endsWith('.svg')) {
            svgFiles.push({
              path: fullPath,
              relativePath: path.relative(projectsDir, fullPath),
              size: fs.statSync(fullPath).size,
            });
          }
        }
      }
      findSvg(projectsDir);

      sendJson(res, 200, { svgFiles });
      return;
    }

    // ── 404 ──
    sendJson(res, 404, { error: 'Not found' });

  } catch (err) {
    console.error('Server error:', err);
    sendJson(res, 500, { error: err.message });
  }
});

// ── Start Server ──
server.listen(PORT, () => {
  console.log('');
  console.log('═══════════════════════════════════════════════════════════');
  console.log('  Flutter ↔ Claude Code Bridge Server');
  console.log('═══════════════════════════════════════════════════════════');
  console.log(`  URL: http://localhost:${PORT}`);
  console.log(`  Skills: ${SKILLS_DIR}`);
  console.log(`  Claude Code: ${CLAUDE_CODE_PATH}`);
  console.log('');
  console.log('  Endpoints:');
    console.log(`    GET  /health   — Check server status`);
    console.log(`    POST /generate — Generate PPT (body: { prompt })`);
    console.log(`    GET  /svg      — List generated SVG files`);
  console.log('═══════════════════════════════════════════════════════════');
  console.log('');
});
