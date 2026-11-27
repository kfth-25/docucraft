import { WebSocket } from 'ws';

export interface CursorState {
  slideIndex: number;
  elementId?: string;
  x: number;
  y: number;
}

export interface SelectionState {
  elementId: string;
  start: number;
  end: number;
}

export interface AwarenessState {
  cursor: CursorState;
  selection?: SelectionState;
  viewportSlideIndex: number;
  isEditing: boolean;
  user: {
    id: string;
    name: string;
    color: string;
    avatar?: string;
  };
}

export interface PresenceUser {
  userId: string;
  name: string;
  color: string;
  avatarUrl?: string;
  cursor?: CursorState;
  selection?: SelectionState;
  viewportSlideIndex: number;
  isEditing: boolean;
  isOnline: boolean;
  lastSeen: Date;
}

export interface AwarenessUpdate {
  clientId: string;
  state: AwarenessState;
  timestamp: number;
}

interface UserConnection {
  ws: WebSocket;
  userId: string;
  userName: string;
  userColor: string;
  documentId: string;
  lastAwarenessState?: any;
  lastSeen: Date;
}

export class AwarenessManager {
  // documentId -> clientId -> UserConnection
  private users: Map<string, Map<string, UserConnection>> = new Map();
  // documentId -> clientId -> last awareness state
  private awarenessStates: Map<string, Map<string, { state: any; timestamp: number }>> = new Map();
  // Broadcast callbacks
  private broadcastCallbacks: Map<string, (message: any, excludeClientId?: string) => void> = new Map();

  registerBroadcastCallback(documentId: string, callback: (message: any, excludeClientId?: string) => void): void {
    this.broadcastCallbacks.set(documentId, callback);
  }

  unregisterBroadcastCallback(documentId: string): void {
    this.broadcastCallbacks.delete(documentId);
  }

  addUser(documentId: string, clientId: string, ws: WebSocket, userId: string, userName: string, userColor: string): void {
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

  removeUser(documentId: string, clientId: string): void {
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

  updateAwareness(documentId: string, clientId: string, state: any): void {
    const docStates = this.awarenessStates.get(documentId);
    if (!docStates) return;

    const user = this.getUser(documentId, clientId);
    if (!user) return;

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

    this.awarenessStates.get(documentId)!.set(clientId, {
      state: awarenessState,
      timestamp: Date.now(),
    });

    // Broadcast to other clients
    this.broadcastAwarenessUpdate(documentId, clientId, 'update', state);
  }

  getUser(documentId: string, clientId: string): { userId: string; userName: string; userColor: string } | null {
    const docUsers = this.users.get(documentId);
    if (!docUsers) return null;

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

  getUsers(documentId: string): any[] {
    const docUsers = this.users.get(documentId);
    if (!docUsers) return [];

    const result: any[] = [];
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

  getOnlineUsers(documentId: string): any[] {
    const docUsers = this.users.get(documentId);
    if (!docUsers) return [];

    const result: any[] = [];
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

  getAwarenessStates(documentId: string): Map<string, any> {
    const docStates = this.awarenessStates.get(documentId);
    if (!docStates) return new Map();

    const result = new Map();
    for (const [clientId, { state }] of docStates) {
      result.set(clientId, state);
    }
    return result;
  }

  getUserCount(documentId: string): number {
    const docUsers = this.users.get(documentId);
    return docUsers ? docUsers.size : 0;
  }

  private broadcastAwarenessUpdate(documentId: string, clientId: string, action: 'online' | 'offline' | 'update', state?: any): void {
    const callback = this.broadcastCallbacks.get(documentId);
    if (!callback) return;

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