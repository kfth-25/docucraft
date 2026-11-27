// DocuCraft — Settings Service
// Pengaturan key-value sederhana yang ditopang SharedPreferences.

import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _qcEnabledKey = 'docucraft_qc_enabled';
  static const String _qcMaxPagesKey = 'docucraft_qc_max_pages';

  static SettingsService? _instance;
  static SharedPreferences? _prefs;

  SettingsService._internal();

  static Future<SettingsService> getInstance() async {
    if (_instance != null) return _instance!;
    _prefs = await SharedPreferences.getInstance();
    _instance = SettingsService._internal();
    return _instance!;
  }

  /// Whether QC pass is enabled (default: true)
  bool get qcEnabled => _prefs?.getBool(_qcEnabledKey) ?? true;

  /// Set QC enabled state
  Future<void> setQcEnabled(bool enabled) async {
    await _prefs?.setBool(_qcEnabledKey, enabled);
  }

  /// Maximum pages to QC per run (default: 20)
  int get qcMaxPages => _prefs?.getInt(_qcMaxPagesKey) ?? 20;

  /// Set max pages for QC
  Future<void> setQcMaxPages(int maxPages) async {
    await _prefs?.setInt(_qcMaxPagesKey, maxPages);
  }
}