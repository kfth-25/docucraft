// DocuCraft Mobile PPT Editor — Main Entry
// Collab: Loro CRDT (via flutter_rust_bridge) + sinkronisasi WebSocket

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'l10n/app_localizations.dart';
import 'providers/slide_provider.dart';
import 'providers/document_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/templates_storage_screen.dart';
import 'themes/app_theme.dart';
import 'models/template_registry.dart';
import 'services/storage_service.dart';
import 'src/ffi/collab_factory.dart';
import 'src/ffi/slide_provider_crdt.dart';
import 'src/ffi/collab_websocket_crdt.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await StorageService.init();
  // Muat semua folder template paralel — sebelumnya 13 await berurutan
  // menahan frame pertama sampai 100+ file JSON selesai dibaca.
  await Future.wait([
    TemplateRegistry.loadSwiftLayouts(),
    TemplateRegistry.loadStandardLayouts(),
    TemplateRegistry.loadModernLayouts(),
    TemplateRegistry.loadGeneralLayouts(),
    TemplateRegistry.loadEducationLayouts(),
    TemplateRegistry.loadNeoSwiftLayouts(),
    TemplateRegistry.loadCodeLayouts(),
    TemplateRegistry.loadNeoModernLayouts(),
    TemplateRegistry.loadNeoStandardLayouts(),
    TemplateRegistry.loadProductOverviewLayouts(),
    TemplateRegistry.loadReportLayouts(),
    TemplateRegistry.loadPitchDeckLayouts(),
    TemplateRegistry.loadNeoGeneralLayouts(),
  ]);
  runApp(const DocuCraftApp());
}

/// CollabManager — manages Loro CRDT collaboration lifecycle
/// Supports both legacy (SyncEngine) and CRDT (SlideProviderCrdt) modes
class CollabManager {
  static final CollabManager _instance = CollabManager._();
  factory CollabManager() => _instance;
  CollabManager._();

  ChangeNotifier? _provider;
  SlideProviderCrdt? _crdtProvider;
  CollabMode _mode = CollabMode.crdt;

  bool get isConnected => _crdtProvider?.isCollabConnected ?? false;
  CollabMode get mode => _mode;

  /// Initialize CRDT-based collaboration (default)
  Future<void> initCrdt({
    required String documentId,
    required String userId,
    required String userName,
  }) async {
    _mode = CollabMode.crdt;

    // Dispose previous
    _provider?.dispose();
    _crdtProvider?.dispose();

    // Load existing snapshot if available
    Uint8List? snapshot;
    // TODO: Load from StorageService if needed

    _crdtProvider = await CollabFactory.createSlideProvider(
      documentId: documentId,
      userId: userId,
      userName: userName,
      mode: CollabMode.crdt,
      existingSnapshot: snapshot,
    );

    _provider = _crdtProvider;
  }

  /// Initialize legacy collaboration (fallback)
  Future<void> initLegacy({
    required String documentId,
    required String userId,
    required String userName,
  }) async {
    _mode = CollabMode.legacy;

    _provider?.dispose();
    _crdtProvider?.dispose();

    _provider = await CollabFactory.createSlideProvider(
      documentId: documentId,
      userId: userId,
      userName: userName,
      mode: CollabMode.legacy,
    );
  }

  /// Get the current provider (SlideProvider or SlideProviderCrdt)
  ChangeNotifier? get provider => _provider;

  /// Get CRDT-specific provider (for CRDT-only features)
  SlideProviderCrdt? get crdtProvider => _crdtProvider;

  /// Create WebSocket sync for CRDT
  CrdtWebSocketSync? _wsSync;

  Future<void> connectWebSocket({
    required String documentId,
    required String userId,
    required String userName,
    String serverUrl = 'ws://127.0.0.1:9101',
  }) async {
    if (_mode != CollabMode.crdt || _crdtProvider == null) return;

    _wsSync = CollabFactory.createWebSocketSync(
      documentId: documentId,
      userId: userId,
      userName: userName,
      serverUrl: serverUrl,
    );

    // Forward local CRDT updates to WebSocket
    _wsSync!.updates.listen((update) {
      _crdtProvider!.onLocalUpdate(update); // This sends to other peers
    });

    // Forward WebSocket updates to CRDT
    _wsSync!.updates.listen((update) {
      _crdtProvider!.receiveFromWebSocket(update);
    });

    // Handle connection state
    _wsSync!.connectionState.listen((state) {
      // Update UI indicator
      _provider?.notifyListeners();
    });

    await _wsSync!.connect();
  }

  /// Save CRDT snapshot locally
  Future<void> saveSnapshot() async {
    if (_crdtProvider != null) {
      await _crdtProvider!.saveSnapshot();
    }
  }

  void dispose() {
    _wsSync?.dispose();
    _provider?.dispose();
    _crdtProvider?.dispose();
    _provider = null;
    _crdtProvider = null;
  }
}

class DocuCraftApp extends StatelessWidget {
  const DocuCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SlideProvider()),
        ChangeNotifierProvider(create: (_) => DocumentProvider()..init()),
      ],
      child: MaterialApp(
        // Sprint 21: localized title + delegates. Locale defaults to
        // English; Indonesian is also supported and will auto-pick
        // when the device reports `id`.
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Splash dulu (status "Server Running"), otomatis lanjut ke
        // MainShell — dashboard tidak dihapus, hanya ditunda sebentar.
        home: const SplashScreen(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    TemplatesStorageScreen(),
    Center(child: Text('AI', style: TextStyle(color: AppTheme.textPrimary))),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Collab Manager ready in singleton — inited per document in editor
    // CollabManager();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
          ),
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navItem(Icons.home, 'Home', 0),
              _navItem(Icons.dashboard_customize, 'Templates', 1),
              _navItem(Icons.auto_awesome, 'AI', 2),
              _navItem(Icons.person, 'Profile', 3),
            ],
          ),
        ),
      ),
    );
  }

  /// Nav item — pill background untuk tab aktif (sesuai stitch-v2)
  Widget _navItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary.withAlpha(40) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: isActive ? AppTheme.primary : AppTheme.textMuted),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? AppTheme.primary : AppTheme.textMuted,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}