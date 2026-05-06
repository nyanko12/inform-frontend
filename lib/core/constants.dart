class AppConstants {
  static const String baseUrl = 'https://backend-production-86a7.up.railway.app/api/v1';
  static const String imageProxyBase = 'https://backend-production-86a7.up.railway.app/api/v1/image-proxy?url=';
  static const int defaultNotificationDaysBefore = 7;

  static String proxyImage(String url) {
    if (url.isEmpty) return '';
    return '$imageProxyBase${Uri.encodeComponent(url)}';
  }
}
