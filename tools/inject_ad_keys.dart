import 'dart:io';

void main() {
  final file = File('lib/core/utils/app_localizations.dart');
  var content = file.readAsStringSync();
  final lines = content.split('\n');

  final newKeys = {
    'en': {
      'pending_ads': 'Pending Ads',
      'total_ads': 'Total Ads',
    },
    'hi': {
      'pending_ads': 'लंबित विज्ञापन',
      'total_ads': 'कुल विज्ञापन',
    },
    'pa': {
      'pending_ads': 'ਲੰਬਿਤ ਇਸ਼ਤਿਹਾਰ',
      'total_ads': 'ਕੁੱਲ ਇਸ਼ਤਿਹਾਰ',
    },
    'gu': {
      'pending_ads': 'બાકી જાહેરાતો',
      'total_ads': 'કુલ જાહેરાતો',
    },
    'mr': {
      'pending_ads': 'प्रलंबित जाहिराती',
      'total_ads': 'एकूण जाहिराती',
    },
    'bn': {
      'pending_ads': 'অমীমাংসিত বিজ্ঞাপন',
      'total_ads': 'মোট বিজ্ঞাপন',
    },
    'ta': {
      'pending_ads': 'நிலுவையில் உள்ள விளம்பரங்கள்',
      'total_ads': 'மொத்த விளம்பரங்கள்',
    },
    'te': {
      'pending_ads': 'పెండింగ్ ప్రకటనలు',
      'total_ads': 'మొత్తం ప్రకటనలు',
    },
    'kn': {
      'pending_ads': 'ಬಾಕಿಯಿರುವ ಜಾಹೀರಾತುಗಳು',
      'total_ads': 'ಒಟ್ಟು ಜಾಹೀರಾತುಗಳು',
    },
    'or': {
      'pending_ads': 'ବିଚାରାଧୀନ ବିଜ୍ଞାପନ',
      'total_ads': 'ମୋଟ ବିଜ୍ଞାପନ',
    },
  };

  final locales = ['en', 'hi', 'pa', 'gu', 'mr', 'bn', 'ta', 'te', 'kn', 'or'];

  // Look for the start of each locale dict
  for (int m = locales.length - 1; m >= 0; m--) {
    final locale = locales[m];
    // Find where the map ends for this locale
    final pattern = RegExp(r"static const Map<String, String> _" + locale + r" = \{");
    
    int mapStart = -1;
    for (int i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i])) {
        mapStart = i;
        break;
      }
    }
    
    if (mapStart != -1) {
      int mapEnd = -1;
      int depth = 0;
      bool started = false;
      for (int i = mapStart; i < lines.length; i++) {
        if (lines[i].contains('{')) { depth++; started = true; }
        if (lines[i].contains('}')) { 
           depth--; 
           if (depth == 0 && started) {
             mapEnd = i;
             break;
           }
        }
      }
      
      if (mapEnd != -1) {
        // Insert right before the closing brace
        // Check if they are already there so we don't duplicate
        bool hasPending = false;
        bool hasTotal = false;
        
        for (int i = mapStart; i < mapEnd; i++) {
          if (lines[i].contains("'pending_ads':")) hasPending = true;
          if (lines[i].contains("'total_ads':")) hasTotal = true;
        }
        
        if (hasPending && hasTotal) {
           // We'll replace the existing ones
           for (int i = mapStart; i < mapEnd; i++) {
             if (lines[i].contains("'pending_ads':")) {
               lines[i] = "    'pending_ads': '''${newKeys[locale]!['pending_ads']}''',";
             }
             if (lines[i].contains("'total_ads':")) {
               lines[i] = "    'total_ads': '''${newKeys[locale]!['total_ads']}''',";
             }
           }
        } else {
           // Just append them before mapEnd
           final buf = StringBuffer();
           if (!hasPending) buf.writeln("    'pending_ads': '''${newKeys[locale]!['pending_ads']}''',");
           if (!hasTotal) buf.writeln("    'total_ads': '''${newKeys[locale]!['total_ads']}''',");
           lines.insert(mapEnd, buf.toString().trimRight());
        }
      }
    }
  }

  file.writeAsStringSync(lines.join('\n'));
  print('✅ Injected pending_ads and total_ads overrides/additions successfully.');
}
