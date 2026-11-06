import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'data.dart';
import 'media.dart';
import 'reminders.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// SES KAYDI
//  - recordVoice(): mikrofonla kayıt penceresi; bitince dosya adını döndürür
//  - VoicePlayButton / VoiceTile: kaydı çal / durdur
//  Kayıtlar uygulamanın kendi "voice" klasöründe durur (yedek dosyasına girmez).
// ---------------------------------------------------------------

/// Kayıt penceresini açar; "Bitir" ile kaydedilen dosyanın ADINI döndürür
/// (vazgeçilirse null).
Future<String?> recordVoice(BuildContext context) {
  return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _RecorderDialog());
}

class _RecorderDialog extends StatefulWidget {
  const _RecorderDialog();

  @override
  State<_RecorderDialog> createState() => _RecorderDialogState();
}

class _RecorderDialogState extends State<_RecorderDialog> {
  final AudioRecorder _rec = AudioRecorder();
  Timer? _t;
  int _sec = 0;
  String? _name;
  String? _path;
  String? _err;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _t?.cancel();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      if (!await _rec.hasPermission()) {
        setState(() => _err = tx('Mikrofon izni verilmedi.'));
        return;
      }
      await media.stop();
      final dir = await store.voiceDir();
      final name = 'v_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final path = '${dir.path}/$name';
      await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path);
      _name = name;
      _path = path;
      _t = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _sec++);
      });
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _err = tx('Kayıt başlatılamadı.'));
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    _busy = true;
    _t?.cancel();
    try {
      await _rec.stop();
    } catch (_) {}
    if (!mounted) return;
    final f = _path == null ? null : File(_path!);
    final ok = f != null && f.existsSync() && f.lengthSync() > 0;
    Navigator.pop(context, ok ? _name : null);
  }

  Future<void> _cancel() async {
    if (_busy) return;
    _busy = true;
    _t?.cancel();
    try {
      await _rec.stop();
    } catch (_) {}
    try {
      if (_path != null) await File(_path!).delete();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final m = (_sec ~/ 60).toString().padLeft(2, '0');
    final s = (_sec % 60).toString().padLeft(2, '0');
    return AlertDialog(
      title: Text(tx('Ses kaydı')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_rounded,
              size: 56,
              color: _err == null ? const Color(0xFFD64545) : p.soft),
          const SizedBox(height: 8),
          if (_err != null)
            Text(_err!, textAlign: TextAlign.center)
          else
            Text('$m:$s',
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700)),
          if (_err == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(tx('Kaydediliyor...'),
                  style: TextStyle(color: p.soft)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: _cancel, child: Text(tx('Vazgeç'))),
        if (_err == null)
          FilledButton.icon(
              onPressed: _finish,
              icon: const Icon(Icons.stop_rounded),
              label: Text(tx('Bitir'))),
      ],
    );
  }
}

/// Kayıt adından (v_<ms>.m4a) zamanı okur
int voiceMs(String name) {
  final m = RegExp(r'v_(\d+)').firstMatch(name);
  return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
}

bool _isCur(String name) => media.isVoice && media.nowId == name;

Future<void> _toggleVoice(String name, String title) async {
  if (_isCur(name)) {
    media.toggle();
    return;
  }
  final dir = await store.voiceDir();
  await media.playVoice('${dir.path}/$name', name, title);
}

/// Sadece çal/durdur simgesi (yapılacaklar satırında kullanılır)
class VoicePlayButton extends StatelessWidget {
  final String name;
  final String title;
  const VoicePlayButton({super.key, required this.name, required this.title});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: media,
      builder: (context, _) {
        final on = _isCur(name) && media.playing;
        return IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: on ? tx('Durdur') : tx('Dinle'),
          onPressed: () => _toggleVoice(name, title),
          icon: Icon(
              on ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              size: 28,
              color: Theme.of(context).colorScheme.primary),
        );
      },
    );
  }
}

/// Günlükteki bir ses kaydı satırı
class VoiceTile extends StatelessWidget {
  final String name;
  final VoidCallback? onDelete;
  const VoiceTile({super.key, required this.name, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final ms = voiceMs(name);
    final label =
        ms > 0 ? tx('Ses kaydı • {0}', [dtLabel(ms)]) : tx('Ses kaydı');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          VoicePlayButton(name: name, title: label),
          Expanded(
              child: Text(label,
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (onDelete != null)
            IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: tx('Sil'),
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: p.soft)),
        ],
      ),
    );
  }
}
