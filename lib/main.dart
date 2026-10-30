import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'models/sync_profile.dart';
import 'services/rclone_service.dart';
import 'ui/dialogs.dart';
import 'ui/brand_widgets.dart';

final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  themeModeNotifier.value = await RcloneService().loadThemeMode();
  runApp(const ClonegilApp());
}

class ClonegilApp extends StatelessWidget {
  const ClonegilApp({super.key});

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0284C7),
        brightness: Brightness.light,
        surface: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.80),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.90),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      dividerColor: const Color(0xFFE2E8F0),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF080C14),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF38BDF8),
        brightness: Brightness.dark,
        surface: const Color(0xFF131A29),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF131A29).withValues(alpha: 0.65),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF141824).withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      dividerColor: Colors.white10,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Clonegil - Rclone & Google Drive Yedekleme Merkezi',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: lightTheme(),
          darkTheme: darkTheme(),
          home: const ClonegilDashboard(),
        );
      },
    );
  }
}

class ClonegilDashboard extends StatefulWidget {
  const ClonegilDashboard({super.key});

  @override
  State<ClonegilDashboard> createState() => _ClonegilDashboardState();
}

class _ClonegilDashboardState extends State<ClonegilDashboard> {
  final RcloneService _service = RcloneService();

  String? _rclonePath;
  String? _rcloneVersion;
  List<RcloneRemoteInfo> _remotes = [];
  DriveQuotaInfo? _quota;

  List<SyncProfile> _profiles = [];
  String? _selectedProfileId;
  final Map<String, ProfileRuntimeStatus> _statuses = {};

  bool _initialLoading = true;
  bool _actionBusy = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initAll();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_actionBusy) {
        _refreshStatuses();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  SyncProfile? get _selectedProfile {
    if (_profiles.isEmpty) return null;
    try {
      return _profiles.firstWhere((p) => p.id == _selectedProfileId);
    } catch (_) {
      return _profiles.first;
    }
  }

  Future<void> _initAll() async {
    setState(() => _initialLoading = true);
    final path = await _service.findRcloneExecutable();
    final ver = await _service.getRcloneVersion();
    final rems = await _service.listRemotes();
    final profs = await _service.loadProfiles();

    if (mounted) {
      setState(() {
        _rclonePath = path;
        _rcloneVersion = ver;
        _remotes = rems;
        _profiles = profs;
        if (_selectedProfileId == null && profs.isNotEmpty) {
          _selectedProfileId = profs.first.id;
        }
        _initialLoading = false;
      });
    }

    await _refreshStatuses();

    if (rems.isNotEmpty) {
      final q = await _service.getDriveQuota(rems.first.name);
      if (mounted && q != null) {
        setState(() => _quota = q);
      }
    }

    // Eğer rclone kurulu değilse sihirbazı otomatik aç
    if (path == null && mounted) {
      _openSetupWizard();
    }
  }

  Future<void> _refreshStatuses() async {
    for (final p in _profiles) {
      final st = await _service.getProfileStatus(p);
      if (mounted) {
        setState(() {
          _statuses[p.id] = st;
        });
      }
    }
  }

  Future<void> _openSetupWizard() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => RcloneSetupWizardDialog(
        service: _service,
        onUpdated: () async {
          final path = await _service.findRcloneExecutable();
          final ver = await _service.getRcloneVersion();
          final rems = await _service.listRemotes();
          if (mounted) {
            setState(() {
              _rclonePath = path;
              _rcloneVersion = ver;
              _remotes = rems;
            });
          }
        },
      ),
    );
  }

  Future<void> _addOrEditProfile({SyncProfile? existing}) async {
    final result = await showDialog<SyncProfile>(
      context: context,
      builder: (ctx) => ProfileEditorDialog(
        service: _service,
        remotes: _remotes,
        existing: existing,
      ),
    );

    if (result != null) {
      setState(() => _actionBusy = true);
      final updated = List<SyncProfile>.from(_profiles);
      final idx = updated.indexWhere((p) => p.id == result.id);
      if (idx >= 0) {
        updated[idx] = result;
      } else {
        updated.add(result);
      }
      await _service.saveProfiles(updated);
      await _service.deployAndInstallProfileService(
        result,
        restartIfRunning: existing != null,
      );
      setState(() {
        _profiles = updated;
        _selectedProfileId = result.id;
        _actionBusy = false;
      });
      await _refreshStatuses();
    }
  }

  Future<void> _deleteProfile(SyncProfile profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${profile.name}" Kurgusunu Kaldır'),
        content: const Text(
          'Bu klasör eşitleme kurgusu listeden kaldırılacak ve arka plan zamanlanmış görevi durdurulacak.\n(Yerel veya Google Drive dosyalarınız silinmez.)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _actionBusy = true);
      await _service.uninstallProfileService(profile);
      final updated = _profiles.where((p) => p.id != profile.id).toList();
      await _service.saveProfiles(updated);
      setState(() {
        _profiles = updated;
        _selectedProfileId = updated.isNotEmpty ? updated.first.id : null;
        _actionBusy = false;
      });
      await _refreshStatuses();
    }
  }

  Future<void> _handleServiceAction(
    SyncProfile profile,
    String action,
  ) async {
    setState(() => _actionBusy = true);
    try {
      if (action == 'start') {
        await _service.deployAndInstallProfileService(profile);
      } else if (action == 'stop') {
        await _service.stopProfileService(profile);
      } else if (action == 'sync_now') {
        await _service.triggerSyncNow(profile);
      } else if (action == 'dedupe') {
        final out = await _service.runDedupe(profile);
        if (mounted) {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Google Drive Çift Kayıt (Dedupe) Sonucu'),
              content: SizedBox(
                width: 560,
                height: 320,
                child: SingleChildScrollView(
                  child: SelectableText(
                    out,
                    style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tamam'),
                ),
              ],
            ),
          );
        }
      }
    } finally {
      await _refreshStatuses();
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedProfile;
    final selectedStatus = selected != null
        ? (_statuses[selected.id] ?? const ProfileRuntimeStatus())
        : const ProfileRuntimeStatus();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF070A12),
                    Color(0xFF0C1322),
                    Color(0xFF080D18),
                  ]
                : const [
                    Color(0xFFF8FAFC),
                    Color(0xFFEFF6FF),
                    Color(0xFFF1F5F9),
                  ],
          ),
        ),
        child: Column(
          children: [
            _buildTopHeader(),
            Expanded(
              child: _initialLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        _buildLeftSidebar(),
                        Expanded(
                          child: selected == null
                              ? _buildEmptyState()
                              : _buildProfileDetail(selected, selectedStatus),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rcloneReady = _rclonePath != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0C101A).withValues(alpha: 0.82)
            : Colors.white.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0xFF64748B).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                // 1:1 Apple HIG Disk Logosu
                const AppleDiskLogo(size: 42),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ClonegilBrandText(fontSize: 20),
                      const SizedBox(height: 2),
                      Text(
                        'Rclone & Google Drive Otomatik Arka Plan Senkronizasyon Yöneticisi',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? Colors.white60
                              : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (_quota != null)
                  Builder(
                    builder: (context) {
                      final ratio = _quota!.usageRatio;
                      final pct = _quota!.usagePercent;

                      Color progressColor = isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF0284C7);
                      if (ratio != null) {
                        if (ratio >= 0.90) {
                          progressColor = Colors.redAccent;
                        } else if (ratio >= 0.75) {
                          progressColor = const Color(0xFFFBBF24);
                        }
                      }

                      return Tooltip(
                        message:
                            'Google Drive Depolama Alanı\nKullanılan: ${_quota!.used} (${pct != null ? "%$pct" : "-"})\nBoş Alan: ${_quota!.free}\nToplam: ${_quota!.total}',
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF131A29).withValues(alpha: 0.55)
                                : Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.9),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.2)
                                    : const Color(0xFF64748B)
                                        .withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.cloud_done_rounded,
                                    size: 15,
                                    color: progressColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Drive: ${_quota!.used} / ${_quota!.total}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (pct != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: progressColor
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: progressColor
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Text(
                                        '%$pct',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: progressColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  Text(
                                    '(Boş: ${_quota!.free})',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? Colors.white54
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              SizedBox(
                                width: 230,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 5,
                                    backgroundColor: isDark
                                        ? Colors.white10
                                        : const Color(0xFFE2E8F0),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      progressColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                InkWell(
                  onTap: _openSetupWizard,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: rcloneReady
                          ? (isDark
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : const Color(0xFFDCFCE7).withValues(alpha: 0.8))
                          : (isDark
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                              : const Color(0xFFFEF3C7).withValues(alpha: 0.8)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: rcloneReady
                            ? (isDark
                                ? const Color(0xFF34D399).withValues(alpha: 0.4)
                                : const Color(0xFF86EFAC))
                            : (isDark
                                ? const Color(0xFFFBBF24).withValues(alpha: 0.5)
                                : const Color(0xFFFCD34D)),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (rcloneReady
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B))
                              .withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: rcloneReady
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                            boxShadow: [
                              BoxShadow(
                                color: (rcloneReady
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B))
                                    .withValues(alpha: 0.8),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          rcloneReady
                              ? '${_rcloneVersion ?? "Rclone Hazır"} (${_remotes.length} Bulut)'
                              : 'Rclone Kurulumu Gerekli',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: rcloneReady
                                ? (isDark
                                    ? Colors.white
                                    : const Color(0xFF15803D))
                                : (isDark
                                    ? Colors.white
                                    : const Color(0xFFB45309)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: isDark
                        ? 'Açık Temaya Geç (Light Mode)'
                        : 'Koyu Temaya Geç (Dark Mode)',
                    onPressed: () {
                      final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
                      themeModeNotifier.value = newMode;
                      _service.saveThemeMode(newMode);
                    },
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      size: 18,
                      color: isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF0284C7),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Durumu Yenile',
                    onPressed: _refreshStatuses,
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftSidebar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg = isDark
        ? const Color(0xFF0C101A).withValues(alpha: 0.65)
        : const Color(0xFFF8FAFC).withValues(alpha: 0.75);
    final textMuted = isDark ? Colors.white54 : const Color(0xFF64748B);
    final textSubtle = isDark ? Colors.white38 : const Color(0xFF94A3B8);

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'YEDEKLEME KURGULARI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textMuted,
                        letterSpacing: 0.9,
                      ),
                    ),
                    Text(
                      '${_profiles.length} Konum',
                      style: TextStyle(fontSize: 12, color: textSubtle),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFF0284C7), Color(0xFF38BDF8)]
                          : const [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _addOrEditProfile(),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Yeni Klasör Kurgusu Ekle',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.separated(
                    itemCount: _profiles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final p = _profiles[i];
                      final st =
                          _statuses[p.id] ?? const ProfileRuntimeStatus();
                      final isSelected = p.id == _selectedProfile?.id;

                      Color badgeColor =
                          isDark ? Colors.grey : const Color(0xFF64748B);
                      Color badgeBg = isDark
                          ? Colors.grey.withValues(alpha: 0.15)
                          : const Color(0xFFF1F5F9);
                      Color badgeBorder = isDark
                          ? Colors.grey.withValues(alpha: 0.4)
                          : const Color(0xFFCBD5E1);
                      String badgeText = 'DURDURULDU';

                      if (st.rcloneRunning) {
                        badgeColor = isDark
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF0284C7);
                        badgeBg = isDark
                            ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                            : const Color(0xFFE0F2FE);
                        badgeBorder = isDark
                            ? const Color(0xFF38BDF8).withValues(alpha: 0.4)
                            : const Color(0xFF7DD3FC);
                        badgeText = 'AKTARIMDA';
                      } else if (st.watcherRunning ||
                          st.taskState == 'Running') {
                        badgeColor =
                            isDark ? Colors.greenAccent : const Color(0xFF15803D);
                        badgeBg = isDark
                            ? Colors.green.withValues(alpha: 0.15)
                            : const Color(0xFFDCFCE7);
                        badgeBorder = isDark
                            ? Colors.greenAccent.withValues(alpha: 0.4)
                            : const Color(0xFF86EFAC);
                        badgeText = 'İZLENİYOR';
                      }

                      final cardBg = isSelected
                          ? (isDark
                              ? const Color(0xFF0F233D).withValues(alpha: 0.85)
                              : const Color(0xFFE0F2FE).withValues(alpha: 0.90))
                          : (isDark
                              ? const Color(0xFF131A29).withValues(alpha: 0.50)
                              : Colors.white.withValues(alpha: 0.70));

                      final cardBorder = isSelected
                          ? (isDark
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF0284C7))
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFE2E8F0));

                      final cardShadow = isSelected
                          ? [
                              BoxShadow(
                                color: (isDark
                                        ? const Color(0xFF38BDF8)
                                        : const Color(0xFF0284C7))
                                    .withValues(alpha: 0.25),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.15)
                                    : const Color(0xFF64748B)
                                        .withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ];

                      return InkWell(
                        onTap: () =>
                            setState(() => _selectedProfileId = p.id),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: cardBorder,
                              width: isSelected ? 1.5 : 1,
                            ),
                            boxShadow: cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: badgeBorder),
                                    ),
                                    child: Text(
                                      badgeText,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: badgeColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.folder_outlined,
                                    size: 14,
                                    color: isDark
                                        ? Colors.white54
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      p.localPath,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xFF475569),
                                        fontFamily: 'Consolas',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.cloud_outlined,
                                    size: 14,
                                    color: isDark
                                        ? const Color(0xFF38BDF8)
                                        : const Color(0xFF0284C7),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      p.fullRemoteSpec,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? const Color(0xFF38BDF8)
                                            : const Color(0xFF0284C7),
                                        fontFamily: 'Consolas',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (st.progressPercent != null &&
                                  st.rcloneRunning) ...[
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: st.progressPercent,
                                    minHeight: 5,
                                    backgroundColor: isDark
                                        ? Colors.white10
                                        : const Color(0xFFE2E8F0),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isDark
                                          ? const Color(0xFF38BDF8)
                                          : const Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${st.progressTransferred ?? ""} • ${st.currentSpeed ?? ""}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? Colors.white60
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      st.lastBackupTime != null
                                          ? 'Son: ${st.lastBackupTime}'
                                          : 'Henüz kayıt yok',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white54
                                            : const Color(0xFF64748B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Hız: ${p.bwLimit}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white38
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 64,
            color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz bir klasör eşitleme kurgusu seçilmedi.',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _addOrEditProfile(),
            icon: const Icon(Icons.add),
            label: const Text('İlk Klasör Kurgusunu Oluştur'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetail(
    SyncProfile profile,
    ProfileRuntimeStatus status,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRunning = status.watcherRunning || status.taskState == 'Running';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Başlık ve Hızlı Kontroller
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 820;

              final titleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text(
                        profile.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: isRunning
                            ? (isDark
                                ? Colors.green.withValues(alpha: 0.15)
                                : const Color(0xFFDCFCE7))
                            : (isDark
                                ? Colors.red.withValues(alpha: 0.15)
                                : const Color(0xFFFEE2E2)),
                        side: BorderSide(
                          color: isRunning
                              ? (isDark
                                  ? Colors.greenAccent.withValues(alpha: 0.4)
                                  : const Color(0xFF86EFAC))
                              : (isDark
                                  ? Colors.redAccent.withValues(alpha: 0.4)
                                  : const Color(0xFFFCA5A5)),
                        ),
                        label: Text(
                          isRunning
                              ? 'OTOMATİK İZLEYİCİ AKTİF (WATCHDOG)'
                              : 'SERVİS DURDURULDU',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isRunning
                                ? (isDark
                                    ? Colors.greenAccent
                                    : const Color(0xFF15803D))
                                : (isDark
                                    ? Colors.redAccent
                                    : const Color(0xFFB91C1C)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF131A29).withValues(alpha: 0.50)
                          : Colors.white.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: SelectableText(
                      '${profile.localPath}   ➔   ${profile.fullRemoteSpec}   (Mod: ${profile.syncMode.toUpperCase()}, Hız Limiti: ${profile.bwLimit})',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontFamily: 'Consolas',
                      ),
                    ),
                  ),
                ],
              );

              final actionButtons = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (!isRunning)
                    FilledButton.icon(
                      onPressed: _actionBusy
                          ? null
                          : () => _handleServiceAction(profile, 'start'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Otomatik Servisi Başlat'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _actionBusy
                          ? null
                          : () => _handleServiceAction(profile, 'stop'),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Durdur'),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: _actionBusy
                        ? null
                        : () => _handleServiceAction(profile, 'sync_now'),
                    icon: const Icon(Icons.sync),
                    label: const Text('Şimdi Eşitle'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _actionBusy
                        ? null
                        : () => _handleServiceAction(profile, 'dedupe'),
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const Text('Çift Kayıt Temizle'),
                  ),
                  IconButton(
                    tooltip: 'Klasör Kurgusunu ve Hız Limitini Düzenle',
                    onPressed: _actionBusy
                        ? null
                        : () => _addOrEditProfile(existing: profile),
                    icon: const Icon(Icons.settings),
                  ),
                  IconButton(
                    tooltip: 'Kurguyu Sil',
                    onPressed:
                        _actionBusy ? null : () => _deleteProfile(profile),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    const SizedBox(height: 12),
                    actionButtons,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleSection),
                  const SizedBox(width: 16),
                  actionButtons,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // 3 Durum Kartı (Glassmorphic)
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.security_update_good,
                  iconColor: Colors.greenAccent,
                  title: 'Arka Plan Servis & Görev Zamanlayıcı',
                  mainValue:
                      'Görev: ${status.taskState} ${status.watcherPid != null ? "(PID: ${status.watcherPid})" : ""}',
                  subValue: status.rcloneRunning
                      ? 'Aktif Rclone PID: ${status.rclonePids.join(", ")} (BelowNormal Öncelik)'
                      : 'Rclone şu an boşta — dosya değişikliği bekleniyor',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.history_toggle_off,
                  iconColor: const Color(0xFF38BDF8),
                  title: 'En Son Yedekleme Zamanı & Dosya',
                  mainValue: status.lastBackupTime ?? 'Henüz yedekleme kaydı yok',
                  subValue: status.lastSyncedFile != null
                      ? 'Son: ${status.lastSyncedFile}'
                      : 'İlk aktarım veya değişiklik bekleniyor',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.speed,
                  iconColor: const Color(0xFFFBBF24),
                  title: 'Canlı Aktarım İlerlemesi & Hız',
                  mainValue: status.progressTransferred ?? 'Beklemede / Tamamlandı',
                  subValue: status.currentSpeed != null
                      ? 'Hız: ${status.currentSpeed} • Kalan (ETA): ${status.currentEta ?? "-"} ${status.xfrCounts != null ? "(${status.xfrCounts})" : ""}'
                      : 'Bant genişliği koruması: ${profile.bwLimit}',
                  progress: status.progressPercent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Canlı Log Sekmeleri (Glassmorphic)
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF131A29).withValues(alpha: 0.60)
                      : Colors.white.withValues(alpha: 0.80),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.09)
                        : Colors.white.withValues(alpha: 0.90),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.25)
                          : const Color(0xFF64748B).withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isDark
                                    ? Colors.white10
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: TabBar(
                                  isScrollable: true,
                                  tabs: [
                                    Tab(
                                      icon: Icon(Icons.bolt, size: 18),
                                      text:
                                          'Anlık Değişiklik & İzleyici Logları (sync.log)',
                                    ),
                                    Tab(
                                      icon: Icon(Icons.cloud_upload, size: 18),
                                      text:
                                          'Rclone Aktarım Detayları (rclone-detail.log)',
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Otomatik yenileniyor (4 sn)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.4)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildLogList(
                                status.mainLogs,
                                emptyText: 'Henüz izleyici log kaydı oluşmadı.',
                              ),
                              _buildLogList(
                                status.rcloneLogs,
                                emptyText: 'Henüz rclone aktarım detayı oluşmadı.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String mainValue,
    required String subValue,
    double? progress,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF131A29).withValues(alpha: 0.60)
            : Colors.white.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.09)
              : Colors.white.withValues(alpha: 0.90),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0xFF64748B).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: iconColor.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(icon, color: iconColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white60
                              : const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  mainValue,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  subValue,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor:
                          isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogList(List<String> lines, {required String emptyText}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final consoleBg = isDark
        ? const Color(0xFF070A10).withValues(alpha: 0.94)
        : const Color(0xFF0F172A).withValues(alpha: 0.96);

    if (lines.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: TextStyle(
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
        ),
      );
    }
    final reversed = lines.reversed.toList();
    return Container(
      color: consoleBg,
      padding: const EdgeInsets.all(12),
      child: ListView.builder(
        itemCount: reversed.length,
        itemBuilder: (ctx, i) {
          final line = reversed[i];
          Color textColor = Colors.white70;
          if (line.contains('ERROR') || line.contains('CRITICAL')) {
            textColor = Colors.redAccent;
          } else if (line.contains('WARN')) {
            textColor = Colors.orangeAccent;
          } else if (line.contains('Copied') ||
              line.contains('tamamlandi') ||
              line.contains('tamamlandı')) {
            textColor = Colors.greenAccent;
          } else if (line.contains('ETA')) {
            textColor = const Color(0xFF38BDF8);
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: SelectableText(
              line,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 12,
                color: textColor,
              ),
            ),
          );
        },
      ),
    );
  }
}
