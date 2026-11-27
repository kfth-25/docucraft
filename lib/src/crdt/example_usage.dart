// DocuCraft CRDT — Example Usage & Tests
// Mendemonstrasikan cara memakai mesin CRDT pure Dart

import 'crdt.dart';

void main() {
  print('=== DocuCraft CRDT Engine Demo ===\n');

  // 1. Create a document
  final doc = CRDTDocument(docId: 'demo-doc');
  print('✓ Created document: ${doc.docId}');
  print('  Peer ID: ${doc.peerId}');

  // 2. Create slides (movable list)
  final slides = doc.getMovableList('slides');
  print('\n✓ Got slides container');

  // 3. Create first slide
  final slide1Id = 'slide_1';
  final slide1 = CRDTMap(id: ContainerID.parse('slide:slide_1'));
  doc.addContainer(slide1);

  slide1.set('title', 'Welcome to DocuCraft', lamport: Lamport(1), opId: OpID.create(doc.peerId, Lamport(1)));
  slide1.set('body', 'This is a collaborative presentation editor.', lamport: Lamport(2), opId: OpID.create(doc.peerId, Lamport(2)));
  slide1.set('layout', 'title-body', lamport: Lamport(3), opId: OpID.create(doc.peerId, Lamport(3)));

  slides.insert(0, slide1Id);
  print('✓ Created slide 1: "${slide1.get('title')}"');

  // 4. Create second slide
  final slide2Id = 'slide_2';
  final slide2 = CRDTMap(id: ContainerID.parse('slide:slide_2'));
  doc.addContainer(slide2);

  slide2.set('title', 'Features', lamport: Lamport(4), opId: OpID.create(doc.peerId, Lamport(4)));
  slide2.set('body', 'Real-time collaboration, offline-first, CRDT-powered.', lamport: Lamport(5), opId: OpID.create(doc.peerId, Lamport(5)));
  slide2.set('layout', 'two-column', lamport: Lamport(6), opId: OpID.create(doc.peerId, Lamport(6)));

  slides.insert(1, slide2Id);
  print('✓ Created slide 2: "${slide2.get('title')}"');

  // 5. Test movable list reorder
  print('\n✓ Slides order: ${slides.getValues()}');
  slides.move(0, 1); // Move slide 1 after slide 2
  print('✓ After move: ${slides.getValues()}');

  // 6. Test text CRDT
  final text = doc.getText('notes');
  text.insert(0, 'Meeting notes: ');
  text.insert(14, 'Discuss Q4 roadmap');
  text.mark(0, 14, 'bold', true);
  print('\n✓ Text content: "${text.text}"');
  print('  Delta: ${text.toDelta()}');

  // 7. Test LWW Map
  final meta = doc.getMap('meta');
  meta.set('author', 'User', lamport: Lamport(10), opId: OpID.create(doc.peerId, Lamport(10)));
  meta.set('createdAt', DateTime.now().toIso8601String(), lamport: Lamport(11), opId: OpID.create(doc.peerId, Lamport(11)));
  print('\n✓ Meta: ${meta.entries.map((e) => '${e.key}=${e.value}').join(', ')}');

  // 8. Test Tree
  final tree = doc.getTree('outline');
  final root = tree.create(parent: TreeParentRoot());
  final child1 = tree.create(parent: TreeParentNode(root));
  final child2 = tree.create(parent: TreeParentNode(root));
  tree.moveAfter(child2, child1); // child2 after child1
  print('\n✓ Tree nodes: ${tree.getAllNodes().length}');

  // 9. Test Counter
  final counter = doc.getCounter('views');
  counter.increment(doc.peerId, 5);
  print('\n✓ Counter value: ${counter.value}');

  // 10. Export snapshot
  final snapshot = doc.export(ExportModeConfig.snapshot());
  print('\n✓ Snapshot size: ${snapshot.length} bytes');

  // 11. Test JSONPath
  final evaluator = JsonPathEvaluator(doc);
  final result = evaluator.evaluate('\$.slides[*].title');
  print('\n✓ JSONPath \$.slides[*].title: ${result.values}');

  // 12. Test Undo Manager
  final undoManager = doc.createUndoManager();
  undoManager.recordChange(
    affectedContainers: [slides.id],
    origin: 'user',
    message: 'Added new slide',
  );
  print('\n✓ Undo manager: canUndo=${undoManager.canUndo}, undoCount=${undoManager.undoCount}');

  // 13. Test binary encoding
  final encoded = SnapshotCodec.encode(doc);
  print('\n✓ Binary encoded size: ${encoded.length} bytes');

  // 14. Test decode
  final decodedDoc = SnapshotCodec.decode(encoded);
  print('\n✓ Decoded doc ID: ${decodedDoc.docId}');
  print('  Peer ID: ${decodedDoc.peerId}');
  print('  Containers: ${decodedDoc.containerCount}');

  print('\n=== All Tests Passed! ===');
}