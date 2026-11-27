const { DatabaseSync } = require('node:sqlite');
const db = new DatabaseSync('C:/Users/Pongo/AppData/Roaming/AionUi/aionui/aionui-backend.db');

const conv = db.prepare("SELECT id FROM conversations WHERE name = 'keqo' LIMIT 1").get();
if (!conv) { console.log('No keqo conversation'); process.exit(0); }

const msgs = db.prepare('SELECT id, type, content, status, created_at FROM messages WHERE conversation_id = ? ORDER BY created_at DESC LIMIT 6').all(conv.id);

msgs.forEach(m => {
  console.log('===');
  console.log('ID:', m.id.slice(0, 12), '| Type:', m.type, '| Status:', m.status);
  try {
    const c = JSON.parse(m.content || '{}');
    const text = c.text || c.content || JSON.stringify(c);
    console.log('Content:', text.substring(0, 400));
  } catch (e) {
    console.log('Raw:', String(m.content).substring(0, 400));
  }
});
