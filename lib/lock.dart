import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// UYGULAMA KİLİDİ: kişinin kendi belirlediği şifre
//  - Uygulama açılırken ve arka plandan 5 saniyeden uzun kaldıktan sonra
//    dönünce bu ekran tüm uygulamanın üstünde açılır (main.dart tetikler)
//  - Her 5 yanlış denemede 30 saniye beklenir
//  - 3 yanlıştan sonra, yazıldıysa, şifre ipucu gösterilir
//  - Geri tuşu uygulamadan çıkar
// Şifre düz yazı olarak değil, tuzlu SHA-256 özeti olarak saklanır.
// ---------------------------------------------------------------
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _c = TextEditingController();
  bool _hide = true;
  int _wrong = 0;
  String? _err;
  DateTime? _until; // bekleme bitiş zamanı
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  int get _waitSeconds {
    final u = _until;
    if (u == null) return 0;
    final s = u.difference(DateTime.now()).inSeconds + 1;
    return s > 0 ? s : 0;
  }

  void _submit() {
    if (_waitSeconds > 0) return;
    if (store.checkPassword(_c.text)) {
      store.unlock();
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _wrong++;
      _err = tx('Şifre yanlış');
      _c.clear();
      if (_wrong % 5 == 0) {
        // Her 5 yanlışta 30 saniye beklet
        _until = DateTime.now().add(const Duration(seconds: 30));
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) return;
          if (_waitSeconds == 0) {
            t.cancel();
            setState(() => _until = null);
          } else {
            setState(() {});
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final wait = _waitSeconds;
    return PopScope(
      canPop: false,
      // Kilit ekranında geri tuşu uygulamadan çıkar
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration:
                        BoxDecoration(color: p.accent, shape: BoxShape.circle),
                    child: Icon(Icons.lock_rounded, size: 34, color: p.onAccent),
                  ),
                  const SizedBox(height: 16),
                  Text('Your Book',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: p.ink)),
                  const SizedBox(height: 4),
                  Text(tx('Uygulama kilitli'),
                      style: TextStyle(color: p.soft)),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _c,
                    autofocus: true,
                    obscureText: _hide,
                    enabled: wait == 0,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: tx('Şifre'),
                      errorText: _err,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_hide
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                  ),
                  // 3 yanlış denemeden sonra şifre ipucu
                  if (_wrong >= 3 && store.lockHint.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(tx('İpucu: {0}', [store.lockHint]),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.soft, height: 1.35)),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: wait == 0 ? _submit : null,
                      child: Text(wait == 0
                          ? tx('Aç')
                          : tx('{0} sn bekle', [wait])),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// ŞİFRE BELİRLE penceresi: yeni şifre iki kez + isteğe bağlı ipucu
// ---------------------------------------------------------------
class PasswordResult {
  final String password;
  final String hint;
  PasswordResult(this.password, this.hint);
}

Future<PasswordResult?> askNewPassword(BuildContext context) {
  return showDialog<PasswordResult>(
    context: context,
    builder: (_) => const _NewPasswordDialog(),
  );
}

class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog();

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  final _h = TextEditingController();
  bool _hide = true;
  String? _err;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _h.dispose();
    super.dispose();
  }

  void _ok() {
    if (_a.text.length < 4) {
      setState(() => _err = tx('Şifre en az 4 karakter olmalı'));
      return;
    }
    if (_a.text != _b.text) {
      setState(() => _err = tx('Şifreler aynı değil'));
      return;
    }
    Navigator.pop(context, PasswordResult(_a.text, _h.text));
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return AlertDialog(
      title: Text(tx('Şifreni belirle')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _a,
              autofocus: true,
              obscureText: _hide,
              decoration: InputDecoration(
                labelText: tx('Yeni şifre'),
                suffixIcon: IconButton(
                  icon: Icon(_hide
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _b,
              obscureText: _hide,
              decoration: InputDecoration(labelText: tx('Şifreyi tekrar yaz')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _h,
              decoration:
                  InputDecoration(labelText: tx('Şifre ipucu (isteğe bağlı)')),
            ),
            const SizedBox(height: 12),
            Text(
              tx('Şifreni unutursan sıfırlamanın tek yolu uygulamayı kaldırıp yeniden kurmaktır; bu da tüm verilerini siler. Önce Ayarlar’dan yedek al.'),
              style: TextStyle(fontSize: 12.5, color: p.soft, height: 1.35),
            ),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_err!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tx('Vazgeç'))),
        FilledButton(onPressed: _ok, child: Text(tx('Kaydet'))),
      ],
    );
  }
}

// ---------------------------------------------------------------
// MEVCUT ŞİFREYİ SOR: doğruysa true döner (kilidi kapatırken / değiştirirken)
// ---------------------------------------------------------------
Future<bool> askCurrentPassword(BuildContext context) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => const _CurrentPasswordDialog(),
  );
  return r ?? false;
}

class _CurrentPasswordDialog extends StatefulWidget {
  const _CurrentPasswordDialog();

  @override
  State<_CurrentPasswordDialog> createState() => _CurrentPasswordDialogState();
}

class _CurrentPasswordDialogState extends State<_CurrentPasswordDialog> {
  final _c = TextEditingController();
  bool _hide = true;
  String? _err;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _ok() {
    if (store.checkPassword(_c.text)) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _err = tx('Şifre yanlış');
        _c.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tx('Mevcut şifre')),
      content: TextField(
        controller: _c,
        autofocus: true,
        obscureText: _hide,
        onSubmitted: (_) => _ok(),
        decoration: InputDecoration(
          labelText: tx('Şifre'),
          errorText: _err,
          suffixIcon: IconButton(
            icon: Icon(
                _hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
            onPressed: () => setState(() => _hide = !_hide),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tx('Vazgeç'))),
        FilledButton(onPressed: _ok, child: Text(tx('Tamam'))),
      ],
    );
  }
}
