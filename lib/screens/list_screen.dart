import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/router.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/products_provider.dart';
import '../providers/purchased_today_provider.dart';

class ListScreen extends ConsumerStatefulWidget {
  const ListScreen({super.key});

  @override
  ConsumerState<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends ConsumerState<ListScreen> {
  final _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _purchase(String productId, String name) async {
    try {
      final api = ref.read(apiServiceProvider);
      final newDueDate = await api.purchaseProduct(productId);
      await ref.read(purchasedTodayProvider.notifier).add(productId);
      ref.invalidate(productsProvider);
      ref.invalidate(calendarProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「$name」次回期日: $newDueDate'), duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('購入エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _delete(String productId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('「$name」を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(apiServiceProvider).deleteProduct(productId);
    ref.invalidate(productsProvider);
    ref.invalidate(calendarProvider);
  }

  Future<void> _showEditDaysDialog(Product p) async {
    final controller = TextEditingController(text: '${p.daysToConsume}');
    final newDays = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('使い切るまでの日数を変更'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '変更すると期日が本日から再計算されます',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '日数',
                suffixText: '日',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () {
              final d = int.tryParse(controller.text.trim());
              if (d != null && d > 0) Navigator.pop(ctx, d);
            },
            child: const Text('変更'),
          ),
        ],
      ),
    );
    if (newDays != null && mounted) {
      try {
        await ref.read(apiServiceProvider).updateProductDays(p.id, newDays);
        ref.invalidate(productsProvider);
        ref.invalidate(calendarProvider);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(_keyword.isEmpty ? null : _keyword));

    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(builder: (ctx) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        hintText: '検索欄',
                        contentPadding: EdgeInsets.symmetric(vertical: 0),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _keyword = v),
                    ),
                  ),
                ],
              ),
            )),
            Expanded(
              child: productsAsync.when(
                data: (products) => products.isEmpty
                    ? const Center(child: Text('登録商品がありません', style: TextStyle(color: Colors.grey)))
                    : Scrollbar(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: products.length,
                          itemBuilder: (_, i) => _buildProductCard(products[i]),
                        ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('エラー: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product p) {
    final alreadyPurchased = ref.watch(purchasedTodayProvider).contains(p.id);
    final statusColor = AppTheme.statusColor(p.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 76),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 40, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 左: 写真 + 日数バッジ
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                                  ? Image.network(
                                      AppConstants.proxyImage(p.imageUrl!),
                                      width: 90, height: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                                    )
                                  : _imagePlaceholder(),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _showEditDaysDialog(p),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${p.daysToConsume}日', style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 3),
                                    const Icon(Icons.edit, size: 11, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // 右: 名前・ジャンル・内容量・残り日数
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (p.genre != null && p.genre!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  p.genre!,
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ],
                              if (p.contentVolume != null && p.contentVolume! > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _formatVolume(p.contentVolume!, p.contentUnit ?? ''),
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Text(
                                p.daysRemaining >= 0 ? '残り${p.daysRemaining}日' : '期限切れ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p.nextDueDate.replaceAll('-', '/'),
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _delete(p.id, p.name),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 68,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: alreadyPurchased ? Colors.grey[300] : Colors.black,
                foregroundColor: alreadyPurchased ? Colors.grey[600] : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: alreadyPurchased ? null : () => _purchase(p.id, p.name),
              child: Text(
                alreadyPurchased ? '購入\n済み' : '購入\n完了',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatVolume(double v, String unit) {
    final s = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    return '$s$unit';
  }

  Widget _imagePlaceholder() => Container(
    width: 90, height: 120,
    color: Colors.grey[200],
    child: const Icon(Icons.inventory_2, color: Colors.grey, size: 32),
  );

}
