// DocuCraft — Slide Error Boundary Widget
// Membungkus rendering slide untuk mencegah crash aplikasi akibat elemen korup.
// Mengganti slide yang rusak dengan kartu error yang ramah.

import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

/// Wraps any child widget to catch render-time errors gracefully.
/// On error, displays a user-friendly placeholder instead of crashing.
class SlideErrorBoundary extends StatefulWidget {
  final Widget child;
  final String slideId;
  final String? slideTitle;
  final VoidCallback? onError;

  const SlideErrorBoundary({
    super.key,
    required this.child,
    required this.slideId,
    this.slideTitle,
    this.onError,
  });

  @override
  State<SlideErrorBoundary> createState() => _SlideErrorBoundaryState();
}

class _SlideErrorBoundaryState extends State<SlideErrorBoundary> {
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _hasError = false;
  }

  @override
  void didUpdateWidget(covariant SlideErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset error state when slide changes
    if (widget.slideId != oldWidget.slideId) {
      _hasError = false;
    }
  }

  void _handleError(String message) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorMessage = message;
    });
    widget.onError?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _errorPlaceholder();
    }
    return widget.child;
  }

  Widget _errorPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withAlpha(60), width: 1),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: AppTheme.error.withAlpha(200), size: 40),
          const SizedBox(height: 12),
          Text(
            '⚠️ Slide Error',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            widget.slideTitle ?? widget.slideId,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage.isNotEmpty ? _errorMessage : 'Element tidak bisa dirender',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() { _hasError = false; }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Coba Lagi', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
