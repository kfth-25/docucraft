// DocuCraft — Splash Screen (Halaman Pembuka)
// Halaman pertama saat app dibuka: tampilkan branding + status koneksi
// server GenOffice (port 3001), lalu otomatis navigasi ke MainShell
// (dashboard tetap ada seperti biasa — splash hanya "selamat datang").
//
// Alur:
//   app start → SplashScreen → health check /api/v1/health (timeout 3s)
//     → tampilkan "Server Running" (hijau) atau "Server Offline" (kuning)
//     → tunggu minimal 2 detik (biar kebaca) → pushReplacement(MainShell)

import 'package:flutter/material.dart';
import '../main.dart' show MainShell;
import '../services/api_client.dart';
import '../themes/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse; // animasi titik status server
  bool _serverRunning = false; // hasil health check GenOffice
  bool _checking = true; // masih cek server?

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _boot();
  }

  /// Cek server GenOffice lalu lanjut ke dashboard.
  Future<void> _boot() async {
    final started = DateTime.now();

    // Health check singkat — splash tidak boleh nunggu lama.
    bool healthy = false;
    try {
      healthy = await GenOfficeClient()
          .healthCheck()
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      healthy = false;
    }

    // Pastikan splash tampil minimal 2 detik supaya status kebaca.
    final elapsed = DateTime.now().difference(started);
    if (elapsed < const Duration(seconds: 2)) {
      await Future.delayed(const Duration(seconds: 2) - elapsed);
    }

    if (!mounted) return;
    setState(() {
      _serverRunning = healthy;
      _checking = false;
    });

    // Tambah 700ms biar user sempat baca status "Server Running".
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    // Ganti ke shell utama (dashboard + nav bawah) — splash tidak ditumpuk.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Latar gradasi brand — indigo → gelap, kesan "product demo".
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primary, AppTheme.primaryDark, Color(0xFF1A237E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),

              // ── Logo + nama app ──
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 44,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'DocuCraft',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'AI Presentation & Document Studio',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),

              const Spacer(),

              // ── Status server (tulisan "Server Running" dsb.) ──
              _buildServerStatus(),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  /// Kartu status koneksi server GenOffice.
  Widget _buildServerStatus() {
    final Color statusColor;
    final String statusText;
    final String statusSub;

    if (_checking) {
      statusColor = Colors.white70;
      statusText = 'Checking server…';
      statusSub = 'Menghubungkan ke GenOffice :3001';
    } else if (_serverRunning) {
      statusColor = AppTheme.success;
      statusText = 'Server Running';
      statusSub = 'GenOffice terhubung — semua fitur aktif';
    } else {
      statusColor = AppTheme.warning;
      statusText = 'Server Offline';
      statusSub = 'Mode standalone — jalankan GenOffice untuk fitur AI';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indikator berdenyut (hijau = server jalan).
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: statusColor.withValues(alpha: 0.6), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusSub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (_checking) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
