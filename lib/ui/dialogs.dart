import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/sync_profile.dart';
import '../services/rclone_service.dart';
import 'brand_widgets.dart';

class RemoteFolderPickerDialog extends StatefulWidget {
  final RcloneService service;
  final String remoteName;
  final String initialPath;

  const RemoteFolderPickerDialog({
    super.key,
    required this.service,
    required this.remoteName,
    required this.initialPath,
  });

  @override
  State<RemoteFolderPickerDialog> createState() =>
      _RemoteFolderPickerDialogState();
}

class _RemoteFolderPickerDialogState extends State<RemoteFolderPickerDialog> {
  late String _currentPath;
  List<String> _folders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath.trim().replaceAll('\\', '/');
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.service.listRemoteFolders(
        widget.remoteName,
        _currentPath,
      );
      if (mounted) {
        setState(() {
          _folders = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _navigateInto(String folderName) {
    setState(() {
      _currentPath =
          _currentPath.isEmpty ? folderName : '$_currentPath/$folderName';
    });
    _loadFolders();
  }

  void _navigateUp() {
    if (_currentPath.isEmpty) return;
    final idx = _currentPath.lastIndexOf('/');
    setState(() {
      _currentPath = idx == -1 ? '' : _currentPath.substring(0, idx);
    });
    _loadFolders();
  }

  Future<void> _createNewFolderDialog() async {
    final controller = TextEditingController();
    final createdName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Google Drive\'da Yeni Klasör Oluştur'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Klasör Adı',
            hintText: 'Örn: Yedekler_2026',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            icon: const Icon(Icons.create_new_folder),
            label: const Text('Oluştur'),
          ),
        ],
      ),
    );

    if (createdName != null && createdName.isNotEmpty) {
      setState(() => _loading = true);
      final target =
          _currentPath.isEmpty ? createdName : '$_currentPath/$createdName';
      final ok = await widget.service.createRemoteFolder(
        widget.remoteName,
        target,
      );
      if (ok) {
        _currentPath = target;
      }
      await _loadFolders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fullSpec = _currentPath.isEmpty
        ? '${widget.remoteName}:/ (Kök Dizin)'
        : '${widget.remoteName}:$_currentPath';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 640,
            height: 540,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F1523).withValues(alpha: 0.90)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFCBD5E1),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.40)
                      : const Color(0xFF64748B).withValues(alpha: 0.15),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppleDiskLogo(size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const ClonegilBrandText(fontSize: 16),
                              const SizedBox(width: 8),
                              Text(
                                '• Google Drive Klasör Seçici',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Hedef uzaktaki bulut klasörünü seçin veya yeni klasör oluşturun',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Yeni Klasör Oluştur',
                      onPressed: _loading ? null : _createNewFolderDialog,
                      icon: const Icon(Icons.create_new_folder_outlined),
                    ),
                    IconButton(
                      tooltip: 'Yenile',
                      onPressed: _loading ? null : _loadFolders,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0D1017)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed:
                        (_loading || _currentPath.isEmpty) ? null : _navigateUp,
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    tooltip: 'Üst Klasöre Çık',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      fullSpec,
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        color: isDark
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF0284C7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Alt klasöre girmek için klasöre tıklayın veya mevcut klasörü seçmek için alttaki "Bu Klasörü Seç" butonuna basın:',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Material(
                color: isDark
                    ? const Color(0xFF0D1017)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _loading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Google Drive klasörleri listeleniyor...'),
                          ],
                        ),
                      )
                    : _error != null
                        ? Center(child: Text('Hata: $_error'))
                        : _folders.isEmpty
                            ? Center(
                                child: Text(
                                  'Bu klasörün içinde alt klasör yok.\nDoğrudan "Bu Klasörü Seç" diyebilirsiniz.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _folders.length,
                                separatorBuilder: (_, _) => Divider(
                                  height: 1,
                                  color: isDark
                                      ? Colors.white10
                                      : const Color(0xFFE2E8F0),
                                ),
                                itemBuilder: (ctx, i) {
                                  final f = _folders[i];
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.folder,
                                      color: Color(0xFFFBBF24),
                                    ),
                                    title: Text(f),
                                    trailing: Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: isDark
                                          ? Colors.white38
                                          : const Color(0xFF94A3B8),
                                    ),
                                    onTap: () => _navigateInto(f),
                                  );
                                },
                              ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _currentPath),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    _currentPath.isEmpty
                        ? 'Kök Dizini Seç (${widget.remoteName}:)'
                        : 'Bu Klasörü Seç ($_currentPath)',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    ),
    );
  }
}

class ProfileEditorDialog extends StatefulWidget {
  final RcloneService service;
  final List<RcloneRemoteInfo> remotes;
  final SyncProfile? existing;

  const ProfileEditorDialog({
    super.key,
    required this.service,
    required this.remotes,
    this.existing,
  });

  @override
  State<ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<ProfileEditorDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _localPathCtrl;
  late TextEditingController _remotePathCtrl;
  late TextEditingController _bwLimitCtrl;
  late TextEditingController _prioritySubCtrl;
  late TextEditingController _debounceCtrl;
  late TextEditingController _fullSyncMinsCtrl;
  late TextEditingController _excludesCtrl;

  late String _selectedRemote;
  late String _syncMode;
  late bool _autoStart;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _localPathCtrl = TextEditingController(text: e?.localPath ?? '');
    _remotePathCtrl = TextEditingController(text: e?.remotePath ?? '');
    _bwLimitCtrl = TextEditingController(text: e?.bwLimit ?? '2M:off');
    _prioritySubCtrl = TextEditingController(text: e?.prioritySubfolder ?? '');
    _debounceCtrl =
        TextEditingController(text: (e?.debounceSeconds ?? 10).toString());
    _fullSyncMinsCtrl =
        TextEditingController(text: (e?.fullSyncMinutes ?? 30).toString());
    _excludesCtrl = TextEditingController(
      text: (e?.excludePatterns ??
              const [
                'desktop.ini',
                'Thumbs.db',
                'sync.ffs_db',
                '~\$*',
                '*.tmp',
                '*.temp',
                '.gdrive-sync*',
              ])
          .join(', '),
    );

    final availableRemoteNames = widget.remotes.map((r) => r.name).toList();
    if (e != null && availableRemoteNames.contains(e.remoteName)) {
      _selectedRemote = e.remoteName;
    } else if (availableRemoteNames.contains('gdrive')) {
      _selectedRemote = 'gdrive';
    } else if (availableRemoteNames.isNotEmpty) {
      _selectedRemote = availableRemoteNames.first;
    } else {
      _selectedRemote = 'gdrive';
    }

    _syncMode = e?.syncMode ?? 'sync';
    _autoStart = e?.autoStart ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _localPathCtrl.dispose();
    _remotePathCtrl.dispose();
    _bwLimitCtrl.dispose();
    _prioritySubCtrl.dispose();
    _debounceCtrl.dispose();
    _fullSyncMinsCtrl.dispose();
    _excludesCtrl.dispose();
    super.dispose();
  }

  Future<void> _browseLocal() async {
    final picked = await widget.service.pickLocalFolder(
      initialDirectory: _localPathCtrl.text.trim(),
    );
    if (picked != null && picked.isNotEmpty) {
      setState(() {
        _localPathCtrl.text = picked;
        if (_nameCtrl.text.trim().isEmpty) {
          final leaf = picked.split(RegExp(r'[\\/]')).last;
          _nameCtrl.text = leaf;
          if (_remotePathCtrl.text.trim().isEmpty) {
            _remotePathCtrl.text = leaf;
          }
        }
      });
    }
  }

  Future<void> _browseRemote() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => RemoteFolderPickerDialog(
        service: widget.service,
        remoteName: _selectedRemote,
        initialPath: _remotePathCtrl.text.trim(),
      ),
    );
    if (picked != null) {
      setState(() {
        _remotePathCtrl.text = picked;
      });
    }
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final localPath = _localPathCtrl.text.trim();
    if (name.isEmpty || localPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen profil adını ve yerel klasör yolunu girin.'),
        ),
      );
      return;
    }

    final slug = widget.existing?.id ??
        '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    final taskName = widget.existing?.taskName ?? 'Clonegil_AutoSync_$slug';
    final logDir =
        widget.existing?.logDir ?? '${RcloneService.appDataDir}\\logs\\$slug';

    final excludes = _excludesCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final profile = SyncProfile(
      id: slug,
      name: name,
      localPath: localPath,
      remoteName: _selectedRemote,
      remotePath: _remotePathCtrl.text.trim(),
      syncMode: _syncMode,
      bwLimit: _bwLimitCtrl.text.trim().isEmpty
          ? '2M:off'
          : _bwLimitCtrl.text.trim(),
      prioritySubfolder: _prioritySubCtrl.text.trim(),
      debounceSeconds: int.tryParse(_debounceCtrl.text.trim()) ?? 10,
      fullSyncMinutes: int.tryParse(_fullSyncMinsCtrl.text.trim()) ?? 30,
      autoStart: _autoStart,
      taskName: taskName,
      logDir: logDir,
      excludePatterns: excludes,
    );

    Navigator.pop(context, profile);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remoteItems = widget.remotes.isEmpty
        ? [const RcloneRemoteInfo(name: 'gdrive', type: 'drive')]
        : widget.remotes;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 720,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F1523).withValues(alpha: 0.90)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFCBD5E1),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.40)
                      : const Color(0xFF64748B).withValues(alpha: 0.15),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const AppleDiskLogo(size: 38),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const ClonegilBrandText(fontSize: 17),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.existing == null
                                        ? '• Yeni Klasör Kurgusu'
                                        : '• Kurgu Düzenle (${widget.existing!.name})',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Yerel disk ve Google Drive arasında anlık/zamanlanmış yedekleme kuralı tanımlayın',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white60
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Profil / Kurgu Adı',
                  hintText: 'Örn: Müzik Çalışmalarım, Projelerim 2026',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _localPathCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bilgisayardaki Yerel Klasör (Kaynak)',
                        hintText: 'Örn: D:\\Müzik Çalışmalarım',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.computer),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(
                    onPressed: _browseLocal,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Klasör Seç'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedRemote,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Bulut Bağlantısı',
                        border: OutlineInputBorder(),
                      ),
                      items: remoteItems
                          .map(
                            (r) => DropdownMenuItem(
                              value: r.name,
                              child: Text(
                                '${r.name}: (${r.type})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedRemote = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _remotePathCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Google Drive Hedef Klasörü',
                        hintText: 'Örn: Müzik Çalışmalarım',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cloud_done_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(
                    onPressed: _browseRemote,
                    icon: const Icon(Icons.manage_search),
                    label: const Text('Drive\'dan Seç'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _syncMode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Eşitleme Modu',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'sync',
                          child: Text(
                            'Birebir Sync (Yereli Drive\'a Eşitle)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'copy',
                          child: Text(
                            'Copy (Drive\'dan Silmeden Yedekle)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _syncMode = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _bwLimitCtrl,
                      decoration: InputDecoration(
                        labelText: 'Hız Sınırı (İnterneti Yavaşlatmaması İçin)',
                        hintText: '2M:off',
                        border: const OutlineInputBorder(),
                        suffixIcon: PopupMenuButton<String>(
                          tooltip: 'Hazır Hız Limiti Seç',
                          icon: const Icon(Icons.speed),
                          onSelected: (v) => setState(() => _bwLimitCtrl.text = v),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: '1M:off',
                              child: Text('1 MB/sn (~8 Mbps - Çok Düşük)'),
                            ),
                            PopupMenuItem(
                              value: '2M:off',
                              child: Text('2 MB/sn (~16 Mbps - Önerilen)'),
                            ),
                            PopupMenuItem(
                              value: '5M:off',
                              child: Text('5 MB/sn (~40 Mbps - Hızlı)'),
                            ),
                            PopupMenuItem(
                              value: '09:00,1.5M 01:00,8M',
                              child: Text('Gündüz 1.5 MB/s, Gece 8 MB/s'),
                            ),
                            PopupMenuItem(
                              value: 'off',
                              child: Text('Sınırsız (Tam Hız)'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _prioritySubCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Öncelikli Alt Klasör (Opsiyonel)',
                        hintText: 'Örn: 2026 (Önce bu klasörü eşitler)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _debounceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Anlık Algılama (sn)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _fullSyncMinsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Tam Tarama (dk)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _excludesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Hariç Tutulan Geçici Dosyalar (Virgülle Ayırın)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _autoStart,
                onChanged: (v) => setState(() => _autoStart = v),
                title: const Text(
                  'Windows Başlangıcında Durdurulamaz Görev (Watchdog) Olarak Çalıştır',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Bilgisayar açıldığında gizli başlar, kapanırsa 1 dk içinde kendi kendini yeniden başlatır ve dosya değişikliklerini anında eşitler.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('İptal'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Kaydet ve Servisi Uygula'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    ),
    );
  }
}

class RcloneSetupWizardDialog extends StatefulWidget {
  final RcloneService service;
  final VoidCallback onUpdated;

  const RcloneSetupWizardDialog({
    super.key,
    required this.service,
    required this.onUpdated,
  });

  @override
  State<RcloneSetupWizardDialog> createState() =>
      _RcloneSetupWizardDialogState();
}

class _RcloneSetupWizardDialogState extends State<RcloneSetupWizardDialog> {
  String? _rclonePath;
  String? _rcloneVersion;
  List<RcloneRemoteInfo> _remotes = [];
  bool _busy = false;
  String _statusMessage = '';
  final _newRemoteNameCtrl = TextEditingController(text: 'gdrive');

  @override
  void initState() {
    super.initState();
    _checkState();
  }

  @override
  void dispose() {
    _newRemoteNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkState() async {
    setState(() => _busy = true);
    final path = await widget.service.findRcloneExecutable();
    final ver = await widget.service.getRcloneVersion();
    final rem = await widget.service.listRemotes();
    if (mounted) {
      setState(() {
        _rclonePath = path;
        _rcloneVersion = ver;
        _remotes = rem;
        _busy = false;
      });
    }
  }

  Future<void> _installRclone() async {
    setState(() {
      _busy = true;
      _statusMessage = 'Rclone indiriliyor ve kuruluyor...';
    });
    await widget.service.installRclone(
      onProgress: (msg) {
        if (mounted) setState(() => _statusMessage = msg);
      },
    );
    await _checkState();
    widget.onUpdated();
  }

  Future<void> _connectGDrive() async {
    final name = _newRemoteNameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _busy = true;
      _statusMessage = 'Google Drive OAuth yetkilendirmesi başlatılıyor...';
    });
    await widget.service.connectNewGoogleDriveRemote(
      remoteName: name,
      onStatus: (msg) {
        if (mounted) setState(() => _statusMessage = msg);
      },
    );
    await _checkState();
    widget.onUpdated();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final installed = _rclonePath != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F1523).withValues(alpha: 0.90)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFCBD5E1),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.40)
                      : const Color(0xFF64748B).withValues(alpha: 0.15),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppleDiskLogo(size: 38),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const ClonegilBrandText(fontSize: 17),
                              const SizedBox(width: 8),
                              Text(
                                '• Kurulum Sihirbazı',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rclone motoru ve Google Drive bulut bağlantı yönetimi',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0D1017)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: installed
                      ? (isDark
                          ? Colors.green.withValues(alpha: 0.4)
                          : const Color(0xFF86EFAC))
                      : (isDark
                          ? Colors.orange.withValues(alpha: 0.4)
                          : const Color(0xFFFCD34D)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    installed ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: installed ? Colors.greenAccent : Colors.orangeAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          installed
                              ? 'Rclone Kurulu (${_rcloneVersion ?? ""})'
                              : 'Rclone Bulunamadı',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          installed
                              ? 'Konum: $_rclonePath'
                              : 'Tek tıkla C:\\rclone\\rclone.exe konumuna otomatik kurabilirsiniz.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _installRclone,
                    icon: const Icon(Icons.download),
                    label: Text(installed ? 'Güncelle / Onar' : 'Otomatik Kur'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Kayıtlı Bulut Bağlantıları (Remotes):',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_remotes.isEmpty)
              const Text(
                'Henüz kayıtlı bir Google Drive bağlantısı yok.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _remotes
                    .map(
                      (r) => Chip(
                        avatar: const Icon(
                          Icons.cloud_done,
                          size: 16,
                          color: Colors.greenAccent,
                        ),
                        label: Text('${r.name}: (${r.type})'),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 16),
            Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            const SizedBox(height: 10),
            const Text(
              'Yeni Google Drive Hesabı Bağla (OAuth):',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newRemoteNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bağlantı Adı (Remote Name)',
                      hintText: 'Örn: gdrive, gdrive_is',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: (_busy || !installed) ? null : _connectGDrive,
                  icon: const Icon(Icons.login),
                  label: const Text('Google Drive\'a Bağlan'),
                ),
              ],
            ),
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (_busy) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Kapat'),
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
