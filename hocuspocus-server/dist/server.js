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
const server_1 = require("@hocuspocus/server");
const extension_database_1 = require("@hocuspocus/extension-database");
const extension_logger_1 = require("@hocuspocus/extension-logger");
const http = __importStar(require("http"));
const jsonwebtoken_1 = require("jsonwebtoken");
const documentManager_1 = require("./documentManager");
const awarenessManager_1 = require("./awarenessManager");
// Configuration
const PORT = parseInt(process.env.PORT || '9101', 10);
const JWT_SECRET = process.env.JWT_SECRET || 'docucraft-dev-secret-change-in-production';
const DB_PATH = process.env.DB_PATH || './data/docucraft.db';
const MAX_PAYLOAD_SIZE = 1024 * 1024; // 1MB
const PING_INTERVAL = 30000;
const PING_TIMEOUT = 5000;
// Initialize database
const documentManager = new documentManager_1.DocumentManager(DB_PATH);
const awarenessManager = new awarenessManager_1.AwarenessManager();
console.log('🚀 Starting DocuCraft Hocuspocus Server...');
console.log(`   Port: ${PORT}`);
console.log(`   Database: ${DB_PATH}`);
// HTTP server for health checks and REST API
const httpServer = http.createServer(async (req, res) => {
    // CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    if (req.method === 'OPTIONS') {
        res.writeHead(204);
        res.end();
        return;
    }
    // Health check
    if (req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'ok', timestamp: new Date().toISOString() }));
        return;
    }
    // REST API for document management
    if (req.url?.startsWith('/api/documents')) {
        await handleDocumentApi(req, res);
        return;
    }
    res.writeHead(404);
    res.end('Not Found');
});
// Start HTTP server
httpServer.listen(PORT + 1, () => {
    console.log(`🌐 HTTP API server running on port ${PORT + 1}`);
});
// Hocuspocus WebSocket server
const hocuspocus = new server_1.Hocuspocus({
    async onAuthenticate(payload) {
        const { token, documentName } = payload;
        if (!token) {
            console.warn(`❌ No token provided for document: ${documentName}`);
            return false;
        }
        try {
            const decoded = (0, jsonwebtoken_1.verify)(token, JWT_SECRET);
            if (!decoded.userId || !decoded.userName) {
                console.warn(`❌ Invalid token payload: ${JSON.stringify(decoded)}`);
                return false;
            }
            // Check document access permission
            const hasAccess = await documentManager.checkAccess(documentName, decoded.userId);
            if (!hasAccess) {
                console.warn(`❌ Access denied for user ${decoded.userId} to document ${documentName}`);
                return false;
            }
            return true;
        }
        catch (error) {
            console.error('❌ Token verification failed:', error);
            return false;
        }
    },
    onStateless: async () => {
        return false; // We require authentication for all connections
    },
    onListen: async (payload) => {
        console.log(`🌐 WebSocket server listening on port ${payload.port}`);
    },
    debounce: 100,
    extensions: [
        new extension_database_1.Database({
            fetch: async (payload) => {
                try {
                    const doc = await documentManager.loadDocument(payload.documentName);
                    return doc ? new Uint8Array(doc.data) : null;
                }
                catch (error) {
                    console.error(`❌ Failed to fetch document ${payload.documentName}:`, error);
                    return null;
                }
            },
            store: async (payload) => {
                try {
                    await documentManager.saveDocument(payload.documentName, payload.state);
                }
                catch (error) {
                    console.error(`❌ Failed to store document ${payload.documentName}:`, error);
                }
            },
        }),
        new extension_logger_1.Logger(),
    ],
});
// Start the server with WebSocket options
hocuspocus.listen(PORT, () => {
    console.log(`✅ Hocuspocus WebSocket server running on port ${PORT}`);
    console.log(`   WebSocket: ws://localhost:${PORT}`);
    console.log(`   HTTP API: http://localhost:${PORT + 1}`);
});
// HTTP server for health checks and REST API
httpServer.listen(PORT + 1, () => {
    console.log(`🌐 HTTP API server running on port ${PORT + 1}`);
});
// REST API handlers
async function handleDocumentApi(req, res) {
    const url = new URL(req.url || '', `http://localhost:${PORT + 1}`);
    const path = url.pathname.replace('/api/documents', '');
    const method = req.method;
    // Parse body
    let body = '';
    for await (const chunk of req) {
        body += chunk;
    }
    try {
        // GET /api/documents - List user's documents
        if (method === 'GET' && (path === '' || path === '/')) {
            const token = url.searchParams.get('token');
            if (!token) {
                res.writeHead(401, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'Unauthorized' }));
                return;
            }
            const decoded = (0, jsonwebtoken_1.verify)(token, JWT_SECRET);
            const docs = await documentManager.listDocuments(decoded.userId);
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ documents: docs }));
            return;
        }
        // GET /api/documents/:id - Get document info
        if (method === 'GET' && path.startsWith('/') && path.length > 1) {
            const docId = path.substring(1);
            const token = url.searchParams.get('token');
            if (!token) {
                res.writeHead(401, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'Unauthorized' }));
                return;
            }
            const decoded = (0, jsonwebtoken_1.verify)(token, JWT_SECRET);
            const hasAccess = await documentManager.checkAccess(docId, decoded.userId);
            if (!hasAccess) {
                res.writeHead(403, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'Forbidden' }));
                return;
            }
            const doc = await documentManager.loadDocument(docId);
            if (!doc) {
                res.writeHead(404, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'Document not found' }));
                return;
            }
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ document: doc }));
            return;
        }
        // POST /api/documents - Create new document
        if (method === 'POST' && (path === '' || path === '/')) {
            const token = url.searchParams.get('token');
            if (!token) {
                res.writeHead(401, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'Unauthorized' }));
                return;
            }
            const decoded = (0, jsonwebtoken_1.verify)(token, JWT_SECRET);
            const data = JSON.parse(body);
            const doc = await documentManager.createDocument(data.name || 'Untitled Presentation', decoded.userId, decoded.userName);
            res.writeHead(201, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ document: doc }));
            return;
        }
        // DELETE /api/documents/:id - Delete document
        if (method === 'DELETE' && path.startsWith('/') && path.length > 1) {
            const docId = path.substring(1);
            const token = url.searchParams.get('token');
            if (!token) {
                res.writeHead(401, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'Unauthorized' }));
                return;
            }
            const decoded = (0, jsonwebtoken_1.verify)(token, JWT_SECRET);
            const hasAccess = await documentManager.checkAccess(docId, decoded.userId);
            if (!hasAccess) {
                res.writeHead(403, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'Forbidden' }));
                return;
            }
            await documentManager.deleteDocument(docId, decoded.userId);
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ success: true }));
            return;
        }
        res.writeHead(404);
        res.end('Not Found');
    }
    catch (error) {
        console.error('API Error:', error);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Internal Server Error' }));
    }
}
// Graceful shutdown
process.on('SIGTERM', async () => {
    console.log('🛑 Shutting down...');
    await documentManager.close();
    hocuspocus.destroy();
    httpServer.close();
    process.exit(0);
});
process.on('SIGINT', async () => {
    console.log('🛑 Shutting down...');
    await documentManager.close();
    hocuspocus.destroy();
    httpServer.close();
    process.exit(0);
});
//# sourceMappingURL=server.js.map