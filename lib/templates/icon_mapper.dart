// DocuCraft — Icon Mapper
// Memetakan URL icon SVG Presenton → Material Icons
// (Sama seperti RemoteSvgIcon di Presenton, tapi native Flutter)

import 'package:flutter/material.dart';

class TemplateIconMapper {
  /// Map SVG icon URL/name → Material IconData
  static IconData iconFor(String? url) {
    final u = (url ?? '').toLowerCase();

    if (u.contains('file-text') || u.contains('document') || u.contains('file')) return Icons.description_outlined;
    if (u.contains('devices') || u.contains('phone') || u.contains('mobile')) return Icons.devices_outlined;
    if (u.contains('chart-line') || u.contains('chart') || u.contains('trend')) return Icons.trending_up;
    if (u.contains('checks') || u.contains('check') || u.contains('verify')) return Icons.check_circle_outline;
    if (u.contains('calendar')) return Icons.calendar_today_outlined;
    if (u.contains('graduation') || u.contains('education') || u.contains('school')) return Icons.school_outlined;
    if (u.contains('user') || u.contains('person') || u.contains('profile')) return Icons.person_outline;
    if (u.contains('clipboard') || u.contains('note')) return Icons.assignment_outlined;
    if (u.contains('x-bold') || u.contains('close') || u.contains('delete')) return Icons.close;
    if (u.contains('gear') || u.contains('settings') || u.contains('cog')) return Icons.settings_outlined;
    if (u.contains('shield') || u.contains('security')) return Icons.shield_outlined;
    if (u.contains('lightning') || u.contains('bolt') || u.contains('flash')) return Icons.bolt;
    if (u.contains('rocket')) return Icons.rocket_launch_outlined;
    if (u.contains('target')) return Icons.adjust;
    if (u.contains('star')) return Icons.star_outline;
    if (u.contains('heart')) return Icons.favorite_outline;
    if (u.contains('globe') || u.contains('world')) return Icons.public;
    if (u.contains('lock') || u.contains('secure')) return Icons.lock_outline;
    if (u.contains('mail') || u.contains('envelope')) return Icons.mail_outline;
    if (u.contains('search') || u.contains('magnify')) return Icons.search;
    if (u.contains('home') || u.contains('house')) return Icons.home_outlined;
    if (u.contains('cart') || u.contains('shop') || u.contains('bag')) return Icons.shopping_bag_outlined;
    if (u.contains('download')) return Icons.download_outlined;
    if (u.contains('upload')) return Icons.upload_outlined;
    if (u.contains('play')) return Icons.play_circle_outline;
    if (u.contains('video') || u.contains('camera')) return Icons.videocam_outlined;
    if (u.contains('image') || u.contains('photo') || u.contains('picture')) return Icons.image_outlined;
    if (u.contains('layers')) return Icons.layers_outlined;
    if (u.contains('database') || u.contains('server')) return Icons.storage_outlined;
    if (u.contains('code')) return Icons.code;
    if (u.contains('cube') || u.contains('box')) return Icons.inventory_2_outlined;

    return Icons.auto_awesome_outlined; // fallback
  }

  /// Warna icon — sesuai konteks (dark text di bg biru muda, putih di bg gelap)
  static Color colorFor(String? url, {bool onDark = false}) {
    return onDark ? Colors.white : const Color(0xFF111827);
  }
}
