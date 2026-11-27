// DocuCraft — Icon Picker Dialog v2
// Material Icons diperluas + 100 emoji + color picker + yang baru dipakai

import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

/// Recently used icons (max 10)
final List<String> _recentIcons = [];

/// Material icon categories
class _IconCategory {
  final String name;
  final IconData icon;
  final List<IconData> icons;
  const _IconCategory({required this.name, required this.icon, required this.icons});
}

const List<_IconCategory> _categories = [
  // ── FAVORITES ──
  _IconCategory(name: 'Favorit', icon: Icons.star, icons: [
    Icons.star, Icons.star_border, Icons.star_half, Icons.star_outline,
    Icons.favorite, Icons.favorite_border, Icons.favorite_outline,
    Icons.thumb_up, Icons.thumb_up_off_alt, Icons.thumb_down, Icons.thumb_down_off_alt,
    Icons.bookmark, Icons.bookmark_border, Icons.lightbulb, Icons.lightbulb_outline,
    Icons.notifications, Icons.notifications_off, Icons.push_pin, Icons.flag,
    Icons.emoji_events, Icons.verified,
  ]),
  // ── ARROWS & NAVIGATION ──
  _IconCategory(name: 'Arah', icon: Icons.navigation, icons: [
    Icons.arrow_back, Icons.arrow_forward, Icons.arrow_upward, Icons.arrow_downward,
    Icons.arrow_back_ios, Icons.arrow_forward_ios,
    Icons.keyboard_arrow_up, Icons.keyboard_arrow_down,
    Icons.keyboard_arrow_left, Icons.keyboard_arrow_right,
    Icons.keyboard_double_arrow_up, Icons.keyboard_double_arrow_down,
    Icons.keyboard_double_arrow_left, Icons.keyboard_double_arrow_right,
    Icons.expand_more, Icons.expand_less, Icons.chevron_right, Icons.chevron_left,
    Icons.north_east, Icons.north_west, Icons.south_east, Icons.south_west,
    Icons.turn_left, Icons.turn_right, Icons.my_location,
    Icons.explore, Icons.explore_outlined, Icons.map, Icons.place,
  ]),
  // ── BUSINESS & MONEY ──
  _IconCategory(name: 'Bisnis', icon: Icons.business, icons: [
    Icons.business, Icons.business_center, Icons.work, Icons.work_outline,
    Icons.account_balance, Icons.account_balance_wallet,
    Icons.trending_up, Icons.trending_down, Icons.show_chart, Icons.insights,
    Icons.analytics, Icons.assessment, Icons.pie_chart, Icons.bar_chart,
    Icons.scatter_plot, Icons.leaderboard, Icons.timeline,
    Icons.attach_money, Icons.money_off, Icons.payments,
    Icons.monetization_on, Icons.price_change, Icons.price_check,
    Icons.receipt_long, Icons.receipt,
    Icons.shopping_cart, Icons.shopping_cart_outlined,
    Icons.store, Icons.storefront, Icons.sell, Icons.discount,
    Icons.inventory, Icons.local_shipping,
    Icons.add_shopping_cart, Icons.loyalty, Icons.card_giftcard,
    Icons.point_of_sale, Icons.request_quote, Icons.volunteer_activism,
    Icons.savings, Icons.credit_card, Icons.credit_card_off,
    Icons.recommend, Icons.query_stats,
  ]),
  // ── COMMUNICATION ──
  _IconCategory(name: 'Komunikasi', icon: Icons.chat, icons: [
    Icons.chat, Icons.chat_outlined, Icons.chat_bubble, Icons.chat_bubble_outline,
    Icons.email, Icons.mail, Icons.mail_outline, Icons.drafts,
    Icons.send, Icons.forward, Icons.reply, Icons.reply_all,
    Icons.phone, Icons.phone_outlined, Icons.phone_in_talk,
    Icons.videocam, Icons.videocam_outlined,
    Icons.mic, Icons.mic_off, Icons.mic_none,
    Icons.volume_up, Icons.volume_off, Icons.volume_mute,
    Icons.record_voice_over, Icons.hearing, Icons.closed_caption,
    Icons.forum, Icons.forum_outlined,
    Icons.share, Icons.share_outlined, Icons.share_location,
    Icons.public, Icons.language, Icons.translate,
    Icons.info, Icons.info_outline, Icons.help, Icons.help_outline,
    Icons.warning, Icons.report, Icons.report_problem,
    Icons.link, Icons.link_off, Icons.paste,
    Icons.content_copy, Icons.content_paste,
    Icons.mark_email_read, Icons.mark_email_unread,
    Icons.mark_chat_read, Icons.mark_chat_unread,
  ]),
  // ── CONTENT & DOCUMENTS ──
  _IconCategory(name: 'Konten', icon: Icons.article, icons: [
    Icons.article, Icons.article_outlined,
    Icons.description, Icons.description_outlined,
    Icons.note, Icons.note_add, Icons.notes,
    Icons.assignment, Icons.assignment_ind, Icons.assignment_late,
    Icons.checklist, Icons.fact_check, Icons.quiz, Icons.grading,
    Icons.summarize, Icons.auto_stories,
    Icons.menu_book, Icons.library_books, Icons.book,
    Icons.book_outlined, Icons.sticky_note_2, Icons.edit_note,
    Icons.text_snippet, Icons.snippet_folder,
    Icons.table_chart, Icons.table_rows, Icons.view_list,
    Icons.format_list_bulleted, Icons.format_list_numbered,
    Icons.view_carousel, Icons.view_module,
    Icons.dashboard, Icons.dashboard_customize,
    Icons.folder, Icons.folder_outlined, Icons.folder_open,
    Icons.create_new_folder, Icons.archive, Icons.unarchive,
    Icons.cloud_upload, Icons.cloud_download, Icons.cloud,
  ]),
  // ── DESIGN & MEDIA ──
  _IconCategory(name: 'Design', icon: Icons.palette, icons: [
    Icons.palette, Icons.palette_outlined, Icons.color_lens, Icons.colorize,
    Icons.brush, Icons.format_paint,
    Icons.gradient, Icons.format_shapes, Icons.crop, Icons.crop_free,
    Icons.crop_landscape, Icons.crop_portrait, Icons.crop_square,
    Icons.auto_fix_high, Icons.auto_fix_off,
    Icons.format_bold, Icons.format_italic, Icons.format_underline,
    Icons.format_strikethrough, Icons.format_size, Icons.font_download,
    Icons.style, Icons.theater_comedy,
    Icons.format_color_text, Icons.format_color_fill,
    Icons.brightness_1, Icons.brightness_2, Icons.brightness_3, Icons.brightness_4,
    Icons.brightness_5, Icons.brightness_6, Icons.brightness_7,
    Icons.contrast, Icons.invert_colors, Icons.opacity,
    Icons.layers, Icons.grid_on, Icons.grid_view,
    Icons.center_focus_strong, Icons.center_focus_weak,
    Icons.zoom_in, Icons.zoom_out, Icons.fit_screen,
    Icons.straighten, Icons.rotate_right, Icons.rotate_left,
    Icons.flip,
  ]),
  // ── MEDIA & ENTERTAINMENT ──
  _IconCategory(name: 'Media', icon: Icons.play_circle, icons: [
    Icons.play_arrow, Icons.play_circle, Icons.play_circle_outline,
    Icons.pause, Icons.pause_circle, Icons.pause_circle_outline,
    Icons.stop, Icons.stop_circle,
    Icons.skip_next, Icons.skip_previous,
    Icons.fast_forward, Icons.fast_rewind,
    Icons.replay, Icons.replay_5, Icons.replay_10, Icons.replay_30,
    Icons.slideshow, Icons.screen_share,
    Icons.airplay, Icons.cast, Icons.cast_connected,
    Icons.videocam, Icons.videocam_off, Icons.video_call,
    Icons.live_tv, Icons.live_tv_outlined,
    Icons.movie, Icons.movie_filter, Icons.local_movies,
    Icons.music_note, Icons.music_off,
    Icons.album, Icons.audiotrack, Icons.queue_music,
    Icons.playlist_play, Icons.playlist_add,
    Icons.library_music, Icons.library_music_outlined,
    Icons.tune, Icons.equalizer, Icons.surround_sound,
  ]),
  // ── SOCIAL & PEOPLE ──
  _IconCategory(name: 'Orang', icon: Icons.people, icons: [
    Icons.person, Icons.person_outlined, Icons.person_add,
    Icons.person_remove, Icons.person_off,
    Icons.people, Icons.people_outline,
    Icons.group, Icons.group_add, Icons.group_remove,
    Icons.family_restroom, Icons.child_care, Icons.elderly,
    Icons.engineering, Icons.science, Icons.psychology,
    Icons.school, Icons.menu_book, Icons.badge,
    Icons.supervised_user_circle, Icons.account_circle,
    Icons.account_circle_outlined, Icons.account_box,
    Icons.account_tree, Icons.admin_panel_settings,
    Icons.face, Icons.emoji_emotions, Icons.waving_hand,
    Icons.wc, Icons.pets, Icons.hotel,
  ]),
  // ── SYSTEM & UI ──
  _IconCategory(name: 'Sistem', icon: Icons.settings, icons: [
    Icons.settings, Icons.settings_outlined, Icons.settings_suggest,
    Icons.tune, Icons.tune_outlined,
    Icons.admin_panel_settings, Icons.manage_accounts,
    Icons.security, Icons.lock, Icons.lock_open,
    Icons.vpn_key, Icons.key,
    Icons.search, Icons.search_off, Icons.manage_search,
    Icons.refresh, Icons.sync, Icons.sync_disabled,
    Icons.update, Icons.system_update, Icons.backup,
    Icons.save, Icons.save_alt, Icons.save_as,
    Icons.download, Icons.upload, Icons.file_download, Icons.file_upload,
    Icons.copy, Icons.copy_all, Icons.content_copy,
    Icons.cut, Icons.content_paste, Icons.paste,
    Icons.undo, Icons.redo, Icons.history,
    Icons.close, Icons.cancel, Icons.check_circle,
    Icons.add_circle, Icons.remove_circle,
    Icons.more_vert, Icons.more_horiz,
    Icons.menu, Icons.menu_open,
    Icons.fullscreen, Icons.fullscreen_exit,
    Icons.open_in_new, Icons.open_in_browser,
  ]),
  // ── TOOLS & UTILITY ──
  _IconCategory(name: 'Alat', icon: Icons.build, icons: [
    Icons.build, Icons.build_circle, Icons.build_outlined,
    Icons.handyman, Icons.plumbing, Icons.electrical_services,
    Icons.carpenter, Icons.architecture, Icons.engineering,
    Icons.design_services, Icons.format_paint, Icons.brush,
    Icons.edit, Icons.edit_outlined,
    Icons.draw, Icons.brush_outlined,
    Icons.science, Icons.biotech, Icons.psychology,
    Icons.code, Icons.terminal, Icons.developer_board,
    Icons.developer_mode, Icons.devices, Icons.devices_other,
    Icons.storage, Icons.memory, Icons.sd_card,
    Icons.usb, Icons.print, Icons.scanner,
    Icons.qr_code, Icons.qr_code_2, Icons.qr_code_scanner,
  ]),
  // ── DATA & ANALYTICS ──
  _IconCategory(name: 'Data', icon: Icons.analytics, icons: [
    Icons.analytics, Icons.analytics_outlined,
    Icons.insights, Icons.insights_outlined,
    Icons.query_stats, Icons.query_stats_outlined,
    Icons.leaderboard, Icons.leaderboard_outlined,
    Icons.pie_chart, Icons.pie_chart_outline,
    Icons.bar_chart,
    Icons.scatter_plot, Icons.timeline, Icons.functions,
    Icons.straighten, Icons.speed,
    Icons.timer, Icons.timer_outlined, Icons.timer_10, Icons.timer_3,
    Icons.hourglass_top, Icons.hourglass_bottom, Icons.hourglass_empty,
    Icons.alarm, Icons.alarm_add, Icons.alarm_off,
    Icons.schedule, Icons.av_timer,
    Icons.traffic, Icons.eco,
    Icons.park, Icons.forest, Icons.grass,
    Icons.water_drop, Icons.thermostat,
    Icons.air,
  ]),
  // ── LOCATION & MAP ──
  _IconCategory(name: 'Lokasi', icon: Icons.place, icons: [
    Icons.place, Icons.place_outlined, Icons.add_location,
    Icons.my_location,
    Icons.explore, Icons.explore_outlined,
    Icons.map, Icons.map_outlined, Icons.terrain,
    Icons.near_me, Icons.pin_drop, Icons.pin_drop_outlined,
    Icons.location_on, Icons.location_on_outlined, Icons.location_off,
    Icons.navigation, Icons.navigation_outlined,
    Icons.directions, Icons.directions_car, Icons.directions_bike,
    Icons.directions_bus, Icons.directions_walk,
    Icons.local_cafe, Icons.local_bar, Icons.local_dining,
    Icons.local_gas_station, Icons.local_hospital, Icons.local_pharmacy,
    Icons.local_hotel, Icons.flight, Icons.hotel,
    Icons.pool, Icons.spa, Icons.fitness_center,
    Icons.sports, Icons.sports_soccer,
  ]),
  // ── EMOJI ──
  _IconCategory(name: 'Emoji', icon: Icons.emoji_emotions, icons: [
    Icons.emoji_emotions, Icons.emoji_events, Icons.emoji_flags,
    Icons.emoji_food_beverage, Icons.emoji_nature,
    Icons.emoji_objects, Icons.emoji_people, Icons.emoji_symbols,
    Icons.bolt, Icons.bolt_outlined,
    Icons.rocket_launch, Icons.rocket,
    Icons.celebration, Icons.celebration_outlined,
    Icons.wb_sunny, Icons.wb_cloudy, Icons.nightlight_round,
    Icons.auto_awesome, Icons.auto_awesome_mosaic, Icons.auto_awesome_motion,
    Icons.local_fire_department, Icons.whatshot,
    Icons.tips_and_updates, Icons.lightbulb_outline,
    Icons.diamond, Icons.diamond_outlined,
    Icons.gpp_good, Icons.gpp_maybe, Icons.gpp_bad,
    Icons.workspace_premium, Icons.military_tech,
    Icons.local_florist, Icons.park, Icons.forest,
  ]),
];

/// 100 popular emojis — expanded from 50
const List<String> _popularEmojis = [
  '⭐', '🔥', '💡', '✅', '❌', '🎯', '📊', '📈', '📉', '💰',
  '🚀', '🎉', '❤️', '👍', '👎', '💪', '🧠', '⚡', '🌟', '💎',
  '🏆', '🎯', '📌', '🔍', '🔑', '🎵', '📷', '🎬', '📝', '⏰',
  '📅', '🌐', '💻', '📱', '🏠', '✈️', '🚗', '📚', '🎨', '🧪',
  '🔬', '🤖', '👾', '🎮', '🧩', '🎲', '🃏', '🏆', '🥇', '🥈',
  '🥉', '🏆', '🎁', '🎊', '🎈', '🎋', '🎎', '🎍', '🎏', '🎐',
  '🎄', '🎌', '🎍', '🎎', '🎑', '🏮', '🎀', '🎁', '🎗️', '🎟️',
  '🎪', '🎭', '🎨', '🎬', '🎤', '🎧', '🎼', '🎹', '🥁', '🎷',
  '🎺', '🎸', '🪕', '🎻', '🎹', '🎯', '🎲', '🎮', '🎰', '🧩',
];

/// Show icon picker — returns selected icon (emoji string or 'icon:codePoint,color')
Future<String?> showIconPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _IconPickerSheet(),
  );
}

class _IconPickerSheet extends StatefulWidget {
  const _IconPickerSheet();
  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<_IconPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _selectedCategory = 0;
  String _searchQuery = '';
  int? _selectedColorValue; // null = default white

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this); // Recent | Icons | Emoji
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  List<IconData> _filteredIcons() {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) return _categories[_selectedCategory].icons;
    return _categories.expand((c) => c.icons).where((icon) {
      final name = icon.toString().toLowerCase();
      return name.contains(query);
    }).toList();
  }

  void _selectIcon(String iconStr) {
    if (_selectedColorValue != null) {
      iconStr = '$iconStr,color:$_selectedColorValue';
    }
    if (iconStr.startsWith('icon:')) {
      final codeStr = iconStr.split(',')[0];
      if (!_recentIcons.contains(codeStr)) {
        _recentIcons.insert(0, codeStr);
        if (_recentIcons.length > 10) _recentIcons.removeLast();
      }
    }
    Navigator.pop(context, iconStr);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(2)))),
          // Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Icon(Icons.emoji_symbols, size: 18, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Pilih Icon', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            ]),
          ),
          const SizedBox(height: 8),
          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white.withAlpha(8), borderRadius: BorderRadius.circular(10)),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(color: AppTheme.primary.withAlpha(80), borderRadius: BorderRadius.circular(10)),
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Baru'),
                Tab(text: 'Icons'),
                Tab(text: 'Emoji'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Cari icon atau emoji...',
                hintStyle: TextStyle(color: Colors.white.withAlpha(40)),
                prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                filled: true, fillColor: Colors.white.withAlpha(5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withAlpha(15))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withAlpha(15))),
              ),
            ),
          ),
          // Color override
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Text('Warna icon:', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              const SizedBox(width: 8),
              _colorChoice(null, 'Default'),
              const SizedBox(width: 4),
              _colorChoice(0xFFFFFFFF, 'Putih'),
              const SizedBox(width: 4),
              _colorChoice(0xFF6366F1, 'Indigo'),
              const SizedBox(width: 4),
              _colorChoice(0xFF10B981, 'Hijau'),
              const SizedBox(width: 4),
              _colorChoice(0xFFF59E0B, 'Kuning'),
              const SizedBox(width: 4),
              _colorChoice(0xFFEF4444, 'Merah'),
            ]),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildRecentTab(),
                _buildIconsTab(),
                _buildEmojiTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorChoice(int? color, String label) {
    final isActive = _selectedColorValue == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColorValue = color),
      child: Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: color != null ? Color(color!) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: isActive ? AppTheme.primary : Colors.white.withAlpha(30), width: 2),
          boxShadow: isActive ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 4)] : null,
        ),
      ),
    );
  }

  Widget _buildRecentTab() {
    if (_recentIcons.isEmpty) {
      return const Center(child: Text('Belum ada icon terakhir dipakai', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)));
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, mainAxisSpacing: 4, crossAxisSpacing: 4),
      itemCount: _recentIcons.length,
      itemBuilder: (ctx, i) {
        final codePoint = int.tryParse(_recentIcons[i].replaceFirst('icon:', ''));
        if (codePoint == null) return const SizedBox();
        return GestureDetector(
          onTap: () => _selectIcon(_recentIcons[i]),
          child: Container(
            decoration: BoxDecoration(color: Colors.white.withAlpha(5), borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withAlpha(10))),
            child: Text(
              String.fromCharCode(codePoint),
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontFamily: 'MaterialIcons',
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconsTab() {
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            itemBuilder: (ctx, i) {
              final cat = _categories[i];
              final isActive = i == _selectedCategory;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = i),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primary.withAlpha(30) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isActive ? AppTheme.primary.withAlpha(50) : Colors.white.withAlpha(15)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(cat.icon, size: 14, color: isActive ? AppTheme.primary : AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(cat.name, style: TextStyle(fontSize: 10, color: isActive ? AppTheme.primary : AppTheme.textMuted, fontWeight: FontWeight.w600)),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, mainAxisSpacing: 4, crossAxisSpacing: 4),
            itemCount: _filteredIcons().length,
            itemBuilder: (ctx, i) {
              final icon = _filteredIcons()[i];
              final iconStr = 'icon:${icon.codePoint}';
              return GestureDetector(
                onTap: () => _selectIcon(iconStr),
                child: Container(
                  decoration: BoxDecoration(color: Colors.white.withAlpha(5), borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withAlpha(10))),
                  child: Icon(icon, color: _selectedColorValue == null ? Colors.white : Color(_selectedColorValue!), size: 24),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiTab() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, mainAxisSpacing: 4, crossAxisSpacing: 4),
      itemCount: _popularEmojis.length,
      itemBuilder: (ctx, i) {
        final emoji = _popularEmojis[i];
        return GestureDetector(
          onTap: () => _selectIcon(emoji),
          child: Container(
            decoration: BoxDecoration(color: Colors.white.withAlpha(5), borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withAlpha(10))),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
          ),
        );
      },
    );
  }
}
