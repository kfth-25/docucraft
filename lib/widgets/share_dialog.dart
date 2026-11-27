// DocuCraft — ShareDialog (DIALOG SHARE — STUB BELUM SELESAI)
// Placeholder sementara untuk dialog share/export.
// TODO: Implementasi widget ShareDialog yang sesungguhnya.

// Stub placeholder — ShareDialog
// TODO: Implement real ShareDialog widget

import 'package:flutter/material.dart';

class ShareDialog extends StatelessWidget {
  final String documentId;
  const ShareDialog({super.key, required this.documentId});

  static void show(BuildContext context, {required String documentId}) {
    showDialog(
      context: context,
      builder: (_) => ShareDialog(documentId: documentId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share Document'),
      content: Text('Document ID: $documentId'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
