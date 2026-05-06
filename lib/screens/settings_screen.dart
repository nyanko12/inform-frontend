import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/router.dart';
import '../providers/auth_provider.dart';
import '../providers/purchased_today_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double _notificationDays = 7;
  bool _saving = false;

  Future<void> _saveNotificationDays() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateSettings(_notificationDays.round());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存しました')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteExpired() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('期限切れ商品の一括削除'),
        content: const Text('期限切れの商品をすべて削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );
    if (confirmed != true) return;
    final api = ref.read(apiServiceProvider);
    await api.deleteExpiredProducts();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除しました')));
  }

  Future<void> _signOut() async {
    await ref.read(purchasedTodayProvider.notifier).clear();
    final auth = ref.read(authServiceProvider);
    await auth.signOut();
    if (mounted) context.go('/sign');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Builder(builder: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
              const Text('設定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 24),

            // Notification days
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('通知日程の変更', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('${_notificationDays.round()}日前から通知', style: const TextStyle(color: Colors.grey)),
                  Slider(
                    value: _notificationDays,
                    min: 1,
                    max: 14,
                    divisions: 13,
                    label: '${_notificationDays.round()}日前',
                    activeColor: Colors.black,
                    onChanged: (v) => setState(() => _notificationDays = v),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('1日前', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const Text('14日前', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveNotificationDays,
                      child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('保存'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),

            // Delete expired
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _deleteExpired,
                  child: const Text('期限切れ商品を一括削除'),
                ),
              ),
            ),

            const Divider(),

            // Current account
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ログイン中のアカウント', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  ref.watch(authStateProvider).when(
                    data: (user) => Row(
                      children: [
                        () {
                          final photoUrl = user?.photoURL;
                          if (photoUrl != null && photoUrl.isNotEmpty) {
                            return CircleAvatar(radius: 18, backgroundImage: NetworkImage(photoUrl));
                          }
                          return const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.black12,
                            child: Icon(Icons.person, size: 20, color: Colors.black54),
                          );
                        }(),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (user?.displayName != null && user!.displayName!.isNotEmpty)
                                Text(user.displayName!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(
                                user?.email ?? '(メールアドレスなし)',
                                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    loading: () => const SizedBox(height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Sign out
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _signOut,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  child: const Text('ログアウト'),
                ),
              ),
            ),
          ],
        )),
      ),
    );
  }
}
