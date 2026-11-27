// DocuCraft — Undo/Redo Manager
// Diekstrak dari SlideProvider demi single responsibility

import 'package:flutter/material.dart';
import '../models/slide.dart';

class UndoRedoManager extends ChangeNotifier {
  final List<Map<String, dynamic>> _undoStack = [];
  final List<Map<String, dynamic>> _redoStack = [];
  final List<DateTime> _undoTimestamps = [];
  final List<DateTime> _redoTimestamps = [];
  static const int _maxHistory = 30;

  List<DateTime> get undoTimestamps => List.unmodifiable(_undoTimestamps);
  List<DateTime> get redoTimestamps => List.unmodifiable(_redoTimestamps);
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;

  Map<String, dynamic> _snapshot(List<Slide> slides, int currentIndex) => {
    'slides': slides.map((s) => s.toJson()).toList(),
    'currentIndex': currentIndex,
  };

  void pushUndo(List<Slide> slides, int currentIndex) {
    _undoStack.add(_snapshot(slides, currentIndex));
    _undoTimestamps.add(DateTime.now());
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
      _undoTimestamps.removeAt(0);
    }
    _redoStack.clear();
    _redoTimestamps.clear();
    notifyListeners();
  }

  /// Returns [slides, currentIndex] or null if nothing to undo
  /// Pops current state from undo, pushes to redo, returns new top of undo
  Map<String, dynamic>? undo() {
    if (_undoStack.isEmpty) return null;
    // Pop current state and move to redo
    final currentState = _undoStack.removeLast();
    _undoTimestamps.removeLast();
    _redoStack.add(currentState);
    _redoTimestamps.add(DateTime.now());
    // Return new top of undo stack (the state to restore to)
    if (_undoStack.isEmpty) return null;
    final prev = _undoStack.last;
    notifyListeners();
    return prev;
  }

  /// Returns [slides, currentIndex] or null if nothing to redo
  /// Pops from redo, pushes to undo, returns the redone state
  Map<String, dynamic>? redo() {
    if (_redoStack.isEmpty) return null;
    final nextState = _redoStack.removeLast();
    _redoTimestamps.removeLast();
    _undoStack.add(nextState);
    _undoTimestamps.add(DateTime.now());
    notifyListeners();
    return nextState;
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    _undoTimestamps.clear();
    _redoTimestamps.clear();
    notifyListeners();
  }
}