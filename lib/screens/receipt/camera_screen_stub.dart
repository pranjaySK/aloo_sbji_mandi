// Stub file for non-web platforms
import 'package:flutter/material.dart';

import '../../core/utils/app_localizations.dart';

/// A stub widget that returns an empty screen
/// This is used when the web camera screen is imported on non-web platforms
class WebCameraScreen extends StatelessWidget {
  const WebCameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // This screen should never be reached on mobile
    // because the parent checks for kIsWeb before navigating here
    return Scaffold(
      appBar: AppBar(title: Text(tr('camera'))),
      body: Center(child: Text(tr('camera_not_available'))),
    );
  }
}
