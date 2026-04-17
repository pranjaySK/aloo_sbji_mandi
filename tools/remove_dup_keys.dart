import 'dart:io';

void main() {
  final file = File('lib/core/utils/app_localizations.dart');
  var content = file.readAsStringSync();
  final lines = content.split('\n');

  // Keys that already exist in the maps and are now duplicated in the admin section
  // We'll find lines in admin sections and remove the duplicate ones
  
  // Strategy: For each language map, find the "// ── Admin Screens Localization ──" marker,
  // then for each key after that marker, check if it also appears BEFORE the marker in the same map.
  // If so, remove it from the admin section.

  // First, find all the admin section markers
  final adminMarker = '// ── Admin Screens Localization ──';
  
  // Find all map boundaries
  final mapStartPattern = RegExp(r"static const Map<String, String> _(\w+) = \{");
  
  // Parse each map: find start, admin marker, and end
  final mapStarts = <int>[];
  final mapEnds = <int>[];
  
  for (int i = 0; i < lines.length; i++) {
    if (mapStartPattern.hasMatch(lines[i])) {
      mapStarts.add(i);
    }
  }
  
  // Find end of each map (the `};` line)
  for (final start in mapStarts) {
    int braceDepth = 0;
    bool started = false;
    for (int i = start; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('{')) { braceDepth++; started = true; }
      if (line.contains('}') && started) {
        braceDepth--;
        if (braceDepth == 0) {
          mapEnds.add(i);
          break;
        }
      }
    }
  }
  
  print('Found ${mapStarts.length} language maps');
  
  // For each map, find the admin marker and extract pre-admin keys
  final linesToRemove = <int>{};
  
  for (int m = 0; m < mapStarts.length; m++) {
    final start = mapStarts[m];
    final end = mapEnds[m];
    
    // Find admin marker within this map
    int adminMarkerLine = -1;
    for (int i = start; i <= end; i++) {
      if (lines[i].contains(adminMarker)) {
        adminMarkerLine = i;
        break;
      }
    }
    
    if (adminMarkerLine == -1) continue;
    
    // Extract all keys before admin marker
    final keyPattern = RegExp(r"^\s+'(\w+)':");
    final preAdminKeys = <String>{};
    for (int i = start; i < adminMarkerLine; i++) {
      final match = keyPattern.firstMatch(lines[i]);
      if (match != null) {
        preAdminKeys.add(match.group(1)!);
      }
    }
    
    // Check keys after admin marker for duplicates
    for (int i = adminMarkerLine + 1; i <= end; i++) {
      final match = keyPattern.firstMatch(lines[i]);
      if (match != null) {
        final key = match.group(1)!;
        if (preAdminKeys.contains(key)) {
          linesToRemove.add(i);
        }
      }
    }
  }
  
  print('Removing ${linesToRemove.length} duplicate lines');
  
  // Remove lines in reverse order
  final sortedLines = linesToRemove.toList()..sort((a, b) => b.compareTo(a));
  for (final lineNum in sortedLines) {
    lines.removeAt(lineNum);
  }
  
  file.writeAsStringSync(lines.join('\n'));
  print('✅ Done! Removed duplicate keys from admin sections.');
}
