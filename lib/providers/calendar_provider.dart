import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import 'auth_provider.dart';

final selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final calendarProvider = FutureProvider.family<List<CalendarDate>, (int, int)>((ref, args) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final api = ref.watch(apiServiceProvider);
  final (year, month) = args;
  return api.getCalendar(year, month);
});

final selectedDateProvider = StateProvider<DateTime?>((ref) => null);
