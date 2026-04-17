import 'dart:io';

void main() {
  final file = File('lib/core/utils/app_localizations.dart');
  var content = file.readAsStringSync();
  
  // Find where the maps start
  final startIndex = content.indexOf('// ═══════════════════════════════════════════════════════════════');
  
  // Find where the class ends
  final endIndex = content.indexOf('/// Shorthand function for easy access throughout the app');
  
  // Extract just the maps part
  var mapsContent = content.substring(startIndex, endIndex);

  // Close the class properly
  mapsContent = mapsContent.trimRight();
  if (mapsContent.endsWith('}')) {
    mapsContent = mapsContent.substring(0, mapsContent.length - 1);
  }

  // Construct valid dart file
  var newContent = "import 'dart:convert';\nimport 'dart:io';\n\nclass AppLocalizations {\n";
  
  // Create allTranslations map explicitly
  newContent += '''
  static const Map<String, Map<String, String>> allTranslations = {
    'en': _en, 'hi': _hi, 'pa': _pa, 'gu': _gu, 'mr': _mr, 
    'bn': _bn, 'ta': _ta, 'te': _te, 'kn': _kn, 'or': _or,
  };
''';

  newContent += mapsContent;
  newContent += "}\n";
  
  newContent += '''
  
void main() {
  final outDir = Directory('lib/l10n');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }
  
  final regex = RegExp(r'\\{([a-zA-Z0-9_]+)\\}');
  
  AppLocalizations.allTranslations.forEach((locale, translations) {
    final Map<String, dynamic> arb = {};
    arb['@@locale'] = locale;
    
    translations.forEach((key, value) {
      arb[key] = value;
      
      // Only add metadata in the English (template) file
      if (locale == 'en') {
        final matches = regex.allMatches(value);
        if (matches.isNotEmpty) {
          final placeholders = {};
          for (final match in matches) {
            placeholders[match.group(1)!] = {
              "type": "String"
            };
          }
          arb['@\$key'] = {
            "placeholders": placeholders
          };
        }
      }
    });
    
    final file = File('lib/l10n/app_\$locale.arb');
    final encoder = JsonEncoder.withIndent('  ');
    file.writeAsStringSync(encoder.convert(arb));
    print('Generated \$locale');
  });
}
''';

  File('extractor.dart').writeAsStringSync(newContent);
}
