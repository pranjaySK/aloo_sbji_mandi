import 'dart:io';

void main() {
  final file = File('lib/core/utils/app_localizations.dart');
  var content = file.readAsStringSync();
  final lines = content.split('\n');

  final locales = ['en', 'hi', 'pa', 'gu', 'mr', 'bn', 'ta', 'te', 'kn', 'or'];

  final missingKeys = {
    'all': 'All',
    'reject': 'Reject',
    'not_available': 'N/A',
  };

  // Find where the admin section is for each language and append the missing keys.
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('// ── Admin Screens Localization ──')) {
      // found an admin section. Let's insert the missing keys right after it.
      int insertIndex = i + 1;
      
      final buf = StringBuffer();
      for (final entry in missingKeys.entries) {
        buf.writeln("    '${entry.key}': '''${entry.value}''',");
      }
      
      lines.insert(insertIndex, buf.toString().trimRight());
      // Skip the inserted lines
      i++; 
    }
  }

  file.writeAsStringSync(lines.join('\n'));
  print('✅ Inserted missing keys.');
}
