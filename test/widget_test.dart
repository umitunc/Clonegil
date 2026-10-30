import 'package:flutter_test/flutter_test.dart';
import 'package:clonegil/models/sync_profile.dart';
import 'package:clonegil/services/rclone_service.dart';

void main() {
  test('SyncProfile serialization and ASCII-safe PowerShell encoding', () {
    const profile = SyncProfile(
      id: 'muzik_calismalarim',
      name: 'Müzik Çalışmalarım',
      localPath: r'D:\Müzik Çalışmalarım',
      remoteName: 'gdrive',
      remotePath: 'Müzik Çalışmalarım',
      taskName: 'MuzikCalismalarim_GDrive_AutoSync',
      logDir: r'C:\Users\umitu\AppData\Local\RcloneMuzikSync',
    );

    final json = profile.toJson();
    final restored = SyncProfile.fromJson(json);
    expect(restored.name, 'Müzik Çalışmalarım');
    expect(restored.fullRemoteSpec, 'gdrive:Müzik Çalışmalarım');

    final safe = RcloneService.toPowerShellAsciiSafeString(
      'Müzik Çalışmalarım',
    );
    expect(safe.contains(r'$([char]0x00FC)'), isTrue);
    expect(safe.contains(r'$([char]0x00C7)'), isTrue);
    expect(safe.contains(r'$([char]0x0131)'), isTrue);
    expect(safe.contains(r'$([char]0x015F)'), isTrue);
  });
}
