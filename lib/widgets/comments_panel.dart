// DocuCraft — Comments Panel (Threaded, element-pinned)
//
// CATATAN: Ini prototipe UI sisi klien. Komentar sungguhan membutuhkan server
// backend untuk persistensi multi-user dan sinkronisasi real-time.

import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

class CommentsPanel extends StatefulWidget {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CommentsPanel(),
    );
  }

  const CommentsPanel({super.key});

  @override
  State<CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends State<CommentsPanel> {
  final TextEditingController _commentCtrl = TextEditingController();
  final TextEditingController _replyCtrl = TextEditingController();
  final List<_CommentThread> _threads = [];
  _CommentThread? _replyingToThread;

  @override
  void initState() {
    super.initState();
    // Show helpful tip instead of fake demo data
    _threads.add(
      _CommentThread(
        author: 'Saya',
        initials: 'A',
        avatarColor: AppTheme.primary,
        role: 'Editor',
        text: 'Selamat datang di komentar! Long-press elemen di canvas untuk memberi komentar.',
        time: 'Baru saja',
        elementLabel: null,
        replies: [],
      ),
    );
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _addComment() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _threads.insert(0, _CommentThread(
        author: 'Rina A.',
        initials: 'RA',
        avatarColor: const Color(0xFFF59E0B),
        role: 'Owner',
        text: text,
        time: 'Baru saja',
        elementLabel: text.contains('@') ? '📌 @mention' : null,
        replies: [],
      ));
    });
    _commentCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('💬 Komentar dikirim${text.contains('@') ? ' (mention terdeteksi!)' : ''}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _showReplyInput(thread) {
    _replyingToThread = thread;
    _replyCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface2,
        title: Text('Reply ke ${thread.author}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
        content: TextField(
          controller: _replyCtrl, autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Tulis balasan...', hintStyle: TextStyle(color: AppTheme.textMuted.withAlpha(100)),
            filled: true, fillColor: AppTheme.surface3,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); _replyingToThread = null; },
            child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted))),
          TextButton(onPressed: () { _submitReply(); Navigator.pop(ctx); },
            child: const Text('Kirim', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _submitReply() {
    final text = _replyCtrl.text.trim();
    final thread = _replyingToThread;
    if (text.isEmpty || thread == null) return;
    setState(() {
      thread.replies.add(_CommentReply(
        author: 'Saya', initials: 'S', avatarColor: AppTheme.primary,
        text: text, time: 'Baru saja',
      ));
      _replyingToThread = null;
      _replyCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('💬 Balasan dikirim'), behavior: SnackBarBehavior.floating, backgroundColor: AppTheme.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _handleBar(),
              _header(),
              // Threads
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _threads.length,
                  itemBuilder: (ctx, i) => _threadWidget(_threads[i]),
                ),
              ),
              // Comment input
              _inputBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _handleBar() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(2)),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withAlpha(12)))),
      child: Row(
        children: [
          const Icon(Icons.comment, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text('Komentar  (${_threads.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _threadWidget(_CommentThread thread) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _commentCard(thread.author, thread.initials, thread.avatarColor, thread.role, thread.text, thread.time, thread.elementLabel),
          // Replies
          if (thread.replies.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...thread.replies.map((r) => Padding(
              padding: const EdgeInsets.only(left: 32, top: 6),
              child: _replyCard(r),
            )),
          ],
          // Reply button
          GestureDetector(
            onTap: () {
              _showReplyInput(thread);
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 32, top: 6),
              child: Text('Reply', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentCard(String name, String initials, Color avatarColor, String role, String text, String time, String? elementLabel) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Avatar(initials: initials, color: avatarColor, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(width: 6),
                  Text(time, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                  if (role != 'Owner') ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: AppTheme.primary.withAlpha(30), borderRadius: BorderRadius.circular(6)),
                      child: Text(role, style: TextStyle(fontSize: 8, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
              if (elementLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.success.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                    child: Text(elementLabel, style: const TextStyle(fontSize: 8, color: AppTheme.success)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _replyCard(_CommentReply reply) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Avatar(initials: reply.initials, color: reply.avatarColor, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(reply.author, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(width: 4),
                  Text(reply.time, style: const TextStyle(fontSize: 8, color: AppTheme.textMuted)),
                ],
              ),
              const SizedBox(height: 2),
              Text(reply.text, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withAlpha(12)))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentCtrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tulis komentar... (@ untuk mention)',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppTheme.surface3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withAlpha(15)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _addComment(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _addComment,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.primary, const Color(0xFFA855F7)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.send, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String initials;
  final Color color;
  final double size;
  const Avatar({super.key, required this.initials, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.surface, width: 2),
      ),
      child: Center(
        child: Text(initials, style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}

class _CommentThread {
  final String author, initials, role, text, time;
  final Color avatarColor;
  final String? elementLabel;
  final List<_CommentReply> replies;
  _CommentThread({required this.author, required this.initials, required this.avatarColor, required this.role, required this.text, required this.time, this.elementLabel, required this.replies});
}

class _CommentReply {
  final String author, initials, text, time;
  final Color avatarColor;
  _CommentReply({required this.author, required this.initials, required this.avatarColor, required this.text, required this.time});
}
