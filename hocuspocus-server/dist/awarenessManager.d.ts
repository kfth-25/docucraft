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
export declare class AwarenessManager {
    private users;
    private awarenessStates;
    private broadcastCallbacks;
    registerBroadcastCallback(documentId: string, callback: (message: any, excludeClientId?: string) => void): void;
    unregisterBroadcastCallback(documentId: string): void;
    addUser(documentId: string, clientId: string, ws: WebSocket, userId: string, userName: string, userColor: string): void;
    removeUser(documentId: string, clientId: string): void;
    updateAwareness(documentId: string, clientId: string, state: any): void;
    getUser(documentId: string, clientId: string): {
        userId: string;
        userName: string;
        userColor: string;
    } | null;
    getUsers(documentId: string): any[];
    getOnlineUsers(documentId: string): any[];
    getAwarenessStates(documentId: string): Map<string, any>;
    getUserCount(documentId: string): number;
    private broadcastAwarenessUpdate;
}
//# sourceMappingURL=awarenessManager.d.ts.map