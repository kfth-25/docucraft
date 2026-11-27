/**
 * AION UI Bridge Server
 *
 * Menerima prompt dari Flutter app dan insert ke database AION UI
 * sehingga muncul sebagai conversation baru di AION UI.
 *
 * Flow:
 *   Flutter app → HTTP POST → Bridge Server → SQLite AION UI → AION UI detect & process
 *
 * Usage:
 *   node aion-bridge.js
 *   Server runs at http://localhost:3002
 */

const http = require('http');
const { DatabaseSync } = require('node:sqlite');
const path = require('path');
const crypto = require('crypto');

const PORT = 3002;

// Set Aion UI runtime env vars (required by aioncore.exe session send-message)
process.env.AIONUI_BASE_URL = 'http://127.0.0.1:55018';
process.env.AIONUI_WORK_DIR = path.join(
  process.env.APPDATA || path.join(process.env.HOME, 'AppData', 'Roaming'),
  'AionUi', 'aionui'
);
process.env.AIONUI_HELPER_BIN = path.join(
  process.env.LOCALAPPDATA || path.join(process.env.HOME, 'AppData', 'Local'),
  'Programs', 'AionUi', 'resources', 'bundled-aioncore', 'win32-x64', 'aioncore.exe'
);
console.log(`  AIONUI_BASE_URL: ${process.env.AIONUI_BASE_URL}`);

const AION_DB_PATH = path.join(
  process.env.APPDATA || path.join(process.env.HOME, 'AppData', 'Roaming'),
  'AionUi', 'aionui', 'aionui-backend.db'
);

// ── Database Connection ──
let db;
try {
  db = new DatabaseSync(AION_DB_PATH);
  console.log(`✓ Connected to AION UI database: ${AION_DB_PATH}`);
} catch (err) {
  console.error(`✗ Failed to connect to AION UI database: ${err.message}`);
  console.error('  Make sure AION UI is installed.');
  process.exit(1);
}

// ── Generate UUID ──
function uuid() {
  return crypto.randomUUID();
}

// ── Get or Create User ──
function getOrCreateUser() {
  // Always use the logged-in AionPro user (not system_default_user)
  const user = db.prepare("SELECT id FROM users WHERE user_type = 'aionpro' ORDER BY updated_at DESC LIMIT 1").get();
  if (user) return user.id;

  // Fallback: any non-system user
  const fallback = db.prepare("SELECT id FROM users WHERE id != 'system_default_user' LIMIT 1").get();
  if (fallback) return fallback.id;

  // Last resort: system_default_user
  const sys = db.prepare("SELECT id FROM users LIMIT 1").get();
  if (sys) return sys.id;

  const userId = uuid();
  const now = Date.now();
  db.prepare(`
    INSERT INTO users (id, username, email, password_hash, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(userId, 'aionui', 'flutter@local', 'noop', now, now);
  return userId;
}

// ── Create Conversation ──
function createConversation(userId, prompt) {
  const conversationId = uuid();
  const now = Date.now();

  db.prepare(`
    INSERT INTO conversations (id, user_id, name, type, status, source, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    conversationId,
    userId,
    `Flutter: ${prompt.substring(0, 50)}...`,
    'chat',
    'pending',
    'aionui',
    now,
    now
  );

  return conversationId;
}

// ── Get Keqo Extra (shared helper) ──
function getKeqoExtra(agentId) {
  const keqoConv = db.prepare('SELECT extra FROM conversations WHERE name = ? AND source = ? LIMIT 1').get('keqo', 'aionui');
  if (!keqoConv || !keqoConv.extra) return null;
  try {
    const extra = JSON.parse(keqoConv.extra);
    extra.agent_id = agentId; // Update agent_id ke Project Mapper
    return JSON.stringify(extra);
  } catch (e) {
    return keqoConv.extra;
  }
}

// ── Create ACP Conversation (like AION UI does) ──
function createAcpConversation(userId, prompt) {
  const conversationId = uuid();
  const now = Date.now();

  // Get Project Mapper agent ID (fallback to Claude Code if not found)
  const mapperAgent = db.prepare("SELECT agent_id FROM agent_metadata WHERE name = 'Project Mapper' LIMIT 1").get();
  const agentId = mapperAgent ? mapperAgent.agent_id : '2d23ff1c';

  // Get extra from conversation "keqo" (Claude Code + Project Mapper preset context)
  const keqoExtra = getKeqoExtra(agentId);

  // Get project_id, folder_id, user_id from "keqo" PROJECT (sessions muncul di project keqo)
  const keqoProject = db.prepare('SELECT project_id FROM projects WHERE name = ? LIMIT 1').get('keqo');
  const projectId = keqoProject ? keqoProject.project_id : null;
  const keqoProjConv = db.prepare('SELECT folder_id, user_id FROM conversations WHERE project_id = ? LIMIT 1').get(projectId);
  const folderId = keqoProjConv ? keqoProjConv.folder_id : null;
  const realUserId = keqoProjConv ? keqoProjConv.user_id : userId;

  // Extra JSON like AION UI creates
  const extra = JSON.stringify({
    agent_id: agentId,
    agent_source: 'builtin',
    backend: 'claude',
    current_mode_id: 'bypassPermissions',
    current_model_id: 'fable',
    default_files: [],
    mcp_server_ids: [],
    mcp_servers: [],
    mcp_statuses: [],
    session_mcp_servers: [],
    session_mode: 'bypassPermissions',
    skills: ['aionui-config', 'cron', 'officecli', 'ppt-master', 'skill-creator'],
    thought_level: 'max',
    workspace: `C:\\Users\\Pongo\\docucraft_app`,
    preset_context: '# PPT Master Skill\n\nYou are an expert presentation designer AI. Create attractive and COMPLEX presentation designs.',
  });

  db.prepare(`
    INSERT INTO conversations (id, user_id, name, type, extra, status, source, project_id, folder_id, name_source, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    conversationId,
    realUserId,
    `Flutter: ${prompt.substring(0, 50)}...`,
    'acp',
    keqoExtra || extra,
    'pending',
    'aionui',
    projectId,
    folderId,
    'user',
    now,
    now
  );

  // Get snapshot data from "keqo" conversation (required for AION UI to show in list)
  const keqoSnapshot = db.prepare('SELECT * FROM conversation_assistant_snapshots WHERE conversation_id = ?').get('c7c5d0cd');

  // Create assistant snapshot entry (REQUIRED for AION UI to show conversation in list)
  if (keqoSnapshot) {
    db.prepare(`
      INSERT INTO conversation_assistant_snapshots (
        conversation_id, assistant_definition_id, assistant_id, assistant_source,
        agent_id, rules_content, default_model_mode, resolved_model_id,
        default_permission_mode, resolved_permission_value,
        default_skills_mode, resolved_skill_ids, resolved_disabled_builtin_skill_ids,
        default_mcps_mode, resolved_mcp_ids, default_thought_level_mode,
        resolved_thought_level_value, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      conversationId,
      keqoSnapshot.assistant_definition_id,
      keqoSnapshot.assistant_id,
      keqoSnapshot.assistant_source,
      agentId, // Use Project Mapper agent_id
      keqoSnapshot.rules_content,
      keqoSnapshot.default_model_mode,
      keqoSnapshot.resolved_model_id,
      keqoSnapshot.default_permission_mode,
      keqoSnapshot.resolved_permission_value,
      keqoSnapshot.default_skills_mode,
      keqoSnapshot.resolved_skill_ids,
      keqoSnapshot.resolved_disabled_builtin_skill_ids,
      keqoSnapshot.default_mcps_mode,
      keqoSnapshot.resolved_mcp_ids,
      keqoSnapshot.default_thought_level_mode,
      keqoSnapshot.resolved_thought_level_value,
      now,
      now
    );
  }

  // Create ACP session entry with valid session_id (REQUIRED for AION UI to process prompts)
  const sessionId = uuid();
  const sessionConfig = JSON.stringify({
    runtime: {
      config_selections: {
        agent: 'default',
        effort: 'max',
        mode: 'bypassPermissions',
        model: 'fable',
      },
      current_mode_id: 'bypassPermissions',
      current_model_id: 'fable',
    },
  });

  db.prepare(`
    INSERT INTO acp_session (conversation_id, agent_source, agent_id, session_id, session_status, session_config, last_active_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `).run(
    conversationId,
    'builtin',
    agentId,
    sessionId,
    'idle',
    sessionConfig,
    now
  );

  return conversationId;
}

// ── Insert Message ──
function insertMessage(conversationId, content, type = 'user') {
  const messageId = uuid();
  const now = Date.now();

  db.prepare(`
    INSERT INTO messages (id, conversation_id, type, content, position, status, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `).run(
    messageId,
    conversationId,
    type,
    JSON.stringify({ text: content, content: content }),
    type === 'user' ? 'right' : 'left',
    'finish',
    now
  );

  return messageId;
}

// ── Request Logger ──
function log(method, url, body = {}) {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${method} ${url}`);
  if (body.prompt) console.log(`  Prompt: ${body.prompt.substring(0, 100)}...`);
}

// ── Parse JSON Body ──
function parseBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', chunk => data += chunk);
    req.on('end', () => {
      try { resolve(data ? JSON.parse(data) : {}); }
      catch (e) { reject(e); }
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

// ── Routes ──
const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    sendJson(res, 200, {});
    return;
  }

  const url = new URL(req.url, `http://localhost:${PORT}`);

  try {
    // ── Health Check ──
    if (url.pathname === '/health' && req.method === 'GET') {
      log(req.method, req.url);
      const userCount = db.prepare('SELECT COUNT(*) as count FROM users').get();
      const convCount = db.prepare('SELECT COUNT(*) as count FROM conversations').get();
      sendJson(res, 200, {
        status: 'ok',
        service: 'Flutter ↔ AION UI Bridge',
        version: '1.0.0',
        dbPath: AION_DB_PATH,
        users: userCount.count,
        conversations: convCount.count,
      });
      return;
    }

    // ── Create New Agent Session (buat agent baru di project docucraft_app) ──
    if (url.pathname === '/create-session' && req.method === 'POST') {
      const body = await parseBody(req);
      log(req.method, req.url, body);

      try {
        const userId = getOrCreateUser();
        const convId = createAcpConversation(userId, body.projectName || 'New Agent Session');

        // Get project & folder for docucraft_app
        const proj = db.prepare('SELECT project_id FROM projects WHERE name = ? LIMIT 1').get('docucraft_app');
        const folder = db.prepare('SELECT f.folder_id FROM folders f JOIN project_explorer pe ON f.folder_id = pe.folder_id JOIN projects p ON pe.project_id = p.project_id WHERE p.name = ? LIMIT 1').get('docucraft_app');

        if (proj) {
          db.prepare('UPDATE conversations SET project_id = ?, folder_id = ? WHERE id = ?').run(proj.project_id, folder ? folder.folder_id : null, convId);
        }

        insertMessage(convId, 'Session started. Ready for prompts.', 'user');

        // Restart AION UI to detect new session
        const { exec } = require('child_process');
        exec('taskkill /IM AionUi.exe /IM aioncore.exe 2>nul & timeout /t 3 /nobreak >nul 2>&1 & start "" "C:\\Users\\Pongo\\AppData\\Local\\Programs\\AionUi\\AionUi.exe"', (err) => {
          if (err) console.log('AION UI restart error:', err.message);
          else console.log('AION UI restarted for new session');
        });

        sendJson(res, 200, {
          success: true,
          conversationId: convId,
          message: 'New agent session created. AION UI restarting...',
        });
      } catch (err) {
        sendJson(res, 500, { success: false, error: err.message });
      }
      return;
    }

    // ── Create Agent (smart: buat session + snapshot + acp_session, no restart) ──
    if (url.pathname === '/create-agent' && req.method === 'POST') {
      const body = await parseBody(req);
      log(req.method, req.url, body);

      try {
        const userId = getOrCreateUser();
        const agentName = body.agentName || 'Project Mapper';
        const projectName = body.projectName || 'docucraft_app';
        const prompt = body.prompt || 'Agent ready.';

        // Resolve agent_id from agent_metadata by name
        const agentMeta = db.prepare('SELECT agent_id FROM agent_metadata WHERE name = ? LIMIT 1').get(agentName);
        const agentId = agentMeta ? agentMeta.agent_id : body.agentId || 'pm_mapper';

        // Create ACP conversation
        const conversationId = uuid();
        const now = Date.now();

        // Get project & folder
        const proj = db.prepare('SELECT project_id FROM projects WHERE name = ? LIMIT 1').get(projectName);
        const folder = db.prepare('SELECT f.folder_id FROM folders f JOIN project_explorer pe ON f.folder_id = pe.folder_id JOIN projects p ON pe.project_id = p.project_id WHERE p.name = ? LIMIT 1').get(projectName);

        // Build extra JSON
        const extra = JSON.stringify({
          agent_id: agentId,
          agent_source: 'builtin',
          backend: 'claude',
          current_mode_id: 'bypassPermissions',
          current_model_id: 'fable',
          default_files: [],
          mcp_server_ids: [],
          mcp_servers: [],
          mcp_statuses: [],
          session_mcp_servers: [],
          session_mode: 'bypassPermissions',
          skills: ['aionui-config', 'cron', 'officecli', 'ppt-master', 'skill-creator', 'session-message'],
          thought_level: 'max',
          workspace: `C:\\Users\\Pongo\\${projectName}`,
          preset_context: body.presetContext || '',
        });

        db.prepare(`
          INSERT INTO conversations (id, user_id, name, type, extra, status, source, project_id, folder_id, name_source, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
          conversationId,
          userId,
          body.sessionName || `${agentName} - ${new Date().toLocaleTimeString('id-ID', {hour:'2-digit',minute:'2-digit'})}`,
          'acp',
          extra,
          'pending',
          'aionui',
          proj ? proj.project_id : null,
          folder ? folder.folder_id : null,
          'user',
          now,
          now
        );

        // Create assistant snapshot (required for AION UI to show in list)
        const keqoSnapshot = db.prepare('SELECT * FROM conversation_assistant_snapshots WHERE conversation_id = ?').get('c7c5d0cd');
        if (keqoSnapshot) {
          db.prepare(`
            INSERT INTO conversation_assistant_snapshots (
              conversation_id, assistant_definition_id, assistant_id, assistant_source,
              agent_id, rules_content, default_model_mode, resolved_model_id,
              default_permission_mode, resolved_permission_value,
              default_skills_mode, resolved_skill_ids, resolved_disabled_builtin_skill_ids,
              default_mcps_mode, resolved_mcp_ids, default_thought_level_mode,
              resolved_thought_level_value, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          `).run(
            conversationId,
            keqoSnapshot.assistant_definition_id,
            keqoSnapshot.assistant_id,
            keqoSnapshot.assistant_source,
            agentId,
            keqoSnapshot.rules_content,
            keqoSnapshot.default_model_mode,
            keqoSnapshot.resolved_model_id,
            keqoSnapshot.default_permission_mode,
            keqoSnapshot.resolved_permission_value,
            keqoSnapshot.default_skills_mode,
            keqoSnapshot.resolved_skill_ids,
            keqoSnapshot.resolved_disabled_builtin_skill_ids,
            keqoSnapshot.default_mcps_mode,
            keqoSnapshot.resolved_mcp_ids,
            keqoSnapshot.default_thought_level_mode,
            keqoSnapshot.resolved_thought_level_value,
            now,
            now
          );
        }

        // Create ACP session entry
        const sessionId = uuid();
        const sessionConfig = JSON.stringify({
          runtime: {
            config_selections: {
              agent: 'default',
              effort: 'max',
              mode: 'bypassPermissions',
              model: 'fable',
            },
            current_mode_id: 'bypassPermissions',
            current_model_id: 'fable',
          },
        });

        db.prepare(`
          INSERT INTO acp_session (conversation_id, agent_source, agent_id, session_id, session_status, session_config, last_active_at)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        `).run(
          conversationId,
          'builtin',
          agentId,
          sessionId,
          'idle',
          sessionConfig,
          now
        );

        // Insert initial message
        insertMessage(conversationId, prompt, 'user');

        sendJson(res, 200, {
          success: true,
          conversationId: conversationId,
          sessionId: sessionId,
          agentId: agentId,
          agentName: agentName,
          project: projectName,
          message: `Agent "${agentName}" created in ${projectName}. Send messages via /send-message.`,
        });
      } catch (err) {
        sendJson(res, 500, { success: false, error: err.message });
      }
      return;
    }

    // ── Send Message via aioncore.exe session send-message (s/send) ──
    if (url.pathname === '/send-message' && req.method === 'POST') {
      const body = await parseBody(req);
      log(req.method, req.url, body);

      if (!body.to || !body.message) {
        sendJson(res, 400, { error: 'Missing "to" (conversationId) or "message" field' });
        return;
      }

      try {
        const { execSync } = require('child_process');
        const aioncorePath = path.join(
          process.env.LOCALAPPDATA || path.join(process.env.HOME, 'AppData', 'Local'),
          'Programs', 'AionUi', 'resources', 'bundled-aioncore', 'win32-x64', 'aioncore.exe'
        );

        const payload = JSON.stringify({ to: body.to, message: body.message });
        const result = execSync(`"${aioncorePath}" session send-message`, {
          input: payload,
          encoding: 'utf8',
          timeout: 15000,
          env: { ...process.env }, // Inherit all env vars (AIONUI_BASE_URL, etc.)
        });

        const parsed = JSON.parse(result);
        sendJson(res, parsed.success ? 200 : 400, {
          success: parsed.success,
          data: parsed.data || null,
          error: parsed.error || null,
          message: parsed.success ? 'Message delivered via s/send' : (parsed.error?.message || 'Failed'),
        });
      } catch (err) {
        // Try to parse error output (aioncore returns JSON on stderr too)
        let errorData = null;
        try {
          if (err.stderr) errorData = JSON.parse(err.stderr.toString());
          else if (err.stdout) errorData = JSON.parse(err.stdout.toString());
        } catch (e) { /* ignore */ }

        if (errorData && errorData.error) {
          sendJson(res, 400, {
            success: false,
            error: errorData.error,
            message: errorData.error.message || 's/send failed',
          });
        } else {
          sendJson(res, 500, {
            success: false,
            error: err.message,
            message: 'Failed to execute aioncore.exe session send-message',
          });
        }
      }
      return;
    }

    // ── Send Prompt to AION UI ──
    if (url.pathname === '/send' && req.method === 'POST') {
      const body = await parseBody(req);
      log(req.method, req.url, body);

      if (!body.prompt) {
        sendJson(res, 400, { error: 'Missing "prompt" field' });
        return;
      }

      try {
        const userId = getOrCreateUser();
        let conversationId = body.conversationId;

        // Always use keqo conversation (no new conversations = no UI refresh)
        const keqoConv = db.prepare('SELECT id FROM conversations WHERE name = ? LIMIT 1').get('keqo');
        if (keqoConv) {
          conversationId = keqoConv.id;
          console.log(`  → Using keqo: ${conversationId}`);
        } else if (!conversationId) {
          conversationId = createAcpConversation(userId, body.prompt || 'Session');
          console.log(`  → Created new: ${conversationId}`);
        } else {
          console.log(`  → Using provided: ${conversationId}`);
        }

        insertMessage(conversationId, body.prompt, 'user');

        // Update conversation timestamp to trigger AION UI refresh
        db.prepare('UPDATE conversations SET updated_at = ?, status = ? WHERE id = ?')
          .run(Date.now(), 'pending', conversationId);

        // Also update keqo timestamp to force AION UI refresh conversation list
        const keqoConv2 = db.prepare('SELECT id FROM conversations WHERE name = ? LIMIT 1').get('keqo');
        if (keqoConv2 && keqoConv2.id !== conversationId) {
          db.prepare('UPDATE conversations SET updated_at = ? WHERE id = ?').run(Date.now(), keqoConv2.id);
        }

        sendJson(res, 200, {
          success: true,
          conversationId: conversationId,
          message: 'Prompt sent to AION UI. Check AION UI for processing.',
          prompt: body.prompt,
        });
      } catch (err) {
        sendJson(res, 500, { success: false, error: err.message });
      }
      return;
    }

    // ── Get Conversation Status ──
    if (url.pathname === '/status' && req.method === 'GET') {
      const convId = url.searchParams.get('id');
      if (!convId) {
        sendJson(res, 400, { error: 'Missing "id" query parameter' });
        return;
      }

      const messages = db.prepare(`
        SELECT id, type, content, status, created_at
        FROM messages
        WHERE conversation_id = ?
        ORDER BY created_at ASC
      `).all(convId);

      const conversation = db.prepare('SELECT * FROM conversations WHERE id = ?').get(convId);

      sendJson(res, 200, {
        conversation,
        messages: messages.map(m => ({
          ...m,
          content: JSON.parse(m.content || '{}'),
        })),
      });
      return;
    }

    // ── Get Latest Output from AION (round-trip) ──
    if (url.pathname === '/output' && req.method === 'GET') {
      const convId = url.searchParams.get('id');
      if (!convId) {
        sendJson(res, 400, { error: 'Missing "id" query parameter' });
        return;
      }

      // Get latest text output messages (exclude thinking/tool_call)
      const outputs = db.prepare(`
        SELECT id, type, content, status, created_at
        FROM messages
        WHERE conversation_id = ?
          AND type = 'text'
          AND status = 'finish'
        ORDER BY created_at DESC
        LIMIT 3
      `).all(convId);

      // Parse content
      const parsedOutputs = outputs.map(m => {
        try {
          const c = JSON.parse(m.content || '{}');
          return {
            id: m.id,
            type: m.type,
            text: c.text || c.content || '',
            status: m.status,
            created_at: m.created_at,
          };
        } catch (e) {
          return { id: m.id, type: m.type, text: '', status: m.status, created_at: m.created_at };
        }
      });

      // Get conversation status
      const conv = db.prepare('SELECT status FROM conversations WHERE id = ?').get(convId);

      sendJson(res, 200, {
        conversationId: convId,
        conversationStatus: conv?.status || 'unknown',
        outputs: parsedOutputs,
        hasOutput: parsedOutputs.length > 0,
      });
      return;
    }

    // ── List Recent Conversations ──
    if (url.pathname === '/conversations' && req.method === 'GET') {
      const limit = parseInt(url.searchParams.get('limit') || '10');
      const conversations = db.prepare(`
        SELECT id, name, status, source, created_at, updated_at
        FROM conversations
        WHERE source = 'aionui'
        ORDER BY created_at DESC
        LIMIT ?
      `).all(limit);

      sendJson(res, 200, { conversations });
      return;
    }

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
  console.log('  Flutter ↔ AION UI Bridge Server');
  console.log('═══════════════════════════════════════════════════════════');
  console.log(`  URL: http://localhost:${PORT}`);
  console.log(`  AION DB: ${AION_DB_PATH}`);
  console.log('');
  console.log('  Endpoints:');
  console.log('    GET  /health                    — Check status');
  console.log('    POST /send                      — Send prompt to AION UI (keqo session)');
  console.log('    POST /create-session            — Create new agent session (legacy, restarts AION UI)');
  console.log('    POST /create-agent              — Create new agent session (smart, no restart)');
  console.log('    POST /send-message              — Send message via aioncore.exe session send-message (s/send)');
  console.log('    GET  /status?id=<conversation>   — Check conversation status');
  console.log('    GET  /output?id=<conversation>   — Get latest output from AION');
  console.log('    GET  /conversations             — List recent conversations');
  console.log('');
  console.log('  Flutter app flow:');
  console.log('    1. POST /create-agent { agentName, projectName, prompt }');
  console.log('    2. POST /send-message { to: conversationId, message }');
  console.log('    3. GET  /output?id=<conversationId>  (poll for response)');
  console.log('═══════════════════════════════════════════════════════════');
  console.log('');
});
