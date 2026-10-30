import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/sync_profile.dart';

class RcloneService {
  static String get appDataDir {
    final localAppData =
        Platform.environment['LOCALAPPDATA'] ?? 'C:\\Users\\Public';
    return '$localAppData\\Clonegil';
  }

  static String get profilesFilePath => '$appDataDir\\profiles.json';
  static String get settingsFilePath => '$appDataDir\\settings.json';

  Future<ThemeMode> loadThemeMode() async {
    try {
      final file = File(settingsFilePath);
      if (await file.exists()) {
        final content = await file.readAsString(encoding: utf8);
        final map = jsonDecode(content) as Map<String, dynamic>;
        final mode = map['themeMode'] as String?;
        if (mode == 'light') return ThemeMode.light;
        if (mode == 'dark') return ThemeMode.dark;
      }
    } catch (_) {}
    return ThemeMode.dark;
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    try {
      final dir = Directory(appDataDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File(settingsFilePath);
      Map<String, dynamic> map = {};
      if (await file.exists()) {
        try {
          map = jsonDecode(await file.readAsString(encoding: utf8))
              as Map<String, dynamic>;
        } catch (_) {}
      }
      map['themeMode'] = mode == ThemeMode.light ? 'light' : 'dark';
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(map),
        encoding: utf8,
      );
    } catch (_) {}
  }

  Future<String?> findRcloneExecutable() async {
    const defaultPath = 'C:\\rclone\\rclone.exe';
    if (await File(defaultPath).exists()) {
      return defaultPath;
    }
    try {
      final res = await Process.run('where.exe', ['rclone'], runInShell: true);
      if (res.exitCode == 0) {
        final lines = res.stdout
            .toString()
            .split(RegExp(r'\r?\n'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (lines.isNotEmpty && await File(lines.first).exists()) {
          return lines.first;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> getRcloneVersion() async {
    final exe = await findRcloneExecutable();
    if (exe == null) return null;
    try {
      final res = await Process.run(
        exe,
        ['version'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode == 0) {
        final firstLine = res.stdout.toString().split(RegExp(r'\r?\n')).first;
        return firstLine.trim();
      }
    } catch (_) {}
    return null;
  }

  Future<bool> installRclone({
    required void Function(String message) onProgress,
  }) async {
    try {
      onProgress('Rclone resmi paketi indiriliyor (downloads.rclone.org)...');
      const psScript = r'''
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$destDir = "C:\rclone"
if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
$zipPath = Join-Path $env:TEMP "rclone-current-windows-amd64.zip"
$extractPath = Join-Path $env:TEMP "rclone_extract"
if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
Invoke-WebRequest -Uri "https://downloads.rclone.org/rclone-current-windows-amd64.zip" -OutFile $zipPath -UseBasicParsing
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
$exeFile = Get-ChildItem -Path $extractPath -Filter "rclone.exe" -Recurse | Select-Object -First 1
if ($null -eq $exeFile) { throw "rclone.exe pakette bulunamadi." }
Copy-Item -Path $exeFile.FullName -Destination (Join-Path $destDir "rclone.exe") -Force
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$destDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$destDir", "User")
}
Write-Output "OK"
''';
      final res = await Process.run(
        'powershell.exe',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', psScript],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode == 0 && res.stdout.toString().contains('OK')) {
        onProgress('Rclone C:\\rclone\\rclone.exe konumuna başarıyla kuruldu.');
        return true;
      } else {
        onProgress('Kurulum hatası: ${res.stderr}');
        return false;
      }
    } catch (e) {
      onProgress('Kurulum istisnası: $e');
      return false;
    }
  }

  Future<List<RcloneRemoteInfo>> listRemotes() async {
    final exe = await findRcloneExecutable();
    if (exe == null) return [];
    try {
      final res = await Process.run(
        exe,
        ['listremotes', '--long'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode != 0) return [];
      final lines = res.stdout.toString().split(RegExp(r'\r?\n'));
      final result = <RcloneRemoteInfo>[];
      for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty) continue;
        final parts = line.split(':');
        if (parts.length >= 2) {
          final name = parts[0].trim();
          final type = parts.sublist(1).join(':').trim();
          result.add(RcloneRemoteInfo(name: name, type: type));
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<DriveQuotaInfo?> getDriveQuota(String remoteName) async {
    final exe = await findRcloneExecutable();
    if (exe == null) return null;
    try {
      final res = await Process.run(
        exe,
        ['about', '$remoteName:'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode != 0) return null;
      String total = '-';
      String used = '-';
      String free = '-';
      String trashed = '-';
      for (final line in res.stdout.toString().split(RegExp(r'\r?\n'))) {
        final trimmed = line.trim();
        if (trimmed.startsWith('Total:')) {
          total = trimmed.substring(6).trim();
        } else if (trimmed.startsWith('Used:')) {
          used = trimmed.substring(5).trim();
        } else if (trimmed.startsWith('Free:')) {
          free = trimmed.substring(5).trim();
        } else if (trimmed.startsWith('Trashed:')) {
          trashed = trimmed.substring(8).trim();
        }
      }
      return DriveQuotaInfo(
        total: total,
        used: used,
        free: free,
        trashed: trashed,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> connectNewGoogleDriveRemote({
    required String remoteName,
    required void Function(String status) onStatus,
  }) async {
    final exe = await findRcloneExecutable();
    if (exe == null) {
      onStatus('Önce Rclone kurulmalıdır.');
      return false;
    }
    final cleanName = remoteName.replaceAll(':', '').trim();
    if (cleanName.isEmpty) return false;
    try {
      onStatus(
        'Tarayıcıda Google OAuth izin ekranı açılıyor... Lütfen Google hesabınızla giriş yapıp izin verin.',
      );
      final res = await Process.run(
        exe,
        ['config', 'create', cleanName, 'drive', 'scope', 'drive'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode == 0) {
        onStatus('"$cleanName:" Google Drive bağlantısı başarıyla oluşturuldu!');
        return true;
      } else {
        onStatus('Bağlantı oluşturulamadı: ${res.stderr}');
        return false;
      }
    } catch (e) {
      onStatus('Hata: $e');
      return false;
    }
  }

  Future<List<String>> listRemoteFolders(
    String remoteName,
    String remotePath,
  ) async {
    final exe = await findRcloneExecutable();
    if (exe == null) return [];
    final spec = remotePath.trim().isEmpty
        ? '$remoteName:'
        : '$remoteName:${remotePath.trim()}';
    try {
      final res = await Process.run(
        exe,
        ['lsf', spec, '--dirs-only'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode != 0) return [];
      final folders = res.stdout
          .toString()
          .split(RegExp(r'\r?\n'))
          .map((e) => e.trim().replaceAll(RegExp(r'/$'), ''))
          .where((e) => e.isNotEmpty)
          .toList();
      final unique = folders.toSet().toList()..sort();
      return unique;
    } catch (_) {
      return [];
    }
  }

  Future<bool> createRemoteFolder(
    String remoteName,
    String remotePath,
  ) async {
    final exe = await findRcloneExecutable();
    if (exe == null) return false;
    final clean = remotePath.trim().replaceAll('\\', '/');
    if (clean.isEmpty) return false;
    try {
      final res = await Process.run(
        exe,
        ['mkdir', '$remoteName:$clean'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<String?> pickLocalFolder({String? initialDirectory}) async {
    final initEscaped = (initialDirectory ?? '').replaceAll("'", "''");
    final script = '''
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
\$dlg = New-Object System.Windows.Forms.FolderBrowserDialog
\$dlg.Description = "Yedeklenecek Yerel Klasoru Secin"
\$dlg.ShowNewFolderButton = \$true
if ('$initEscaped' -ne '' -and (Test-Path '$initEscaped')) {
    \$dlg.SelectedPath = '$initEscaped'
}
\$form = New-Object System.Windows.Forms.Form
\$form.TopMost = \$true
if (\$dlg.ShowDialog(\$form) -eq [System.Windows.Forms.DialogResult]::OK) {
    Write-Output \$dlg.SelectedPath
}
''';
    try {
      final res = await Process.run(
        'powershell.exe',
        ['-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-Command', script],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode == 0) {
        final out = res.stdout.toString().trim();
        if (out.isNotEmpty) return out;
      }
    } catch (_) {}
    return null;
  }

  Future<List<SyncProfile>> loadProfiles() async {
    final dir = Directory(appDataDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(profilesFilePath);
    if (await file.exists()) {
      try {
        final content = await file.readAsString(encoding: utf8);
        final list = jsonDecode(content) as List<dynamic>;
        final profiles = list
            .map((e) => SyncProfile.fromJson(e as Map<String, dynamic>))
            .toList();
        if (profiles.isNotEmpty) return profiles;
      } catch (_) {}
    }

    // Varsayılan olarak mevcut çalışan "Müzik Çalışmalarım" kurgusunu içeri aktar
    final localAppData =
        Platform.environment['LOCALAPPDATA'] ?? 'C:\\Users\\umitu\\AppData\\Local';
    final defaultProfile = SyncProfile(
      id: 'muzik_calismalarim',
      name: 'Müzik Çalışmalarım',
      localPath: 'D:\\Müzik Çalışmalarım',
      remoteName: 'gdrive',
      remotePath: 'Müzik Çalışmalarım',
      syncMode: 'sync',
      bwLimit: '2M:off',
      prioritySubfolder: '2026',
      debounceSeconds: 10,
      fullSyncMinutes: 30,
      autoStart: true,
      taskName: 'MuzikCalismalarim_GDrive_AutoSync',
      logDir: '$localAppData\\RcloneMuzikSync',
    );
    await saveProfiles([defaultProfile]);
    return [defaultProfile];
  }

  Future<void> saveProfiles(List<SyncProfile> profiles) async {
    final dir = Directory(appDataDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(profilesFilePath);
    final jsonStr =
        const JsonEncoder.withIndent('  ').convert(profiles.map((e) => e.toJson()).toList());
    await file.writeAsString(jsonStr, encoding: utf8);
  }

  /// Türkçe ve özel karakterleri PowerShell'de BOM'dan bağımsız $([char]0xXXXX) formatına çevirir.
  static String toPowerShellAsciiSafeString(String input) {
    final sb = StringBuffer();
    for (final codeUnit in input.codeUnits) {
      if (codeUnit >= 32 && codeUnit <= 126) {
        final ch = String.fromCharCode(codeUnit);
        if (ch == '"' || ch == '`' || ch == '\$') {
          sb.write('`$ch');
        } else {
          sb.write(ch);
        }
      } else {
        final hex = codeUnit.toRadixString(16).padLeft(4, '0').toUpperCase();
        sb.write('\$([char]0x$hex)');
      }
    }
    return sb.toString();
  }

  String generateWorkerPowerShellScript(SyncProfile profile, String rcloneExe) {
    final safeName = toPowerShellAsciiSafeString(profile.name);
    final safeLocalRoot = toPowerShellAsciiSafeString(profile.localPath);
    final safeRemoteRoot = toPowerShellAsciiSafeString(profile.fullRemoteSpec);
    final safeRcloneExe = toPowerShellAsciiSafeString(rcloneExe);
    final safeLogDir = toPowerShellAsciiSafeString(profile.logDir);
    final safeTaskName = toPowerShellAsciiSafeString(profile.taskName);
    final safePrioritySub = toPowerShellAsciiSafeString(profile.prioritySubfolder.trim());
    final safeSyncMode = profile.syncMode == 'copy' ? 'copy' : 'sync';
    final excludesLiteral = profile.excludePatterns
        .map((e) => '"${toPowerShellAsciiSafeString(e)}"')
        .join(',\n    ');

    return '''
<#
.SYNOPSIS
    Clonegil Otomatik Arka Plan Dosya Izleyici (FileSystemWatcher) ve Rclone Sync Servisi
    Profil: ${profile.id}
#>

param(
    [ValidateSet("Watch", "Start", "SyncNow", "Status", "Stop", "Install", "Uninstall")]
    [string]\$Action = "Watch",

    [string]\$BwLimit = "${profile.bwLimit}"
)

\$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

\$ProfileName     = "$safeName"
\$LocalRoot       = "$safeLocalRoot"
\$RemoteRoot      = "$safeRemoteRoot"
\$SyncVerb        = "$safeSyncMode"
\$PrioritySub     = "$safePrioritySub"
\$RcloneExe       = "$safeRcloneExe"
\$LogDir          = "$safeLogDir"
\$WorkerScript    = Join-Path \$LogDir "service-worker.ps1"
\$MainLogFile     = Join-Path \$LogDir "sync.log"
\$RcloneLogFile   = Join-Path \$LogDir "rclone-detail.log"
\$PidFile         = Join-Path \$LogDir "watcher.pid"
\$RclonePidFile   = Join-Path \$LogDir "rclone.pid"
\$TaskName        = "$safeTaskName"
\$DebounceSeconds = ${profile.debounceSeconds}
\$FullSyncMinutes = ${profile.fullSyncMinutes}

\$ExcludePatterns = @(
    $excludesLiteral
)

if (-not (Test-Path \$LogDir)) {
    New-Item -ItemType Directory -Path \$LogDir -Force | Out-Null
}

function Write-SyncLog {
    param([string]\$Message, [string]\$Level = "INFO")
    \$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    \$line = "[\$timestamp] [\$Level] \$Message"
    Write-Host \$line
    try {
        if ((Test-Path \$MainLogFile) -and ((Get-Item \$MainLogFile).Length -gt 10MB)) {
            Move-Item -Path \$MainLogFile -Destination "\$MainLogFile.old" -Force -ErrorAction SilentlyContinue
        }
        Add-Content -Path \$MainLogFile -Value \$line -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

function Test-IgnoredPath {
    param([string]\$FullPath)
    if ([string]::IsNullOrWhiteSpace(\$FullPath)) { return \$true }
    if (\$FullPath -match "(^|[\\\\/])\\.git([\\\\/]|\$)") { return \$true }
    \$leaf = Split-Path \$FullPath -Leaf
    foreach (\$pat in \$ExcludePatterns) {
        if (\$leaf -like \$pat) { return \$true }
    }
    return \$false
}

function Get-RelativeFolder {
    param([string]\$FullPath)
    if (\$FullPath.StartsWith(\$LocalRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        \$rel = \$FullPath.Substring(\$LocalRoot.Length).TrimStart('\\', '/')
    } else {
        return ""
    }
    \$targetPath = Join-Path \$LocalRoot \$rel
    if (Test-Path \$targetPath -PathType Container) {
        return (\$rel -replace '\\\\', '/')
    } else {
        \$parent = Split-Path \$rel -Parent
        if ([string]::IsNullOrWhiteSpace(\$parent)) { return "" }
        return (\$parent -replace '\\\\', '/')
    }
}

function Start-RcloneProcess {
    param(
        [string]\$SourcePath,
        [string]\$DestPath,
        [string]\$CurrentBwLimit = \$BwLimit,
        [switch]\$Wait,
        [switch]\$FastTargeted
    )

    \$argsList = @(
        "\$SyncVerb",
        "`"\$SourcePath`"",
        "`"\$DestPath`"",
        "--order-by", "`"modtime,desc`"",
        "--transfers", "2",
        "--checkers", "4",
        "--tpslimit", "4",
        "--drive-chunk-size", "16M",
        "--fast-list",
        "--retries", "5",
        "--retries-sleep", "10s",
        "--log-file", "`"\$RcloneLogFile`"",
        "--log-level", "INFO",
        "--stats", "15s",
        "--stats-one-line"
    )

    if (-not [string]::IsNullOrWhiteSpace(\$CurrentBwLimit) -and \$CurrentBwLimit -ne "off") {
        \$argsList += "--bwlimit"
        \$argsList += "`"\$CurrentBwLimit`""
    }

    foreach (\$ex in \$ExcludePatterns) {
        \$argsList += "--exclude"
        \$argsList += "`"\$ex`""
    }

    \$psi = New-Object System.Diagnostics.ProcessStartInfo
    \$psi.FileName = \$RcloneExe
    \$psi.Arguments = (\$argsList -join " ")
    \$psi.UseShellExecute = \$false
    \$psi.CreateNoWindow = \$true
    \$psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

    \$proc = [System.Diagnostics.Process]::Start(\$psi)
    if (\$null -ne \$proc -and -not \$proc.HasExited) {
        try {
            \$proc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal
            Set-Content -Path \$RclonePidFile -Value \$proc.Id -Force
        } catch {}
    }

    if (\$Wait -and \$null -ne \$proc) {
        \$proc.WaitForExit()
        Remove-Item \$RclonePidFile -Force -ErrorAction SilentlyContinue
        return \$proc.ExitCode
    }
    return \$proc
}

function Stop-SyncService {
    Stop-ScheduledTask -TaskName \$TaskName -ErrorAction SilentlyContinue
    if (Test-Path \$PidFile) {
        \$savedPid = Get-Content \$PidFile -ErrorAction SilentlyContinue
        if (\$savedPid) {
            Stop-Process -Id \$savedPid -Force -ErrorAction SilentlyContinue
            Write-SyncLog "Izleyici servisi durduruldu (PID: \$savedPid)."
        }
        Remove-Item \$PidFile -Force -ErrorAction SilentlyContinue
    }
    Remove-Item \$RclonePidFile -Force -ErrorAction SilentlyContinue
    Write-SyncLog "Servis durdurma komutu tamamlandi."
}

function Install-StartupTask {
    \$currentScript = \$PSCommandPath
    if (-not [string]::IsNullOrWhiteSpace(\$currentScript) -and (\$currentScript -ne \$WorkerScript)) {
        Copy-Item -Path \$currentScript -Destination \$WorkerScript -Force
    }

    \$vbsPath = Join-Path \$LogDir "launch-hidden.vbs"
    \$vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""\$WorkerScript"" -Action Watch -BwLimit ""\$BwLimit""", 0, True
"@
    Set-Content -Path \$vbsPath -Value \$vbsContent -Encoding ASCII

    try {
        \$actionObj = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"\$vbsPath`""
        \$triggerLogon = New-ScheduledTaskTrigger -AtLogOn -User \$env:USERNAME
        \$triggerWatchdog = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 5)

        \$settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -DontStopOnIdleEnd `
            -DisallowHardTerminate `
            -StartWhenAvailable `
            -ExecutionTimeLimit ([TimeSpan]::Zero) `
            -MultipleInstances IgnoreNew `
            -RestartCount 999 `
            -RestartInterval (New-TimeSpan -Minutes 1) `
            -Priority 8

        Register-ScheduledTask `
            -TaskName \$TaskName `
            -Action \$actionObj `
            -Trigger @(\$triggerLogon, \$triggerWatchdog) `
            -Settings \$settings `
            -Description "Clonegil Otomatik Yedekleme Servisi (\${ProfileName} - \$LocalRoot -> \$RemoteRoot)" `
            -Force | Out-Null

        Start-ScheduledTask -TaskName \$TaskName -ErrorAction SilentlyContinue
        Write-SyncLog "Zamanlanmis gorev (\$TaskName) SURESIZ, ZORLA DURDURULAMAZ ve WATCHDOG korumali olarak kuruldu ve baslatildi."
    } catch {
        Write-SyncLog "Gorev zamanlayici hatasi: \$(\$_.Exception.Message)" "ERROR"
    }
}

function Uninstall-StartupTask {
    Unregister-ScheduledTask -TaskName \$TaskName -Confirm:\$false -ErrorAction SilentlyContinue
    Stop-SyncService
    Write-SyncLog "Otomatik baslatma gorevi (\$TaskName) kaldirildi ve servis durduruldu."
}

switch (\$Action) {
    "Start" {
        Start-ScheduledTask -TaskName \$TaskName -ErrorAction SilentlyContinue
        Write-SyncLog "Arka plan servisi (\$TaskName) baslatildi."
        exit 0
    }
    "Stop" {
        Stop-SyncService
        exit 0
    }
    "Install" {
        Install-StartupTask
        exit 0
    }
    "Uninstall" {
        Uninstall-StartupTask
        exit 0
    }
    "SyncNow" {
        Write-SyncLog "Manuel tam senkronizasyon baslatiliyor (BwLimit: \$BwLimit)..."
        \$code = Start-RcloneProcess -SourcePath \$LocalRoot -DestPath \$RemoteRoot -CurrentBwLimit \$BwLimit -Wait
        Write-SyncLog "Manuel senkronizasyon tamamlandi (Cikis Kodu: \$code)."
        exit \$code
    }
}

# --- WATCH MODU ---
if (Test-Path \$PidFile) {
    \$existingPid = Get-Content \$PidFile -ErrorAction SilentlyContinue
    if (\$existingPid -and (\$existingPid -ne \$PID)) {
        \$existingProc = Get-Process -Id \$existingPid -ErrorAction SilentlyContinue
        if (\$existingProc -and \$existingProc.ProcessName -match "powershell|pwsh") {
            exit 0
        }
    }
}

Set-Content -Path \$PidFile -Value \$PID -Force

try {
    [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal
} catch {}

Write-SyncLog "=== \$ProfileName Otomatik Sync Baslatildi (PID: \$PID, Mod: \$SyncVerb, BwLimit: \$BwLimit) ==="
Write-SyncLog "Yerel Dizin : \$LocalRoot"
Write-SyncLog "Uzak Dizin  : \$RemoteRoot"

\$bgFullSyncProc   = \$null
\$initialPrioPhase = \$false

if (-not [string]::IsNullOrWhiteSpace(\$PrioritySub)) {
    \$prioLocal  = Join-Path \$LocalRoot \$PrioritySub
    \$prioRemote = "\$RemoteRoot/\$PrioritySub"
    if (Test-Path \$prioLocal) {
        Write-SyncLog "Oncelikli klasor (\$PrioritySub) senkronizasyonu baslatiliyor..."
        \$bgFullSyncProc = Start-RcloneProcess -SourcePath \$prioLocal -DestPath \$prioRemote -CurrentBwLimit \$BwLimit
        \$initialPrioPhase = (\$null -ne \$bgFullSyncProc)
    }
}

if (-not \$initialPrioPhase) {
    Write-SyncLog "Ilk tam dizin senkronizasyonu baslatiliyor..."
    \$bgFullSyncProc = Start-RcloneProcess -SourcePath \$LocalRoot -DestPath \$RemoteRoot -CurrentBwLimit \$BwLimit
}

\$watcher = New-Object System.IO.FileSystemWatcher
\$watcher.Path = \$LocalRoot
\$watcher.Filter = "*.*"
\$watcher.IncludeSubdirectories = \$true
\$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size'
\$watcher.InternalBufferSize = 65536

\$PendingFolders = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
\$LastEventTime  = [DateTime]::MinValue
\$HasChanges     = \$false

\$sourceIds = @("FSW_Created", "FSW_Changed", "FSW_Deleted", "FSW_Renamed")
foreach (\$sid in \$sourceIds) {
    Unregister-Event -SourceIdentifier \$sid -ErrorAction SilentlyContinue
}

[void](Register-ObjectEvent -InputObject \$watcher -EventName "Created" -SourceIdentifier "FSW_Created")
[void](Register-ObjectEvent -InputObject \$watcher -EventName "Changed" -SourceIdentifier "FSW_Changed")
[void](Register-ObjectEvent -InputObject \$watcher -EventName "Deleted" -SourceIdentifier "FSW_Deleted")
[void](Register-ObjectEvent -InputObject \$watcher -EventName "Renamed" -SourceIdentifier "FSW_Renamed")

\$watcher.EnableRaisingEvents = \$true
Write-SyncLog "Dosya izleyici aktif: '\$LocalRoot' uzerindeki tum degisiklikler anlik takip ediliyor."

\$lastFullSyncTime = Get-Date

try {
    while (\$true) {
        [void](Wait-Event -Timeout 2)

        \$events = Get-Event -ErrorAction SilentlyContinue
        if (\$events) {
            foreach (\$ev in \$events) {
                if (\$ev.SourceIdentifier -like "FSW_*") {
                    \$path = \$ev.SourceEventArgs.FullPath
                    if (-not (Test-IgnoredPath -FullPath \$path)) {
                        \$relFolder = Get-RelativeFolder -FullPath \$path
                        [void]\$PendingFolders.Add(\$relFolder)
                        \$LastEventTime = Get-Date
                        \$HasChanges = \$true
                    }
                }
                Remove-Event -EventIdentifier \$ev.EventIdentifier -ErrorAction SilentlyContinue
            }
        }

        if (\$HasChanges -and ((Get-Date) - \$LastEventTime).TotalSeconds -ge \$DebounceSeconds) {
            \$foldersToSync = @(\$PendingFolders)
            \$PendingFolders.Clear()
            \$HasChanges = \$false

            if ((\$foldersToSync -contains "") -or (\$foldersToSync.Count -gt 5)) {
                Write-SyncLog "Kok dizinde veya coklu klasorde degisiklik algilandi. Genel senkronizasyon tetikleniyor..."
                if (\$null -eq \$bgFullSyncProc -or \$bgFullSyncProc.HasExited) {
                    \$bgFullSyncProc = Start-RcloneProcess -SourcePath \$LocalRoot -DestPath \$RemoteRoot -CurrentBwLimit \$BwLimit
                    \$lastFullSyncTime = Get-Date
                }
            } else {
                foreach (\$relDir in \$foldersToSync) {
                    \$localSub  = Join-Path \$LocalRoot (\$relDir -replace '/', '\\')
                    \$remoteSub = "\$RemoteRoot/\$relDir"
                    if (Test-Path \$localSub) {
                        Write-SyncLog "Degisiklik algilandi -> '\$relDir' klasoru Google Drive'a esitleniyor..."
                        \$exitCode = Start-RcloneProcess -SourcePath \$localSub -DestPath \$remoteSub -CurrentBwLimit \$BwLimit -Wait -FastTargeted
                        Write-SyncLog "'\$relDir' klasor senkronizasyonu tamamlandi (Kod: \$exitCode)."
                    } else {
                        \$parentRel = Split-Path \$relDir -Parent
                        if ([string]::IsNullOrWhiteSpace(\$parentRel)) {
                            if (\$null -eq \$bgFullSyncProc -or \$bgFullSyncProc.HasExited) {
                                \$bgFullSyncProc = Start-RcloneProcess -SourcePath \$LocalRoot -DestPath \$RemoteRoot -CurrentBwLimit \$BwLimit
                            }
                        } else {
                            \$parentRel = \$parentRel -replace '\\\\', '/'
                            \$localParent = Join-Path \$LocalRoot (\$parentRel -replace '/', '\\')
                            \$remoteParent = "\$RemoteRoot/\$parentRel"
                            if (Test-Path \$localParent) {
                                Write-SyncLog "Klasor silindi -> Ust klasor '\$parentRel' esitleniyor..."
                                [void](Start-RcloneProcess -SourcePath \$localParent -DestPath \$remoteParent -CurrentBwLimit \$BwLimit -Wait -FastTargeted)
                            }
                        }
                    }
                }
            }
        }

        if (\$initialPrioPhase -and (\$null -ne \$bgFullSyncProc) -and \$bgFullSyncProc.HasExited) {
            if (\$bgFullSyncProc.ExitCode -eq 0) {
                Write-SyncLog "Oncelikli klasor (\$PrioritySub) senkronizasyonu tamamlandi. Tum dizin senkronizasyonuna geciliyor..."
                \$initialPrioPhase = \$false
                \$bgFullSyncProc = Start-RcloneProcess -SourcePath \$LocalRoot -DestPath \$RemoteRoot -CurrentBwLimit \$BwLimit
                \$lastFullSyncTime = Get-Date
            } else {
                Write-SyncLog "Oncelikli klasor senkronizasyonu kesintiye ugradi (Kod: \$(\$bgFullSyncProc.ExitCode)). 30 sn sonra devam edecek..." "WARN"
                Start-Sleep -Seconds 30
                \$prioLocal  = Join-Path \$LocalRoot \$PrioritySub
                \$prioRemote = "\$RemoteRoot/\$PrioritySub"
                \$bgFullSyncProc = Start-RcloneProcess -SourcePath \$prioLocal -DestPath \$prioRemote -CurrentBwLimit \$BwLimit
            }
        }

        if (-not \$initialPrioPhase) {
            if (\$null -eq \$bgFullSyncProc -or \$bgFullSyncProc.HasExited) {
                \$waitMins = if (\$null -ne \$bgFullSyncProc -and \$bgFullSyncProc.ExitCode -ne 0) { 2 } else { \$FullSyncMinutes }
                if (((Get-Date) - \$lastFullSyncTime).TotalMinutes -ge \$waitMins) {
                    Write-SyncLog "Arka plan tam dizin senkronizasyonu baslatiliyor..."
                    \$bgFullSyncProc = Start-RcloneProcess -SourcePath \$LocalRoot -DestPath \$RemoteRoot -CurrentBwLimit \$BwLimit
                    \$lastFullSyncTime = Get-Date
                }
            }
        }
    }
} finally {
    foreach (\$sid in \$sourceIds) {
        Unregister-Event -SourceIdentifier \$sid -ErrorAction SilentlyContinue
    }
    \$watcher.Dispose()
    Remove-Item \$PidFile -Force -ErrorAction SilentlyContinue
    Remove-Item \$RclonePidFile -Force -ErrorAction SilentlyContinue
    Write-SyncLog "Izleyici servisi kapatildi."
}
''';
  }

  Future<void> deployAndInstallProfileService(
    SyncProfile profile, {
    bool restartIfRunning = false,
  }) async {
    final exe = await findRcloneExecutable() ?? 'C:\\rclone\\rclone.exe';
    final logDir = Directory(profile.logDir);
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    final workerFile = File('${profile.logDir}\\service-worker.ps1');
    final scriptContent = generateWorkerPowerShellScript(profile, exe);
    await workerFile.writeAsString(scriptContent, encoding: ascii);

    // Eğer D:\Müzik Çalışmalarım ise oradaki gdrive-auto-sync.ps1'i de senkron tut
    final localScript = File('${profile.localPath}\\gdrive-auto-sync.ps1');
    if (await localScript.exists()) {
      try {
        await localScript.writeAsString(scriptContent, encoding: ascii);
      } catch (_) {}
    }

    if (restartIfRunning) {
      await stopProfileService(profile);
    }

    if (profile.autoStart) {
      await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          workerFile.path,
          '-Action',
          'Install',
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
    }
  }

  Future<void> startProfileService(SyncProfile profile) async {
    final workerFile = File('${profile.logDir}\\service-worker.ps1');
    if (!await workerFile.exists()) {
      await deployAndInstallProfileService(profile);
      return;
    }
    await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        workerFile.path,
        '-Action',
        'Install',
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  }

  Future<void> stopProfileService(SyncProfile profile) async {
    final workerFile = File('${profile.logDir}\\service-worker.ps1');
    if (await workerFile.exists()) {
      await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          workerFile.path,
          '-Action',
          'Stop',
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
    }
  }

  Future<void> uninstallProfileService(SyncProfile profile) async {
    final workerFile = File('${profile.logDir}\\service-worker.ps1');
    if (await workerFile.exists()) {
      await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          workerFile.path,
          '-Action',
          'Uninstall',
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
    }
  }

  Future<void> triggerSyncNow(SyncProfile profile) async {
    final exe = await findRcloneExecutable();
    if (exe == null) return;
    final workerFile = File('${profile.logDir}\\service-worker.ps1');
    if (!await workerFile.exists()) {
      await deployAndInstallProfileService(profile);
    }
    // Arka planda SyncNow başlat
    await Process.start(
      'powershell.exe',
      [
        '-NoProfile',
        '-WindowStyle',
        'Hidden',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        workerFile.path,
        '-Action',
        'SyncNow',
      ],
      mode: ProcessStartMode.detached,
    );
  }

  Future<String> runDedupe(SyncProfile profile) async {
    final exe = await findRcloneExecutable();
    if (exe == null) return 'Rclone bulunamadı.';
    try {
      final res = await Process.run(
        exe,
        ['dedupe', '--dedupe-mode', 'newest', profile.fullRemoteSpec, '-v'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      final out = '${res.stdout}\n${res.stderr}'.trim();
      return out.isEmpty ? 'Çift kayıt taraması tamamlandı.' : out;
    } catch (e) {
      return 'Hata: $e';
    }
  }

  Future<ProfileRuntimeStatus> getProfileStatus(SyncProfile profile) async {
    bool taskRegistered = false;
    String taskState = 'Yok';
    bool disallowHardTerminate = false;
    bool watcherRunning = false;
    int? watcherPid;
    List<int> rclonePids = [];

    final pidFilePath = '${profile.logDir}\\watcher.pid';
    final rclonePidPath = '${profile.logDir}\\rclone.pid';
    final mainLogPath = '${profile.logDir}\\sync.log';
    final rcloneLogPath = '${profile.logDir}\\rclone-detail.log';
    final safeLocalEscaped = profile.localPath.replaceAll("'", "''");

    try {
      final psCheck = '''
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
\$t = Get-ScheduledTask -TaskName "${profile.taskName}" -ErrorAction SilentlyContinue
\$tReg = \$null -ne \$t
\$tState = if (\$t) { \$t.State.ToString() } else { "Yok" }
\$tHard = if (\$t) { [bool]\$t.Settings.DisallowHardTerminate } else { \$false }

\$wPid = 0
\$wRun = \$false
if (Test-Path "$pidFilePath") {
    \$rawPid = (Get-Content "$pidFilePath" -ErrorAction SilentlyContinue | Select-Object -First 1)
    if (\$rawPid -match "^\\d+\$") {
        \$wPid = [int]\$rawPid
        \$p = Get-Process -Id \$wPid -ErrorAction SilentlyContinue
        if (\$p) { \$wRun = \$true }
    }
}

\$rPids = @()
if (Test-Path "$rclonePidPath") {
    \$rawRclonePid = (Get-Content "$rclonePidPath" -ErrorAction SilentlyContinue | Select-Object -First 1)
    if (\$rawRclonePid -match "^\\d+\$") {
        \$rp = [int]\$rawRclonePid
        \$p = Get-Process -Id \$rp -ErrorAction SilentlyContinue
        if (\$p -and \$p.ProcessName -eq "rclone") {
            \$rPids = @(\$rp)
        }
    }
}
if (\$rPids.Count -eq 0) {
    \$cims = Get-CimInstance Win32_Process -Filter "Name = 'rclone.exe'" -ErrorAction SilentlyContinue
    if (\$cims) {
        \$rPids = @(\$cims | Where-Object CommandLine -like '*$safeLocalEscaped*' | Select-Object -ExpandProperty ProcessId)
    }
}
\$obj = @{
    taskRegistered = \$tReg
    taskState = \$tState
    disallowHardTerminate = \$tHard
    watcherRunning = \$wRun
    watcherPid = \$wPid
    rclonePids = \$rPids
}
\$obj | ConvertTo-Json -Compress
''';

      final res = await Process.run(
        'powershell.exe',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', psCheck],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
        final map =
            jsonDecode(res.stdout.toString().trim()) as Map<String, dynamic>;
        taskRegistered = map['taskRegistered'] == true;
        taskState = map['taskState']?.toString() ?? 'Yok';
        disallowHardTerminate = map['disallowHardTerminate'] == true;
        watcherRunning = map['watcherRunning'] == true;
        final wp = map['watcherPid'] as int? ?? 0;
        watcherPid = wp > 0 ? wp : null;
        final rp = map['rclonePids'];
        if (rp is List) {
          rclonePids = rp.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e > 0).toList();
        } else if (rp is int && rp > 0) {
          rclonePids = [rp];
        }
      }
    } catch (_) {}

    List<String> mainLogs = [];
    List<String> rcloneLogs = [];
    String? lastBackupTime;
    String? lastSyncedFile;
    String? progressTransferred;
    double? progressPercent;
    String? currentSpeed;
    String? currentEta;
    String? xfrCounts;

    try {
      final mainFile = File(mainLogPath);
      if (await mainFile.exists()) {
        mainLogs = await _readLastLines(mainFile, 40);
        for (final line in mainLogs.reversed) {
          if (line.contains('tamamlandi') ||
              line.contains('tamamlandı') ||
              line.contains('esitleniyor') ||
              line.contains('eşitleniyor')) {
            final match = RegExp(r'^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]')
                .firstMatch(line);
            if (match != null) {
              lastBackupTime ??= match.group(1);
            }
          }
        }
      }
    } catch (_) {}

    try {
      final rcloneFile = File(rcloneLogPath);
      if (await rcloneFile.exists()) {
        rcloneLogs = await _readLastLines(rcloneFile, 60);
        // Rclone loglarından son kopyalanan dosyayı ve son ilerleme yüzdesini bul
        final copiedRegex = RegExp(
          r'^(\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2})\s+INFO\s+:\s+(.+?):\s+Copied\b',
        );
        final statsRegex = RegExp(
          r'(\d+(?:\.\d+)?\s+\w+\s*/\s*\d+(?:\.\d+)?\s+\w+),\s*(\d+)%,\s*([^,]+),\s*ETA\s*([^\s(]+)(?:\s*\(([^)]+)\))?',
        );

        for (final line in rcloneLogs.reversed) {
          if (lastSyncedFile == null) {
            final cm = copiedRegex.firstMatch(line);
            if (cm != null) {
              lastBackupTime = cm.group(1)?.replaceAll('/', '-');
              lastSyncedFile = cm.group(2);
            }
          }
          if (progressTransferred == null) {
            final sm = statsRegex.firstMatch(line);
            if (sm != null) {
              progressTransferred = sm.group(1)?.trim();
              final pct = int.tryParse(sm.group(2) ?? '');
              if (pct != null) {
                progressPercent = (pct.clamp(0, 100)) / 100.0;
              }
              currentSpeed = sm.group(3)?.trim();
              currentEta = sm.group(4)?.trim();
              xfrCounts = sm.group(5)?.trim();
            }
          }
          if (lastSyncedFile != null && progressTransferred != null) break;
        }
      }
    } catch (_) {}

    return ProfileRuntimeStatus(
      taskRegistered: taskRegistered,
      taskState: taskState,
      disallowHardTerminate: disallowHardTerminate,
      watcherRunning: watcherRunning,
      watcherPid: watcherPid,
      rcloneRunning: rclonePids.isNotEmpty,
      rclonePids: rclonePids,
      lastBackupTime: lastBackupTime,
      lastSyncedFile: lastSyncedFile,
      progressTransferred: progressTransferred,
      progressPercent: progressPercent,
      currentSpeed: currentSpeed,
      currentEta: currentEta,
      xfrCounts: xfrCounts,
      mainLogs: mainLogs,
      rcloneLogs: rcloneLogs,
    );
  }

  Future<List<String>> _readLastLines(File file, int maxLines) async {
    try {
      final length = await file.length();
      final readSize = length > 65536 ? 65536 : length;
      final raf = await file.open(mode: FileMode.read);
      try {
        await raf.setPosition(length - readSize);
        final bytes = await raf.read(readSize);
        final text = utf8.decode(bytes, allowMalformed: true);
        final lines = text
            .split(RegExp(r'\r?\n'))
            .where((l) => l.trim().isNotEmpty)
            .toList();
        if (lines.length <= maxLines) return lines;
        return lines.sublist(lines.length - maxLines);
      } finally {
        await raf.close();
      }
    } catch (_) {
      return [];
    }
  }
}
