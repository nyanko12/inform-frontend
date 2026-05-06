import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/router.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/products_provider.dart';
import '../services/api_service.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final has = _searchController.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;
    FocusScope.of(context).unfocus();
    ref.read(searchResultProvider.notifier).search(keyword);
  }

  void _showRegisterDialog(SearchItem item) {
    showDialog(
      context: context,
      builder: (_) => _RegisterDialog(
        item: item,
        api: ref.read(apiServiceProvider),
        onSuccess: () {
          ref.invalidate(productsProvider);
          ref.invalidate(calendarProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('登録しました')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchResultProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(builder: (ctx) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: '検索',
                        contentPadding: EdgeInsets.symmetric(vertical: 0),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _onSearch(),
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasText ? Colors.black : Colors.grey[300],
                        foregroundColor: _hasText ? Colors.white : Colors.grey[500],
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _hasText ? _onSearch : null,
                      child: const Text('検索', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'スキャン',
                    onPressed: () => context.push('/scan'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
            )),
            Expanded(
              child: searchState.when(
                data: (state) => _buildResults(state),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('エラー: $e')),
              ),
            ),
            searchState.when(
              data: (state) => state.allItems.isEmpty ? const SizedBox.shrink() : _buildPagination(state),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(SearchState state) {
    if (state.items.isEmpty) {
      return const Center(child: Text('商品を検索してください', style: TextStyle(color: Colors.grey)));
    }
    return Scrollbar(
      controller: _scrollController,
      child: GridView.builder(
        key: ValueKey('${state.keyword}-${state.page}-${state.pageSize}'),
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: state.items.length,
        itemBuilder: (_, i) => _buildItemCard(state.items[i]),
      ),
    );
  }

  Widget _buildItemCard(SearchItem item) {
    return GestureDetector(
      onTap: () => _showRegisterDialog(item),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: item.imageUrl.isNotEmpty
                  ? Image.network(
                      AppConstants.proxyImage(item.imageUrl),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        width: double.infinity,
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      width: double.infinity,
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      item.contentVolume > 0
                          ? '${item.genre} / ${item.contentVolume.toStringAsFixed(0)}${item.contentUnit}'
                          : '${item.genre} / 無記入',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      height: 26,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                        ),
                        onPressed: () => _showRegisterDialog(item),
                        child: const Text('登録', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(SearchState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 1; i <= state.pageCount && i <= 3; i++)
                    _PageButton(page: i, current: state.page, onTap: () {
                      ref.read(searchResultProvider.notifier).changePage(i);
                    }),
                  if (state.pageCount > 6) ...[
                    const Text('...', style: TextStyle(color: Colors.grey)),
                    for (int i = state.pageCount - 2; i <= state.pageCount; i++)
                      _PageButton(page: i, current: state.page, onTap: () {
                        ref.read(searchResultProvider.notifier).changePage(i);
                      }),
                  ] else if (state.pageCount > 3) ...[
                    for (int i = 4; i <= state.pageCount; i++)
                      _PageButton(page: i, current: state.page, onTap: () {
                        ref.read(searchResultProvider.notifier).changePage(i);
                      }),
                  ],
                ],
              ),
            ),
          ),
          for (final h in [10, 20, 30])
            GestureDetector(
              onTap: () => ref.read(searchResultProvider.notifier).changePageSize(h),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('$h', style: TextStyle(
                  fontWeight: state.pageSize == h ? FontWeight.bold : FontWeight.normal,
                  decoration: state.pageSize == h ? TextDecoration.underline : null,
                )),
              ),
            ),
        ],
      ),
    );
  }
}

class _RegisterDialog extends StatefulWidget {
  final SearchItem item;
  final ApiService api;
  final VoidCallback onSuccess;

  const _RegisterDialog({required this.item, required this.api, required this.onSuccess});

  @override
  State<_RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<_RegisterDialog> {
  bool _showOmakase = false;
  bool _genreNotFound = false;
  int? _calculatedDays;
  final _daysController = TextEditingController();
  final _peopleController = TextEditingController();
  final _volumeController = TextEditingController();
  final _dailyUsageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.item.contentVolume > 0) {
      _volumeController.text = widget.item.contentVolume.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _daysController.dispose();
    _peopleController.dispose();
    _volumeController.dispose();
    _dailyUsageController.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    final people = int.tryParse(_peopleController.text.trim()) ?? 1;
    final volume = double.tryParse(_volumeController.text.trim()) ?? 0;
    if (volume == 0) return;

    final dailyUsage = _genreNotFound
        ? double.tryParse(_dailyUsageController.text.trim())
        : null;
    if (_genreNotFound && (dailyUsage == null || dailyUsage <= 0)) return;

    try {
      final result = await widget.api.calculateDays(
        genre: widget.item.genre,
        contentVolume: volume,
        contentUnit: widget.item.contentUnit.isNotEmpty ? widget.item.contentUnit : 'ml',
        numPeople: people,
        dailyUsagePerPerson: dailyUsage,
      );
      if (result['genre_not_found'] == true) {
        setState(() => _genreNotFound = true);
        return;
      }
      setState(() {
        _calculatedDays = result['days_to_consume'] as int?;
        _daysController.text = '${_calculatedDays ?? ''}';
        _genreNotFound = false;
        _showOmakase = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('計算エラー: $e')));
    }
  }

  Future<void> _register() async {
    final days = int.tryParse(_daysController.text.trim());
    if (days == null || days < 1) return;
    try {
      await widget.api.createProduct(
        name: widget.item.name,
        daysToConsume: days,
        itemCode: widget.item.itemCode,
        genre: widget.item.genre,
        imageUrl: widget.item.imageUrl,
        contentVolume: widget.item.contentVolume,
        contentUnit: widget.item.contentUnit,
      );
      if (mounted) Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登録エラー: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = int.tryParse(_daysController.text.trim());
    final canRegister = days != null && days > 0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product header
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: widget.item.imageUrl.isNotEmpty
                        ? Image.network(
                            AppConstants.proxyImage(widget.item.imageUrl),
                            width: 52, height: 52, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(width: 52, height: 52, color: Colors.grey[200], child: const Icon(Icons.image, color: Colors.grey)),
                          )
                        : Container(width: 52, height: 52, color: Colors.grey[200], child: const Icon(Icons.inventory_2, color: Colors.grey)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.item.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text(
                          widget.item.contentVolume > 0
                              ? '${widget.item.genre} / ${widget.item.contentVolume.toStringAsFixed(0)}${widget.item.contentUnit}'
                              : '${widget.item.genre} / 無記入',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(height: 20),
              // Form
              if (!_showOmakase) ...[
                const Text('使い切るまでの日数', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _daysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '日数を入力',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => setState(() => _showOmakase = true),
                      child: const Text('おまかせ'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: canRegister ? _register : null,
                      child: const Text('登録'),
                    ),
                  ],
                ),
              ] else ...[
                const Text('おまかせ計算', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _peopleController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '人数を入力',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _volumeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '内容量を入力',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_genreNotFound) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '「${widget.item.genre}」は未登録のジャンルです。\n1人あたりの1日使用量を入力すると登録されます。',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _dailyUsageController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '1人あたりの1日使用量',
                      suffixText: widget.item.contentUnit.isNotEmpty ? widget.item.contentUnit : 'ml',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                if (_calculatedDays != null) ...[
                  const SizedBox(height: 8),
                  Text('消費日数: $_calculatedDays 日',
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _showOmakase = false;
                        _genreNotFound = false;
                      }),
                      child: const Text('戻る'),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton(onPressed: _calculate, child: const Text('計算')),
                    if (_calculatedDays != null) ...[
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: _register, child: const Text('登録')),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final int page;
  final int current;
  final VoidCallback onTap;

  const _PageButton({required this.page, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text('$page', style: TextStyle(
          fontWeight: page == current ? FontWeight.bold : FontWeight.normal,
          decoration: page == current ? TextDecoration.underline : null,
        )),
      ),
    );
  }
}
