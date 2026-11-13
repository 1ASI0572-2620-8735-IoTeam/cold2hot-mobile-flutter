import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String renderUrl = 'https://cold2hot-backend.onrender.com/api/v1';
  static const String webLocalUrl = 'http://localhost:8080/api/v1';
  static const String androidEmulatorUrl = 'http://10.0.2.2:8080/api/v1';

  static String get defaultBaseUrl {
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host == 'localhost' || host == '127.0.0.1') {
        return webLocalUrl;
      }
      return renderUrl;
    }
    return renderUrl;
  }
}
