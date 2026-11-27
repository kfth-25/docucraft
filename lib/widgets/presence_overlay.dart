// DocuCraft — Presence Overlay Widget
// Menampilkan kursor, seleksi, dan status online user lain di canvas
// Dirender sebagai overlay di atas SlideCanvas

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../collab/presence.dart';
import '../collab/collab_web_socket_provider.dart';
import '../themes/app_theme.dart';

/// Overlay that shows other users' presence on the canvas
class PresenceOverlay extends StatefulWidget {
  final CollabWebSocketProvider yjsProvider;
  final double canvasWidth;
  final double canvasHeight;

  const PresenceOverlay({
    super.key,
    required this.yjsProvider,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  @override
  State<PresenceOverlay> createState() => _PresenceOverlayState();
}

class _PresenceOverlayState extends State<PresenceOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PresenceUser>>(
      stream: widget.yjsProvider.awarenessStream,
      builder: (context, snapshot) {
        final users = snapshot.data ?? [];
        if (users.isEmpty) return const SizedBox.shrink();

        return Stack(
          children: [
            // User cursors
            for (final user in users)
              if (user.cursor != null)
                _buildCursor(user),
            // Online users bar at top-right
            Positioned(
              top: 8,
              right: 8,
              child: _buildOnlineBar(users),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCursor(PresenceUser user) {
    final cursor = user.cursor!;
    final color = _parseColor(user.color ?? '#6366F1');

    // Scale from design space (1920x1080) to actual widget size
    final x = cursor.x / 1920 * widget.canvasWidth;
    final y = cursor.y / 1080 * widget.canvasHeight;

    return Positioned(
      left: x,
      top: y,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (ctx, _) {
          return Stack(
            children: [
              // Cursor pointer
              Transform.rotate(
                angle: 0,
                child: CustomPaint(
                  size: const Size(20, 24),
                  painter: _CursorPainter(color: color),
                ),
              ),
              // Name label
              Positioned(
                top: 20,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)],
                  ),
                  child: Text(
                    user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Selection ring (if editing an element)
              if (cursor.elementId != null)
                Positioned(
                  left: -4,
                  top: -4,
                  right: -4,
                  bottom: -4,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: color.withValues(alpha: 0.4 + _pulseController.value * 0.3),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOnlineBar(List<PresenceUser> users) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Online dot
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          // User avatars (max 4 shown)
          ...users.take(4).map((user) => _buildAvatar(user)),
          if (users.length > 4)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '+${users.length - 4}',
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ),
          const SizedBox(width: 4),
          Text(
            '${users.length} online',
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(PresenceUser user) {
    final color = _parseColor(user.color ?? '#6366F1');
    final initials = user.name.split(' ').map((w) => w[0]).join().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(left: 4),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.surface, width: 2),
      ),
      child: Center(
        child: Text(
          initials.length > 2 ? initials.substring(0, 2) : initials,
          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF6366F1);
  }
}

/// Custom painter for the cursor pointer shape
class _CursorPainter extends CustomPainter {
  final Color color;

  _CursorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, 20)
      ..lineTo(5, 15)
      ..lineTo(10, 22)
      ..lineTo(13, 20)
      ..lineTo(8, 13)
      ..lineTo(15, 12)
      ..close();

    canvas.drawPath(path, paint);

    // White outline
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _CursorPainter oldDelegate) => color != oldDelegate.color;
}

/// Share Dialog — invite link + user management
class ShareDialog extends StatefulWidget {
  final String documentId;
  final List<PresenceUser> currentUsers;

  const ShareDialog({
    super.key,
    required this.documentId,
    this.currentUsers = const [],
  });

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  final TextEditingController _emailCtrl = TextEditingController();
  String _inviteLink = '';

  @override
  void initState() {
    super.initState();
    _inviteLink = 'https://docucraft.app/doc/${widget.documentId}';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.share, size: 20, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Bagikan Dokumen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Invite link
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface3,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_inviteLink, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _inviteLink));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🔗 Link disalin!'), behavior: SnackBarBehavior.floating),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(6)),
                        child: const Text('Salin', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Invite by email
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Undang via email...',
                        hintStyle: const TextStyle(color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.surface3,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      if (_emailCtrl.text.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('📧 Undangan terkirim ke ${_emailCtrl.text}'), behavior: SnackBarBehavior.floating),
                        );
                        _emailCtrl.clear();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: AppTheme.success, borderRadius: BorderRadius.circular(10)),
                      child: const Text('Kirim', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Online users
              if (widget.currentUsers.isNotEmpty) ...[
                Text('${widget.currentUsers.length} user online', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                ...widget.currentUsers.map((user) => _userRow(user)),
              ],

              const SizedBox(height: 8),
              // Permissions note
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Semua user dengan link bisa edit secara real-time',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userRow(PresenceUser user) {
    final color = _parseColor(user.color ?? '#6366F1');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.name.split(' ').map((w) => w[0]).join().toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(user.name, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary))),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          const Text('Editor', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF6366F1);
  }
}
