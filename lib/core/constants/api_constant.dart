import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  static const String baseUrl = kIsWeb
      ? "http://localhost:8888"
      : "http://15.206.172.102:8888"; //pradeep http://15.206.172.102:8888
      // : "http://72.62.226.160"; //original

      
  // Remote: "http://72.62.226.160" (port 80);
  // Local dev (emulator): "http://10.0.2.2:8888";
  // Local dev (web/chrome): "http://localhost:8888";
  // Local dev (phone on same WiFi): "http://192.168.1.42:8888";
}
