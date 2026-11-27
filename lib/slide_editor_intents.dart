// DocuCraft — Keyboard Shortcut Intents for SlideEditor
// Mendeklarasikan kelas Intent yang dipakai widget Shortcuts untuk Ctrl+C/V, Delete, Undo/Redo, dll.

import 'package:flutter/material.dart';

class CopyIntent extends Intent {
  const CopyIntent();
}

class PasteIntent extends Intent {
  const PasteIntent();
}

class DeleteIntent extends Intent {
  const DeleteIntent();
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class AddSlideIntent extends Intent {
  const AddSlideIntent();
}
