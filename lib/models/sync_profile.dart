class SyncProfile {
  final String id;
  final String name;
  final String localPath;
  final String remoteName;
  final String remotePath;
  final String syncMode; // 'sync' or 'copy'
  final String bwLimit; // e.g. '2M:off'
  final String prioritySubfolder; // e.g. '2026' or ''
  final int debounceSeconds;
  final int fullSyncMinutes;
  final bool autoStart;
  final String taskName;
  final String logDir;
  final List<String> excludePatterns;

  const SyncProfile({
    required this.id,
    required this.name,
    required this.localPath,
    required this.remoteName,
    required this.remotePath,
    this.syncMode = 'sync',
    this.bwLimit = '2M:off',
    this.prioritySubfolder = '',
    this.debounceSeconds = 10,
    this.fullSyncMinutes = 30,
    this.autoStart = true,
    required this.taskName,
    required this.logDir,
    this.excludePatterns = const [
      'desktop.ini',
      'Thumbs.db',
      'sync.ffs_db',
      '~\$*',
      '*.tmp',
      '*.temp',
      '.gdrive-sync*',
    ],
  });

  String get fullRemoteSpec =>
      remotePath.isEmpty ? '$remoteName:' : '$remoteName:$remotePath';

  SyncProfile copyWith({
    String? id,
    String? name,
    String? localPath,
    String? remoteName,
    String? remotePath,
    String? syncMode,
    String? bwLimit,
    String? prioritySubfolder,
    int? debounceSeconds,
    int? fullSyncMinutes,
    bool? autoStart,
    String? taskName,
    String? logDir,
    List<String>? excludePatterns,
  }) {
    return SyncProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      localPath: localPath ?? this.localPath,
      remoteName: remoteName ?? this.remoteName,
      remotePath: remotePath ?? this.remotePath,
      syncMode: syncMode ?? this.syncMode,
      bwLimit: bwLimit ?? this.bwLimit,
      prioritySubfolder: prioritySubfolder ?? this.prioritySubfolder,
      debounceSeconds: debounceSeconds ?? this.debounceSeconds,
      fullSyncMinutes: fullSyncMinutes ?? this.fullSyncMinutes,
      autoStart: autoStart ?? this.autoStart,
      taskName: taskName ?? this.taskName,
      logDir: logDir ?? this.logDir,
      excludePatterns: excludePatterns ?? this.excludePatterns,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'localPath': localPath,
        'remoteName': remoteName,
        'remotePath': remotePath,
        'syncMode': syncMode,
        'bwLimit': bwLimit,
        'prioritySubfolder': prioritySubfolder,
        'debounceSeconds': debounceSeconds,
        'fullSyncMinutes': fullSyncMinutes,
        'autoStart': autoStart,
        'taskName': taskName,
        'logDir': logDir,
        'excludePatterns': excludePatterns,
      };

  factory SyncProfile.fromJson(Map<String, dynamic> json) {
    return SyncProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      localPath: json['localPath'] as String,
      remoteName: json['remoteName'] as String? ?? 'gdrive',
      remotePath: json['remotePath'] as String? ?? '',
      syncMode: json['syncMode'] as String? ?? 'sync',
      bwLimit: json['bwLimit'] as String? ?? '2M:off',
      prioritySubfolder: json['prioritySubfolder'] as String? ?? '',
      debounceSeconds: json['debounceSeconds'] as int? ?? 10,
      fullSyncMinutes: json['fullSyncMinutes'] as int? ?? 30,
      autoStart: json['autoStart'] as bool? ?? true,
      taskName: json['taskName'] as String,
      logDir: json['logDir'] as String,
      excludePatterns: (json['excludePatterns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [
            'desktop.ini',
            'Thumbs.db',
            'sync.ffs_db',
            '~\$*',
            '*.tmp',
            '*.temp',
            '.gdrive-sync*',
          ],
    );
  }
}

class ProfileRuntimeStatus {
  final bool taskRegistered;
  final String taskState; // 'Running', 'Ready', 'Disabled', 'Yok'
  final bool disallowHardTerminate;
  final bool watcherRunning;
  final int? watcherPid;
  final bool rcloneRunning;
  final List<int> rclonePids;
  final String? lastBackupTime;
  final String? lastSyncedFile;
  final String? progressTransferred;
  final double? progressPercent;
  final String? currentSpeed;
  final String? currentEta;
  final String? xfrCounts;
  final List<String> mainLogs;
  final List<String> rcloneLogs;

  const ProfileRuntimeStatus({
    this.taskRegistered = false,
    this.taskState = 'Yok',
    this.disallowHardTerminate = false,
    this.watcherRunning = false,
    this.watcherPid,
    this.rcloneRunning = false,
    this.rclonePids = const [],
    this.lastBackupTime,
    this.lastSyncedFile,
    this.progressTransferred,
    this.progressPercent,
    this.currentSpeed,
    this.currentEta,
    this.xfrCounts,
    this.mainLogs = const [],
    this.rcloneLogs = const [],
  });

  bool get isHealthy => watcherRunning || taskState == 'Running';
}

class RcloneRemoteInfo {
  final String name;
  final String type;

  const RcloneRemoteInfo({required this.name, required this.type});
}

class DriveQuotaInfo {
  final String total;
  final String used;
  final String free;
  final String trashed;

  const DriveQuotaInfo({
    required this.total,
    required this.used,
    required this.free,
    required this.trashed,
  });

  double? get usageRatio {
    final u = _parseToBytes(used);
    final t = _parseToBytes(total);
    if (u != null && t != null && t > 0) {
      return (u / t).clamp(0.0, 1.0);
    }
    return null;
  }

  int? get usagePercent {
    final r = usageRatio;
    return r != null ? (r * 100).round() : null;
  }

  static double? _parseToBytes(String str) {
    final clean = str.trim();
    final match = RegExp(r'^([\d.,]+)\s*([a-zA-Z]+)?').firstMatch(clean);
    if (match == null) return null;
    final numStr = match.group(1)!.replaceAll(',', '.');
    final val = double.tryParse(numStr);
    if (val == null) return null;
    final unit = (match.group(2) ?? '').toLowerCase();

    if (unit.startsWith('p')) return val * 1024 * 1024 * 1024 * 1024 * 1024;
    if (unit.startsWith('t')) return val * 1024 * 1024 * 1024 * 1024;
    if (unit.startsWith('g')) return val * 1024 * 1024 * 1024;
    if (unit.startsWith('m')) return val * 1024 * 1024;
    if (unit.startsWith('k')) return val * 1024;
    return val;
  }
}

