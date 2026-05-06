import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../core/constants.dart';
import '../core/router.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../providers/calendar_provider.dart';
import '../providers/products_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/purchased_today_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _expandedStatus; // 'red' | 'yellow' | 'green' | 'expired'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fcmServiceProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final calendarAsync = ref.watch(calendarProvider((_focusedDay.year, _focusedDay.month)));
    final productsAsync = ref.watch(productsProvider(null));
    final purchasedIds = ref.watch(purchasedTodayProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Builder(builder: (ctx) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: productsAsync.when(
                        data: (products) => _buildChips(products),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    productsAsync.when(
                      data: (products) => _buildCalendar(calendarAsync, products, purchasedIds),
                      loading: () => _buildCalendar(calendarAsync, [], purchasedIds),
                      error: (_, __) => _buildCalendar(calendarAsync, [], purchasedIds),
                    ),
                    if (_expandedStatus != null)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => setState(() => _expandedStatus = null),
                          behavior: HitTestBehavior.opaque,
                          child: Container(color: Colors.black.withValues(alpha: 0.25)),
                        ),
                      ),
                    if (_expandedStatus != null)
                      Positioned(
                        top: 0, left: 0, right: 0,
                        child: productsAsync.when(
                          data: (products) => Material(
                            elevation: 6,
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            child: _buildExpandedSection(products, purchasedIds),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildChips(List<Product> products) {
    final red = products.where((p) => p.status == 'red').toList();
    final yellow = products.where((p) => p.status == 'yellow').toList();
    final green = products.where((p) => p.status == 'green' && p.daysRemaining <= 30).toList();
    final expired = products.where((p) => p.status == 'expired').toList();

    void toggle(String status, List items) {
      if (items.isEmpty) return;
      setState(() => _expandedStatus = _expandedStatus == status ? null : status);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _AlertChip(
            color: AppTheme.statusColor('red'),
            label: '3日以内',
            count: red.length,
            expanded: _expandedStatus == 'red',
            onTap: red.isEmpty ? null : () => toggle('red', red),
          ),
          const SizedBox(width: 6),
          _AlertChip(
            color: AppTheme.statusColor('yellow'),
            label: '1週間以内',
            count: yellow.length,
            expanded: _expandedStatus == 'yellow',
            onTap: yellow.isEmpty ? null : () => toggle('yellow', yellow),
          ),
          const SizedBox(width: 6),
          _AlertChip(
            color: AppTheme.statusColor('green'),
            label: '30日以内',
            count: green.length,
            expanded: _expandedStatus == 'green',
            onTap: green.isEmpty ? null : () => toggle('green', green),
          ),
          if (expired.isNotEmpty) ...[
            const SizedBox(width: 6),
            _AlertChip(
              color: Colors.grey,
              label: '期限切れ',
              count: expired.length,
              expanded: _expandedStatus == 'expired',
              onTap: () => toggle('expired', expired),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpandedSection(List<Product> products, Set<String> purchasedIds) {
    if (_expandedStatus == null) return const SizedBox.shrink();

    final map = {
      'red': products.where((p) => p.status == 'red').toList(),
      'yellow': products.where((p) => p.status == 'yellow').toList(),
      'green': products.where((p) => p.status == 'green' && p.daysRemaining <= 30).toList(),
      'expired': products.where((p) => p.status == 'expired').toList(),
    };

    final items = map[_expandedStatus] ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    final isPurchasable = _expandedStatus == 'red' || _expandedStatus == 'yellow';
    final isDeletable = _expandedStatus == 'expired';
    final color = _expandedStatus == 'expired'
        ? Colors.grey
        : AppTheme.statusColor(_expandedStatus!);

    // Group by genre
    final Map<String, List<Product>> genreMap = {};
    for (final p in items) {
      final key = (p.genre != null && p.genre!.isNotEmpty) ? p.genre! : 'その他';
      genreMap.putIfAbsent(key, () => []).add(p);
    }
    int statusPriority(String s) => s == 'red' || s == 'expired' ? 0 : s == 'yellow' ? 1 : 2;
    final sortedGenres = genreMap.keys.toList()
      ..sort((a, b) {
        final pa = genreMap[a]!.map((p) => statusPriority(p.status)).reduce((x, y) => x < y ? x : y);
        final pb = genreMap[b]!.map((p) => statusPriority(p.status)).reduce((x, y) => x < y ? x : y);
        return pa.compareTo(pb);
      });

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: sortedGenres.map((genre) {
            final genreItems = genreMap[genre]!;
            final dominantStatus = genreItems
                .map((p) => p.status)
                .reduce((a, b) => statusPriority(a) <= statusPriority(b) ? a : b);
            final genreColor = dominantStatus == 'expired'
                ? Colors.grey
                : AppTheme.statusColor(dominantStatus);
            return ExpansionTile(
              leading: Icon(Icons.circle, color: genreColor, size: 14),
              title: Text(genre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${genreItems.length}件', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const Icon(Icons.expand_more),
                ],
              ),
              initiallyExpanded: sortedGenres.length == 1,
              children: genreItems.map((p) {
                final purchased = purchasedIds.contains(p.id);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 6, color: AppTheme.statusColor(p.status)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                            Text(
                              p.daysRemaining >= 0 ? '残り${p.daysRemaining}日' : '期限切れ',
                              style: TextStyle(fontSize: 11, color: AppTheme.statusColor(p.status)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isDeletable)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () async {
                            await ref.read(apiServiceProvider).deleteProduct(p.id);
                            ref.invalidate(productsProvider);
                            ref.invalidate(calendarProvider);
                          },
                        )
                      else if (isPurchasable)
                        SizedBox(
                          width: 68,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purchased ? Colors.grey[300] : Colors.black,
                              foregroundColor: purchased ? Colors.grey[600] : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: purchased
                                ? null
                                : () async {
                                    try {
                                      await ref.read(apiServiceProvider).purchaseProduct(p.id);
                                      await ref.read(purchasedTodayProvider.notifier).add(p.id);
                                      ref.invalidate(productsProvider);
                                      ref.invalidate(calendarProvider);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('エラー: $e')),
                                        );
                                      }
                                    }
                                  },
                            child: Text(
                              purchased ? '購入済み' : '購入完了',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCalendar(AsyncValue<List<CalendarDate>> calendarAsync, List<Product> products, Set<String> purchasedIds) {
    final calendarDates = calendarAsync.valueOrNull ?? [];
    final Map<DateTime, List<CalendarItem>> events = {};
    for (final cd in calendarDates) {
      final key = DateTime(cd.date.year, cd.date.month, cd.date.day);
      events[key] = cd.items;
    }

    final urgent = products.where((p) => p.status == 'red' || p.status == 'yellow').toList();

    return Column(
      children: [
        const Expanded(child: SizedBox()),
        if (urgent.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: urgent.map((p) => _buildUrgentCard(p, purchasedIds)).toList(),
              ),
            ),
          ),
        const Expanded(child: SizedBox()),
        Card(
          margin: EdgeInsets.zero,
          child: TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
            calendarFormat: CalendarFormat.month,
            sixWeekMonthsEnforced: true,
            rowHeight: 58,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: false,
              titleTextFormatter: (date, locale) => '${date.year}年 ${date.month}月',
              leftChevronIcon: const Icon(Icons.chevron_left),
              rightChevronIcon: const Icon(Icons.chevron_right),
            ),
            calendarStyle: const CalendarStyle(outsideDaysVisible: true),
            eventLoader: (day) {
              final key = DateTime(day.year, day.month, day.day);
              return events[key] ?? [];
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (_, day, __) => _calDay(day),
              todayBuilder: (_, day, __) => _calDay(day, fill: Colors.black),
              selectedBuilder: (_, day, __) => _calDay(day, fill: Colors.black.withValues(alpha: 0.7)),
              outsideBuilder: (_, day, __) => _calDay(day, outside: true),
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                final items = events.cast<CalendarItem>();
                final statuses = items.map((e) => e.status).toSet();
                final colors = <Color>[];
                if (statuses.contains('red') || statuses.contains('expired')) {
                  colors.add(AppTheme.statusColor('red'));
                }
                if (statuses.contains('yellow')) {
                  colors.add(AppTheme.statusColor('yellow'));
                }
                if (statuses.contains('green')) {
                  colors.add(AppTheme.statusColor('green'));
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: colors.map((c) => Container(
                    width: 6, height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  )).toList(),
                );
              },
            ),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
              final dates = ref.read(calendarProvider((focused.year, focused.month))).valueOrNull ?? [];
              final items = dates.where((cd) => isSameDay(cd.date, selected)).firstOrNull?.items ?? [];
              _showDayDialog(selected, items);
            },
            onPageChanged: (focused) {
              setState(() {
                _focusedDay = focused;
                _selectedDay = null;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUrgentCard(Product p, Set<String> purchasedIds) {
    final statusColor = AppTheme.statusColor(p.status);
    final purchased = purchasedIds.contains(p.id);

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 76),
            child: Card(
              clipBehavior: Clip.antiAlias,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                              ? Image.network(
                                  AppConstants.proxyImage(p.imageUrl!),
                                  width: 90, height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _urgentPlaceholder(),
                                )
                              : _urgentPlaceholder(),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('${p.daysToConsume}日', style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
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
                            Text(p.genre!, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
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
                            style: TextStyle(fontSize: 13, color: statusColor, fontWeight: FontWeight.w600),
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
            ),
          ),
          SizedBox(
            width: 68,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: purchased ? Colors.grey[300] : Colors.black,
                foregroundColor: purchased ? Colors.grey[600] : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: purchased
                  ? null
                  : () async {
                      try {
                        await ref.read(apiServiceProvider).purchaseProduct(p.id);
                        await ref.read(purchasedTodayProvider.notifier).add(p.id);
                        ref.invalidate(productsProvider);
                        ref.invalidate(calendarProvider);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('エラー: $e')),
                          );
                        }
                      }
                    },
              child: Text(
                purchased ? '購入\n済み' : '購入\n完了',
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

  Widget _urgentPlaceholder() => Container(
    width: 90, height: 120,
    color: Colors.grey[200],
    child: const Icon(Icons.inventory_2, color: Colors.grey, size: 32),
  );

  Widget _calDay(DateTime day, {Color? fill, bool outside = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.12), width: 0.5),
          right: BorderSide(color: Colors.black.withValues(alpha: 0.12), width: 0.5),
        ),
      ),
      child: Center(
        child: fill != null
            ? Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              )
            : Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  color: outside ? Colors.grey[400] : Colors.black87,
                ),
              ),
      ),
    );
  }

  void _showDayDialog(DateTime day, List<CalendarItem> items) {
    final Map<String, List<CalendarItem>> genreMap = {};
    for (final item in items) {
      final key = (item.genre != null && item.genre!.isNotEmpty) ? item.genre! : 'その他';
      genreMap.putIfAbsent(key, () => []).add(item);
    }

    int statusPriority(String s) => s == 'red' || s == 'expired' ? 0 : s == 'yellow' ? 1 : 2;
    final sortedGenres = genreMap.keys.toList()
      ..sort((a, b) {
        final pa = genreMap[a]!.map((i) => statusPriority(i.status)).reduce((x, y) => x < y ? x : y);
        final pb = genreMap[b]!.map((i) => statusPriority(i.status)).reduce((x, y) => x < y ? x : y);
        return pa.compareTo(pb);
      });

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 420, maxWidth: 360),
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${day.month}月${day.day}日',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(height: 12),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('この日の商品はありません', style: TextStyle(color: Colors.grey))),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: sortedGenres.map((genre) {
                      final genreItems = genreMap[genre]!;
                      final dominantStatus = genreItems
                          .map((i) => i.status)
                          .reduce((a, b) => statusPriority(a) <= statusPriority(b) ? a : b);
                      return _buildGenreSection(genre, genreItems, dominantStatus);
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenreSection(String genre, List<CalendarItem> items, String status) {
    final color = AppTheme.statusColor(status);
    return ExpansionTile(
      leading: Icon(Icons.circle, color: color, size: 14),
      title: Text(genre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${items.length}件', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const Icon(Icons.expand_more),
        ],
      ),
      initiallyExpanded: false,
      children: items.map((item) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 16, 4),
        child: Row(
          children: [
            Icon(Icons.circle, size: 6, color: AppTheme.statusColor(item.status)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
}

class _AlertChip extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final bool expanded;
  final VoidCallback? onTap;

  const _AlertChip({
    required this.color,
    required this.label,
    required this.count,
    required this.expanded,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final chipColor = enabled ? color : Colors.grey[400]!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: chipColor, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: chipColor, size: 10),
            const SizedBox(width: 4),
            Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: enabled ? null : Colors.grey[500],
              ),
            ),
            if (enabled) ...[
              const SizedBox(width: 2),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.grey,
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
