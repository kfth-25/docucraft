// DocuCraft — UndoRedoManager Unit Tests

import 'package:test/test.dart';
import 'package:docucraft_app/providers/undo_redo_manager.dart';
import 'package:docucraft_app/models/slide.dart';

void main() {
  group('UndoRedoManager', () {
    late UndoRedoManager manager;

    setUp(() {
      manager = UndoRedoManager();
    });

    test('initial state is empty', () {
      expect(manager.canUndo, false);
      expect(manager.canRedo, false);
      expect(manager.undoCount, 0);
      expect(manager.redoCount, 0);
    });

    test('pushUndo adds to undo stack', () {
      final slides = [Slide(title: 'Slide 1'), Slide(title: 'Slide 2')];
      manager.pushUndo(slides, 0);

      expect(manager.canUndo, true);
      expect(manager.undoCount, 1);
      expect(manager.redoCount, 0);
    });

    test('pushUndo clears redo stack', () {
      final slides = [Slide(title: 'Slide 1'), Slide(title: 'Slide 2')];
      manager.pushUndo(slides, 0);
      manager.undo(); // Move to redo
      manager.pushUndo([Slide(title: 'New State')], 1); // Push new state should clear redo

      expect(manager.redoCount, 0);
    });

    test('undo returns snapshot and moves to redo', () {
      // Push initial state
      final state1 = [Slide(title: 'State A')];
      manager.pushUndo(state1, 0);

      // Push state 2
      final state2 = [Slide(title: 'State B')];
      manager.pushUndo(state2, 0);

      // Undo should return state1 and move state2 to redo
      final snapshot = manager.undo();

      expect(snapshot, isNotNull);
      final slides = snapshot!['slides'] as List;
      expect(slides.length, 1);
      expect((slides[0] as Map)['title'], 'State A');
      expect(snapshot['currentIndex'], 0);
      expect(manager.canRedo, true);
      expect(manager.redoCount, 1);
    });

    test('undo returns null when stack empty', () {
      final result = manager.undo();
      expect(result, null);
    });

    test('redo returns snapshot and moves to undo', () {
      final state1 = [Slide(title: 'State A')];
      final state2 = [Slide(title: 'State B')];
      manager.pushUndo(state1, 0);
      manager.pushUndo(state2, 0);
      manager.undo(); // Now redo has state2, undo has state1

      final snapshot = manager.redo();

      expect(snapshot, isNotNull);
      final slides = snapshot!['slides'] as List;
      expect(slides.length, 1);
      expect((slides[0] as Map)['title'], 'State B');
      expect(manager.canUndo, true);
    });

    test('redo returns null when stack empty', () {
      final result = manager.redo();
      expect(result, null);
    });

    test('max history limit enforced', () {
      for (int i = 0; i < 35; i++) {
        manager.pushUndo([Slide(title: 'Slide $i')], 0);
      }

      expect(manager.undoCount, 30); // _maxHistory = 30
    });

    test('clear resets both stacks', () {
      final slides = [Slide(title: 'Slide 1'), Slide(title: 'Slide 2')];
      manager.pushUndo(slides, 0);
      manager.pushUndo([Slide(title: 'Slide 3')], 1);
      manager.undo();

      manager.clear();

      expect(manager.canUndo, false);
      expect(manager.canRedo, false);
      expect(manager.undoCount, 0);
      expect(manager.redoCount, 0);
    });

    test('timestamps recorded', () {
      final slides = [Slide(title: 'Slide 1')];
      manager.pushUndo(slides, 0);
      final timestamp = manager.undoTimestamps.first;

      expect(timestamp, isNotNull);
      expect(timestamp.isBefore(DateTime.now().add(Duration(seconds: 1))), true);
    });

    test('sequential undo/redo works correctly', () {
      // Initial state: A
      manager.pushUndo([Slide(title: 'A')], 0); // undo: [A]

      // Change to B
      manager.pushUndo([Slide(title: 'B')], 0); // undo: [A, B], redo: []

      // Change to C
      manager.pushUndo([Slide(title: 'C')], 0); // undo: [A, B, C], redo: []

      // Undo to B (moves C to redo)
      var snap = manager.undo(); // returns B, undo: [A, B], redo: [C]
      final slides = snap!['slides'] as List;
      expect((slides[0] as Map)['title'], 'B');

      // Undo to A (moves B to redo)
      snap = manager.undo(); // returns A, undo: [A], redo: [B, C]
      final slides2 = snap!['slides'] as List;
      expect((slides2[0] as Map)['title'], 'A');

      // Redo to B (moves B back to undo)
      snap = manager.redo(); // returns B, undo: [A, B], redo: [C]
      final slides3 = snap!['slides'] as List;
      expect((slides3[0] as Map)['title'], 'B');

      // Redo to C (moves C back to undo)
      snap = manager.redo(); // returns C, undo: [A, B, C], redo: []
      final slides4 = snap!['slides'] as List;
      expect((slides4[0] as Map)['title'], 'C');

      // Can't redo further
      expect(manager.redo(), null);
    });
  });
}