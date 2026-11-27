// DocuCraft CRDT — Main Export
// Mesin CRDT pure Dart untuk DocuCraft

// ID inti
export 'id.dart' show
    PeerID,
    Lamport,
    OpID,
    ContainerID,
    ContainerType,
    TreeID,
    TreeParentId,
    TreeParentRoot,
    TreeParentNode,
    TreeParentDeleted,
    TreeParentUnexist;

// Version Vectors
export 'version_vector.dart' show
    VersionVector,
    Frontiers,
    ImVersionVector,
    VersionRange,
    VersionVectorDiff,
    IdSpan;

// Sequence Index (RLE-based)
export 'sequence_index.dart' show
    SequenceItem,
    RLEBlock,
    SequenceIndex,
    AliveIterator;

// Fractional Index
export 'fractional_index.dart' show
    FractionalIndex,
    TreeFractionalIndex;

// LWW Map
export 'lww_map.dart' show
    LWWEntry,
    LWWMap,
    MergeableKeyTracker;

// Text CRDT
export 'text_crdt.dart' show
    TextOpType,
    TextOp,
    TextDelta,
    TextCRDT;

// Containers
export 'container.dart' show
    CRDTContainer,
    ContainerFactory,
    CRDTList,
    CRDTMovableList,
    CRDTMap,
    CRDTText,
    CRDTTree,
    TreeNode,
    CRDTCounter;

// Document
export 'doc.dart' show
    ExportMode,
    ExportModeConfig,
    ImportStatus,
    DocEvent,
    Subscription,
    CRDTDocument,
    ExportModeConstants;

// Encoding
export 'encoding.dart' show
    BinaryConstants,
    BinaryEncoder,
    BinaryDecoder,
    OperationEncoder,
    OperationDecoder,
    SnapshotCodec;

// Diff & Time Travel
export 'diff.dart' show
    DiffOpType,
    DiffOp,
    DiffResult,
    DiffCalculator,
    CheckoutManager,
    VersionInfo,
    DocumentState,
    ShallowSnapshotManager;

// Undo
export 'undo.dart' show
    UndoAction,
    UndoItemMeta,
    UndoManager,
    UndoItem,
    RecordedOp,
    OriginTracker;

// JSONPath
export 'json_path.dart' show
    JsonPathResult,
    JsonPathEvaluator,
    JsonPathCallback,
    JsonPathSubscription;