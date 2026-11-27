// DocuCraft — Profile Screen (KEKO Intelligence Light Design)
// Sesuai desain Stitch: Verified badge, stats, Smart Tip, Settings

import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface2,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppTheme.primary, size: 22),
          onPressed: () {},
        ),
        title: const Text(
          'KEKO',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.outline),
            ),
            child: const CircleAvatar(
              radius: 17,
              backgroundColor: AppTheme.surface3,
              child: Icon(Icons.person, size: 18, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // ── Profile Header ──
            _buildProfileHeader(),
            const SizedBox(height: 24),

            // ── Stats Row ──
            _buildStatsRow(),
            const SizedBox(height: 20),

            // ── AI Smart Tip ──
            _buildSmartTip(),
            const SizedBox(height: 28),

            // ── Settings ──
            _buildSettingsSection(),
            const SizedBox(height: 20),

            // ── Logout ──
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  // ── Avatar + Name + Badge ──
  Widget _buildProfileHeader() {
    return Column(
      children: [
        // Avatar with gradient ring + verified badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 96, height: 96,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondaryDark],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.surface, width: 2),
                  color: AppTheme.surface3,
                ),
                child: const CircleAvatar(
                  radius: 42,
                  backgroundColor: AppTheme.surface3,
                  child: Icon(Icons.person, size: 40, color: AppTheme.textMuted),
                ),
              ),
            ),
            // Verified badge
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.surface, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                ),
                child: const Icon(Icons.verified, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Name
        const Text(
          'Alex Keko',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),

        // Pro AI Plan badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Pro AI Plan',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textOnPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ── 3-Column Stats ──
  Widget _buildStatsRow() {
    return Row(
      children: [
        _statBox('128', 'Docs'),
        const SizedBox(width: 10),
        _statBox('42', 'Presentations'),
        const SizedBox(width: 10),
        _statBox('75%', 'Storage'),
      ],
    );
  }

  Widget _statBox(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface3,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AI Smart Tip (glass effect) ──
  Widget _buildSmartTip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.secondaryDark.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryDark.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.secondaryDark.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lightbulb,
              color: AppTheme.secondaryDark,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Smart Tip',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your storage is 75% full. AI suggests archiving old project drafts to free up 4GB.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Settings List ──
  Widget _buildSettingsSection() {
    final items = [
      (Icons.person_outline, 'Account Information'),
      (Icons.notifications_outlined, 'Notification Settings'),
      (Icons.security_outlined, 'Privacy & Security'),
      (Icons.card_membership_outlined, 'Subscription Plan'),
      (Icons.help_outline, 'Help & Support'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GENERAL SETTINGS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface3,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final isLast = i == items.length - 1;
              return Column(
                children: [
                  _settingsTile(item.$1, item.$2),
                  if (!isLast)
                    Divider(height: 1, indent: 52, color: AppTheme.outline.withValues(alpha: 0.3)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _settingsTile(IconData icon, String label) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppTheme.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppTheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  // ── Log Out Button ──
  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, size: 20, color: AppTheme.error),
                const SizedBox(width: 8),
                Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
