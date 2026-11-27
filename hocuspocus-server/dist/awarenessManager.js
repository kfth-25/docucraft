"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AwarenessManager = void 0;
class AwarenessManager {
    constructor() {
        // documentId -> clientId -> UserConnection
        this.users = new Map();
        // documentId -> clientId -> last awareness state
        this.awarenessStates = new Map();
        // Broadcast callbacks
        this.broadcastCallbacks = new Map();
    }
    registerBroadcastCallback(documentId, callback) {
        this.broadcastCallbacks.set(documentId, callback);
    }
    unregisterBroadcastCallback(documentId) {
        this.broadcastCallbacks.delete(documentId);
    }
    addUser(documentId, clientId, ws, userId, userName, userColor) {
        let docUsers = this.users.get(documentId);
        if (!docUsers) {
            docUsers = new Map();
            this.users.set(documentId, docUsers);
        }
        docUsers.set(clientId, {
            ws: ws,
            userId,
            userName,
            userColor,
            documentId,
            lastSeen: new Date(),
        });
        // Initialize awareness state for this document
        if (!this.awarenessStates.has(documentId)) {
            this.awarenessStates.set(documentId, new Map());
        }
    }
    removeUser(documentId, clientId) {
        const docUsers = this.users.get(documentId);
        if (docUsers) {
            docUsers.delete(clientId);
            if (docUsers.size === 0) {
                this.users.delete(documentId);
            }
        }
        // Remove awareness state
        const docStates = this.awarenessStates.get(documentId);
        if (docStates) {
            docStates.delete(clientId);
            if (docStates.size === 0) {
                this.awarenessStates.delete(documentId);
            }
        }
        // Broadcast user left
        this.broadcastAwarenessUpdate(documentId, clientId, 'offline');
    }
    updateAwareness(documentId, clientId, state) {
        const docStates = this.awarenessStates.get(documentId);
        if (!docStates)
            return;
        const user = this.getUser(documentId, clientId);
        if (!user)
            return;
        const awarenessState = {
            cursor: state.cursor,
            selection: state.selection,
            viewportSlideIndex: state.viewportSlideIndex,
            isEditing: state.isEditing,
            user: {
                id: state.userId,
                name: state.userName,
                color: state.userColor,
            },
        };
        this.awarenessStates.get(documentId).set(clientId, {
            state: awarenessState,
            timestamp: Date.now(),
        });
        // Broadcast to other clients
        this.broadcastAwarenessUpdate(documentId, clientId, 'update', state);
    }
    getUser(documentId, clientId) {
        const docUsers = this.users.get(documentId);
        if (!docUsers)
            return null;
        for (const [, user] of docUsers) {
            if (user.userId === clientId) {
                return {
                    userId: user.userId,
                    userName: user.userName,
                    userColor: user.userColor,
                };
            }
        }
        return null;
    }
    getUsers(documentId) {
        const docUsers = this.users.get(documentId);
        if (!docUsers)
            return [];
        const result = [];
        for (const [clientId, user] of docUsers) {
            const awareness = this.awarenessStates.get(documentId)?.get(user.documentId);
            result.push({
                userId: user.userId,
                name: user.userName,
                color: user.userColor,
                cursor: this.awarenessStates.get(documentId)?.get(user.documentId)?.state?.cursor,
                isOnline: true,
                lastSeen: new Date(),
            });
        }
        return result;
    }
    getOnlineUsers(documentId) {
        const docUsers = this.users.get(documentId);
        if (!docUsers)
            return [];
        const result = [];
        for (const [clientId, user] of docUsers) {
            const awareness = this.awarenessStates.get(documentId)?.get(user.documentId);
            result.push({
                userId: user.userId,
                name: user.userName,
                color: user.userColor,
                cursor: this.awarenessStates.get(documentId)?.get(user.documentId)?.state?.cursor,
                isOnline: true,
                lastSeen: new Date(),
            });
        }
        return result;
    }
    getAwarenessStates(documentId) {
        const docStates = this.awarenessStates.get(documentId);
        if (!docStates)
            return new Map();
        const result = new Map();
        for (const [clientId, { state }] of docStates) {
            result.set(clientId, state);
        }
        return result;
    }
    getUserCount(documentId) {
        const docUsers = this.users.get(documentId);
        return docUsers ? docUsers.size : 0;
    }
    broadcastAwarenessUpdate(documentId, clientId, action, state) {
        const callback = this.broadcastCallbacks.get(documentId);
        if (!callback)
            return;
        const message = {
            type: 'awareness',
            clientId,
            action,
            state,
            timestamp: Date.now(),
        };
        callback({
            type: 'awareness',
            clientId,
            action,
            data: {
                userId: state?.user?.id,
                userName: state?.user?.name,
                color: state?.user?.color,
                cursor: state?.cursor,
                selection: state?.selection,
                viewportSlideIndex: state?.viewportSlideIndex,
                isEditing: state?.isEditing,
            },
        }, clientId);
    }
}
exports.AwarenessManager = AwarenessManager;
//# sourceMappingURL=awarenessManager.js.map