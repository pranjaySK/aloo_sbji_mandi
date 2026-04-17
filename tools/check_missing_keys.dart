import 'dart:io';

void main() {
  final screens = [
    'lib/screens/admin/admin_ads_screen.dart',
    'lib/screens/admin/admin_home_screen.dart',
    'lib/screens/admin/manage_admins_screen.dart',
    'lib/screens/admin/admin_broadcast_notification_screen.dart',
  ];

  final locFile = File('lib/core/utils/app_localizations.dart');
  final locContent = locFile.readAsStringSync();

  final usedKeys = <String>{};
  final trPattern = RegExp(r"tr\('([^']+)'\)");

  for (final path in screens) {
    final content = File(path).readAsStringSync();
    for (final match in trPattern.allMatches(content)) {
      usedKeys.add(match.group(1)!);
    }
  }

  print('Total unique tr() keys used in admin screens: ${usedKeys.length}');

  final missingKeys = <String>[];
  for (final key in usedKeys.toList()..sort()) {
    // Check if the key exists in the English map (appears as 'key': in loc file)
    if (!locContent.contains("'$key':")) {
      missingKeys.add(key);
    }
  }

  if (missingKeys.isEmpty) {
    print('✅ All keys present!');
  } else {
    print('❌ Missing ${missingKeys.length} keys:');
    for (final k in missingKeys) {
      print('  - $k');
    }
  }
}
