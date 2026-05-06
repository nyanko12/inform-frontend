import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants.dart';
import '../models/product.dart';

class ApiService {
  late final Dio _dio;

  ApiService({String? baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  void setAuthToken(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  void setDevUserId(String userId) {
    _dio.options.headers['X-Dev-User-ID'] = userId;
  }

  // Auth
  Future<String> register(String firebaseUid, String email) async {
    final res = await _dio.post('/auth/register', data: {
      'firebase_uid': firebaseUid,
      'email': email,
    });
    return res.data['user_id'] as String;
  }

  // Products
  Future<List<Product>> getProducts({String? keyword}) async {
    final res = await _dio.get('/products', queryParameters: {
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
    });
    final list = res.data['products'] as List<dynamic>;
    return list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> createProduct({
    required String name,
    required int daysToConsume,
    String? itemCode,
    String? genre,
    String? imageUrl,
    double? contentVolume,
    String? contentUnit,
  }) async {
    final res = await _dio.post('/products', data: {
      'name': name,
      'days_to_consume': daysToConsume,
      if (itemCode != null) 'item_code': itemCode,
      if (genre != null) 'genre': genre,
      if (imageUrl != null) 'image_url': imageUrl,
      if (contentVolume != null) 'content_volume': contentVolume,
      if (contentUnit != null) 'content_unit': contentUnit,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteProduct(String productId) async {
    await _dio.delete('/products/$productId');
  }

  Future<void> updateProductDays(String productId, int daysToConsume) async {
    await _dio.patch('/products/$productId/days', data: {'days_to_consume': daysToConsume});
  }

  Future<String> purchaseProduct(String productId) async {
    final res = await _dio.post('/products/$productId/purchase');
    return res.data['new_due_date'] as String;
  }

  Future<Map<String, dynamic>> calculateDays({
    required String genre,
    required double contentVolume,
    required String contentUnit,
    required int numPeople,
    double? dailyUsagePerPerson,
  }) async {
    final body = <String, dynamic>{
      'genre': genre,
      'content_volume': contentVolume,
      'content_unit': contentUnit,
      'num_people': numPeople,
    };
    if (dailyUsagePerPerson != null) {
      body['daily_usage_per_person'] = dailyUsagePerPerson;
    }
    final res = await _dio.post('/products/calculate-days', data: body);
    return res.data as Map<String, dynamic>;
  }

  // Search
  Future<Map<String, dynamic>> searchItems(String keyword, {int page = 1, int hits = 10}) async {
    final res = await _dio.get('/items/search', queryParameters: {
      'keyword': keyword,
      'page': page,
      'hits': hits,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> searchByBarcode(String janCode) async {
    final res = await _dio.get('/items/barcode', queryParameters: {'jan_code': janCode});
    return res.data as Map<String, dynamic>;
  }

  // Calendar
  Future<List<CalendarDate>> getCalendar(int year, int month) async {
    final res = await _dio.get('/calendar', queryParameters: {'year': year, 'month': month});
    final list = res.data['dates'] as List<dynamic>? ?? [];
    return list.map((e) => CalendarDate.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Settings
  Future<void> updateFcmToken(String token) async {
    await _dio.put('/fcm-token', data: {'fcm_token': token});
  }

  Future<void> updateSettings(int notificationDaysBefore) async {
    await _dio.put('/settings', data: {'notification_days_before': notificationDaysBefore});
  }

  Future<void> deleteExpiredProducts() async {
    await _dio.delete('/settings/products/expired');
  }
}
