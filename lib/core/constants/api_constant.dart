import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl => kIsWeb
      ? dotenv.get('BASE_URL_WEB', fallback: "http://localhost:8888")
      : dotenv.get('BASE_URL_MOBILE', fallback: "http://15.206.172.102:8888");
}
