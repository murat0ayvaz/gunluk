import 'package:flutter/material.dart';
import 'data.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// GÜNLÜK (günün notu): o günün önemli olaylarını yazma alanı.
// Ana ekranın altındaki panelde "Günlük" başlığına dokununca açılır.
// Yazdıkça telefona otomatik kaydedilir; metin tamamen silinirse
// o günün notu kalkar. Her günün notu ayrı tutulur.
// ---------------------------------------------------------------
class NoteBody extends StatefulWidget {
  final String date; // yyyy-MM-dd
  final String title; // gün adı (örn. "Bugün • 23 Ekim Cuma")
  const NoteBody({super.key, required this.date, required this.title});

  @override
  State<NoteBody> createState() => _NoteBodyState();
}

class _NoteBodyState extends State<NoteBody> {
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
          Text(tx('Yazdıkların otomatik kaydedilir'),
              style: TextStyle(fontSize: 12.5, color: p.soft)),
        ],
      ),
    );
  }
}
