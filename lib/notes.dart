import 'dart:async';
import 'package:flutter/material.dart';
import 'data.dart';
import 'strings.dart';
import 'ui.dart';
import 'voice.dart';

// ---------------------------------------------------------------
// GÜNLÜK (günün notu): o günün önemli olaylarını yazma alanı.
// Ana ekranın altındaki panelde "Günlük" başlığına dokununca açılır.
// Yazdıkça telefona otomatik kaydedilir; metin tamamen silinirse
// o günün notu kalkar. Her günün notu ayrı tutulur.
// ---------------------------------------------------------------
class NoteBody extends StatefulWidget {
  final String date; // yyyy-MM-dd
  final String title; // gün adı (örn. "Bugün • 23 Ekim Cuma")
  final VoidCallback? onSaved; // Kaydet'e basılınca (örn. sayfayı kapat)
  const NoteBody(
      {super.key, required this.date, required this.title, this.onSaved});

  @override
  State<NoteBody> createState() => _NoteBodyState();
}

class _NoteBodyState extends State<NoteBody> {
  late final TextEditingController _c =
      TextEditingController(text: store.noteOf(widget.date));
  bool _saved = false; // "Kaydedildi" yazısı 2 sn görünür
  Timer? _t;

  void _save() {
    store.setNote(widget.date, _c.text);
    FocusScope.of(context).unfocus();
    setState(() => _saved = true);
    _t?.cancel();
    _t = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
    widget.onSaved?.call();
  }

  Future<void> _addVoice() async {
    final name = await recordVoice(context);
    if (name == null || !mounted) return;
    store.addVoice(widget.date, name);
  }

  Future<void> _delVoice(String name) async {
    final ok = await confirmDialog(
      context,
      tx('Ses kaydı silinsin mi?'),
      tx('Kayıt telefondan silinir.'),
      okLabel: tx('Sil'),
    );
    if (ok) store.removeVoice(widget.date, name);
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: p.soft)),
          const SizedBox(height: 10),
          Expanded(
            child: TextField(
              controller: _c,
              autofocus: store.noteOf(widget.date).isEmpty,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              // Her değişiklikte sessizce kaydet (ekranı yeniden çizmeden)
              onChanged: (v) => store.setNote(widget.date, v, notify: false),
              decoration: InputDecoration(
                hintText:
                    tx('Bu gün neler oldu? Önemli olayları buraya yazabilirsin.'),
                filled: true,
                fillColor: p.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: p.line),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final vs = store.voicesOf(widget.date);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (vs.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final v in vs)
                            VoiceTile(name: v, onDelete: () => _delVoice(v)),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addVoice,
                      icon: const Icon(Icons.mic_rounded),
                      label: Text(tx('Ses kaydı ekle')),
                    ),
                  ),
                ],
              );
            },
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                    _saved
                        ? tx('Kaydedildi')
                        : tx('Yazdıkların otomatik kaydedilir'),
                    style: TextStyle(
                        fontSize: 12.5,
                        color: _saved ? const Color(0xFF3E8E5A) : p.soft)),
              ),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(tx('Kaydet')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// Takvimden bir günün notunu düzenleme sayfası (tam ekran)
// ---------------------------------------------------------------
class NoteEditPage extends StatelessWidget {
  final String date; // yyyy-MM-dd
  final String title; // örn. "23 Ekim Cuma 2026"
  const NoteEditPage({super.key, required this.date, required this.title});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(tx('Günlük')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tx('Bitti')),
          ),
        ],
      ),
      body: NoteBody(
        date: date,
        title: title,
        onSaved: () => Navigator.pop(context),
      ),
    );
  }
}
