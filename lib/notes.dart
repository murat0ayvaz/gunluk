import 'package:flutter/material.dart';
import 'data.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// GÜNÜN NOTU (günlük): o günün önemli olaylarını yazma ekranı.
// Yazdıkça telefona otomatik kaydedilir; metin tamamen silinirse
// o günün notu kalkar. Her günün notu ayrı tutulur.
// ---------------------------------------------------------------
class NotePage extends StatefulWidget {
  final String date; // yyyy-MM-dd
  final String title; // üstte gösterilen gün adı
  const NotePage({super.key, required this.date, required this.title});

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  late final TextEditingController _c =
      TextEditingController(text: store.noteOf(widget.date));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(widget.title, style: const TextStyle(fontSize: 17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tx('Bitti')),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
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
            Text(tx('Yazdıkların otomatik kaydedilir'),
                style: TextStyle(fontSize: 12.5, color: p.soft)),
          ],
        ),
      ),
    );
  }
}
