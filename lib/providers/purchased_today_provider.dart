import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchasedTodayNotifier extends StateNotifier<Set<String>> {
  PurchasedTodayNotifier() : super({}) {
    _load();
  }

  String get _today => DateTime.now().toIso8601String().substring(0, 10);
  String get _key => 'purchased_today_$_today';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? [];
    state = {...state, ...ids};
  }

  Future<void> add(String id) async {
    state = {...state, id};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.toList());
  }

  Future<void> clear() async {
    state = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  bool contains(String id) => state.contains(id);
}

final purchasedTodayProvider =
    StateNotifierProvider<PurchasedTodayNotifier, Set<String>>(
  (ref) => PurchasedTodayNotifier(),
);
