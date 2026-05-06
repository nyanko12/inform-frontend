import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

final productsProvider = FutureProvider.family<List<Product>, String?>((ref, keyword) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final api = ref.watch(apiServiceProvider);
  return api.getProducts(keyword: keyword);
});

final searchResultProvider = StateNotifierProvider.autoDispose<SearchNotifier, AsyncValue<SearchState>>((ref) {
  final api = ref.watch(apiServiceProvider);
  return SearchNotifier(api);
});

class SearchState {
  final List<SearchItem> allItems;
  final int page;
  final int pageSize;
  final String keyword;

  const SearchState({
    this.allItems = const [],
    this.page = 1,
    this.pageSize = 10,
    this.keyword = '',
  });

  List<SearchItem> get items {
    if (allItems.isEmpty) return const [];
    final start = (page - 1) * pageSize;
    return allItems.skip(start).take(pageSize).toList();
  }

  int get pageCount => pageSize > 0 ? ((allItems.length + pageSize - 1) ~/ pageSize) : 0;
  int get totalCount => allItems.length;

  SearchState copyWith({
    List<SearchItem>? allItems,
    int? page,
    int? pageSize,
    String? keyword,
  }) =>
      SearchState(
        allItems: allItems ?? this.allItems,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        keyword: keyword ?? this.keyword,
      );
}

class SearchNotifier extends StateNotifier<AsyncValue<SearchState>> {
  final ApiService _api;

  SearchNotifier(this._api) : super(const AsyncValue.data(SearchState()));

  Future<void> search(String keyword, {int pageSize = 10}) async {
    final current = state.valueOrNull;
    // Same keyword: don't re-fetch, keep items
    if (current != null && current.keyword == keyword && current.allItems.isNotEmpty) {
      state = AsyncValue.data(current.copyWith(page: 1, pageSize: pageSize));
      return;
    }
    state = const AsyncValue.loading();
    try {
      final data = await _api.searchItems(keyword, hits: 100);
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => SearchItem.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(SearchState(
        allItems: items,
        page: 1,
        pageSize: pageSize,
        keyword: keyword,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void changePage(int page) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(page: page));
  }

  void changePageSize(int pageSize) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(page: 1, pageSize: pageSize));
  }

  void reset() {
    state = const AsyncValue.data(SearchState());
  }

  Future<void> searchByBarcode(String janCode) async {
    state = const AsyncValue.loading();
    try {
      final data = await _api.searchByBarcode(janCode);
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => SearchItem.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(SearchState(
        allItems: items,
        page: 1,
        pageSize: 10,
        keyword: janCode,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
