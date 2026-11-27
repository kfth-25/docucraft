"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.DocumentManager = void 0;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
class DocumentManager {
    constructor(dbPath) {
        this.db = null;
        this.sql = null;
        this.dbPath = dbPath;
        this.initDatabase();
    }
    async initDatabase() {
        // Ensure directory exists
        const dir = path.dirname(this.dbPath);
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        // Initialize sql.js
        const sqlModule = await Promise.resolve().then(() => __importStar(require('sql.js')));
        this.sql = sqlModule.default;
        // Load existing database or create new one
        let dbData = null;
        if (fs.existsSync(this.dbPath)) {
            const fileData = fs.readFileSync(this.dbPath);
            dbData = new Uint8Array(fileData);
        }
        this.db = new this.sql.Database(dbData);
        this.initSchema();
        // Auto-save every 30 seconds
        setInterval(() => this.saveToDisk(), 30000);
    }
    initSchema() {
        if (!this.db)
            return;
        // Documents table
        this.db.run(`
      CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        data BLOB,
        version INTEGER DEFAULT 0,
        ownerId TEXT NOT NULL,
        ownerName TEXT NOT NULL,
        isPublic INTEGER DEFAULT 0,
        collaborators TEXT DEFAULT '[]',
        editors TEXT DEFAULT '[]',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      );
    `);
        // Awareness table
        this.db.run(`
      CREATE TABLE IF NOT EXISTS awareness (
        documentId TEXT NOT NULL,
        userId TEXT NOT NULL,
        state TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        PRIMARY KEY (documentId, userId),
        FOREIGN KEY (documentId) REFERENCES documents(id) ON DELETE CASCADE
      );
    `);
        // Indexes
        this.db.run(`
      CREATE INDEX IF NOT EXISTS idx_documents_owner ON documents(ownerId);
      CREATE INDEX IF NOT EXISTS idx_documents_updated ON documents(updatedAt);
      CREATE INDEX IF NOT EXISTS idx_awareness_document ON awareness(documentId);
    `);
    }
    async createDocument(name, ownerId, ownerName) {
        if (!this.db)
            await this.waitForDb();
        const id = `doc_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        const now = new Date().toISOString();
        const emptyDoc = new Uint8Array(); // Empty Yjs document
        const stmt = this.db.prepare(`
      INSERT INTO documents (id, name, data, version, ownerId, ownerName, isPublic, collaborators, editors, createdAt, updatedAt)
      VALUES (?, ?, ?, 0, ?, ?, 0, '[]', '[]', ?, ?)
    `);
        stmt.run(id, name, emptyDoc, ownerId, ownerName, now, now);
        return {
            id,
            name,
            version: 0,
            ownerId,
            ownerName,
            isPublic: false,
            collaborators: [],
            editors: [],
            createdAt: now,
            updatedAt: now,
        };
    }
    async loadDocument(documentId) {
        if (!this.db)
            await this.waitForDb();
        const stmt = this.db.prepare('SELECT id, data, version FROM documents WHERE id = ?');
        const row = stmt.get(documentId);
        if (!row)
            return null;
        return {
            id: row.id,
            data: row.data ? new Uint8Array(row.data) : new Uint8Array(),
            version: row.version,
        };
    }
    async saveDocument(documentId, state) {
        if (!this.db)
            await this.waitForDb();
        const stmt = this.db.prepare(`
      UPDATE documents SET data = ?, version = version + 1, updatedAt = ? WHERE id = ?
    `);
        stmt.run(Buffer.from(state), new Date().toISOString(), documentId);
    }
    async deleteDocument(documentId, userId) {
        if (!this.db)
            await this.waitForDb();
        // Check ownership
        const stmt = this.db.prepare('SELECT ownerId FROM documents WHERE id = ?');
        const doc = stmt.get(documentId);
        if (!doc || doc.ownerId !== userId) {
            throw new Error('Unauthorized: Not the document owner');
        }
        // Delete awareness records first
        this.db.prepare('DELETE FROM awareness WHERE documentId = ?').run(documentId);
        // Delete document
        this.db.prepare('DELETE FROM documents WHERE id = ?').run(documentId);
    }
    async listDocuments(userId) {
        const stmt = this.db.prepare(`
      SELECT id, name, version, ownerId, ownerName, isPublic, collaborators, editors, createdAt, updatedAt
      FROM documents
      WHERE ownerId = ? OR isPublic = 1 OR collaborators LIKE ? OR editors LIKE ?
      ORDER BY updatedAt DESC
    `);
        const rows = stmt.all(userId, `%${userId}%`, `%${userId}%`);
        return rows.map(row => ({
            id: row.id,
            name: row.name,
            version: row.version,
            ownerId: row.ownerId,
            ownerName: row.ownerName,
            isPublic: Boolean(row.isPublic),
            collaborators: JSON.parse(row.collaborators || '[]'),
            editors: JSON.parse(row.editors || '[]'),
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
        }));
    }
    async checkAccess(documentId, userId) {
        const stmt = this.db.prepare(`
      SELECT ownerId, isPublic, collaborators, editors FROM documents WHERE id = ?
    `);
        const doc = stmt.get(documentId);
        if (!doc)
            return false;
        // Owner has full access
        if (doc.ownerId === userId)
            return true;
        // Public read access
        if (doc.isPublic)
            return true;
        // Check collaborators (read access)
        const collaborators = JSON.parse(doc.collaborators || '[]');
        if (collaborators.includes(userId))
            return true;
        // Check editors (write access)
        const editors = JSON.parse(doc.editors || '[]');
        if (editors.includes(userId))
            return true;
        return false;
    }
    async checkWriteAccess(documentId, userId) {
        const stmt = this.db.prepare(`
      SELECT ownerId, editors FROM documents WHERE id = ?
    `);
        const doc = stmt.get(documentId);
        if (!doc)
            return false;
        // Owner has full access
        if (doc.ownerId === userId)
            return true;
        // Editors have write access
        const editors = JSON.parse(doc.editors || '[]');
        if (editors.includes(userId))
            return true;
        return false;
    }
    async updateDocumentMetadata(documentId, updates) {
        const fields = [];
        const values = [];
        if (updates.name !== undefined) {
            fields.push('name = ?');
            values.push(updates.name);
        }
        if (updates.isPublic !== undefined) {
            fields.push('isPublic = ?');
            values.push(updates.isPublic ? 1 : 0);
        }
        if (updates.collaborators !== undefined) {
            fields.push('collaborators = ?');
            values.push(JSON.stringify(updates.collaborators));
        }
        if (updates.editors !== undefined) {
            fields.push('editors = ?');
            values.push(JSON.stringify(updates.editors));
        }
        if (fields.length === 0)
            return;
        fields.push('updatedAt = ?');
        values.push(new Date().toISOString());
        values.push(documentId);
        const stmt = this.db.prepare(`UPDATE documents SET ${fields.join(', ')} WHERE id = ?`);
        stmt.run(...values);
    }
    waitForDb() {
        return new Promise((resolve) => {
            const check = setInterval(() => {
                if (this.db) {
                    clearInterval(check);
                    resolve();
                }
            }, 10);
        });
    }
    saveToDisk() {
        if (!this.db)
            return;
        try {
            const data = this.db.export();
            fs.writeFileSync(this.dbPath, Buffer.from(data));
        }
        catch (error) {
            console.error('Failed to save database:', error);
        }
    }
    close() {
        this.saveToDisk();
    }
}
exports.DocumentManager = DocumentManager;
//# sourceMappingURL=documentManager.js.map