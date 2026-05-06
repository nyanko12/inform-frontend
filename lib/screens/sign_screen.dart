import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class SignScreen extends ConsumerStatefulWidget {
  const SignScreen({super.key});

  @override
  ConsumerState<SignScreen> createState() => _SignScreenState();
}

class _SignScreenState extends ConsumerState<SignScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkRedirectResult();
  }

  // リダイレクト後の結果を受け取る（signInWithRedirectのフォールバック時）
  Future<void> _checkRedirectResult() async {
    try {
      final auth = ref.read(authServiceProvider);
      final cred = await auth.getRedirectResult();
      if (cred == null || !mounted) return;
      setState(() => _loading = true);
      final api = ref.read(apiServiceProvider);
      final token = await auth.getIdToken();
      if (token != null) api.setAuthToken(token);
      final user = cred.user;
      if (user != null) await api.register(user.uid, user.email ?? '');
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      // ナビゲーション済みなら mounted = false になるので安全
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _continueWithEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() { _loading = true; _error = null; });
    try {
      final auth = ref.read(authServiceProvider);
      // Attempt sign-in; if fails, create account
      try {
        await auth.signInWithEmail(email, 'placeholder_password');
      } catch (_) {
        await auth.createWithEmail(email, 'placeholder_password');
      }
      final user = auth.currentUser;
      if (user != null) {
        final api = ref.read(apiServiceProvider);
        final token = await auth.getIdToken();
        if (token != null) api.setAuthToken(token);
        await api.register(user.uid, user.email ?? email);
      }
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      final auth = ref.read(authServiceProvider);
      final cred = await auth.signInWithGoogle();
      if (cred != null) {
        final api = ref.read(apiServiceProvider);
        final token = await auth.getIdToken();
        if (token != null) api.setAuthToken(token);
        final user = cred.user;
        if (user != null) await api.register(user.uid, user.email ?? '');
        if (mounted) context.go('/home');
      }
      // cred == null はリダイレクト中（ページ遷移するので何もしない）
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              const Text(
                'お知らせくん',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              const Text(
                'アカウントの作成',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'このアプリに登録するには\nメールアドレスを入力してください',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'email@domain.com'),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _continueWithEmail,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('続行'),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: const [
                  Expanded(child: Divider()),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('または', style: TextStyle(color: Colors.grey))),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('G', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  label: Text(_loading ? 'Googleにリダイレクト中...' : 'Googleで続行'),
                  onPressed: _loading ? null : _signInWithGoogle,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.apple, color: Colors.black),
                  label: const Text('Appleで続行'),
                  onPressed: _loading ? null : () {},
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  '「続行」をクリックすることで、利用規約とプライバシーポリシーに同意したことになります。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
