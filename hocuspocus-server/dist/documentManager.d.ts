export interface Document {
    id: string;
    name: string;
    data: Uint8Array;
    version: number;
    ownerId: string;
    ownerName: string;
    isPublic: boolean;
    collaborators: string[];
    editors: string[];
    createdAt: string;
    updatedAt: string;
}
export declare class DocumentManager {
    private db;
    private dbPath;
    private sql;
    constructor(dbPath: string);
    private initDatabase;
    private initSchema;
    createDocument(name: string, ownerId: string, ownerName: string): Promise<any>;
    loadDocument(documentId: string): Promise<{
        id: string;
        data: Uint8Array;
        version: number;
    } | null>;
    saveDocument(documentId: string, state: Uint8Array): Promise<void>;
    deleteDocument(documentId: string, userId: string): Promise<void>;
    listDocuments(userId: string): Promise<any[]>;
    checkAccess(documentId: string, userId: string): Promise<boolean>;
    checkWriteAccess(documentId: string, userId: string): Promise<boolean>;
    updateDocumentMetadata(documentId: string, updates: Partial<{
        name: string;
        isPublic: boolean;
        collaborators: string[];
        editors: string[];
    }>): Promise<void>;
    private waitForDb;
    private saveToDisk;
    close(): void;
}
//# sourceMappingURL=documentManager.d.ts.map