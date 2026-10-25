import 'package:flutter/material.dart';
import 'data.dart';
import 'notes.dart';
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// GÜNLÜK TAKVİMİ (soldaki menüden): notu olan günler işaretlidir.
// Bir tarihe dokununca takvimin altında o günün notu görünür;
// "Düzenle" / "Not yaz" ile not yazılır ya da değiştirilir.
// ---------------------------------------------------------------
class DiaryCalendarPage extends StatefulWidget {
  const DiaryCalendarPage({super.key});

  @override
  State<DiaryCalendarPage> createState() => _DiaryCalendarPageState();
}

class _DiaryCalendarPageState extends State<DiaryCalendarPage> {
  late DateTime _month =
      DateTime(DateTime.now().year, DateTime.now().month, 1); // gösterilen ay
  DateTime _sel = dayOnly(DateTime.now()); // seçili gün

  void _moveMonth(int n) =>
      setState(() => _month = DateTime(_month.year, _month.month + n, 1));

  Future<void> _edit() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NoteEditPage(
        date: dKey(_sel),
        title: '${dateLabel(_sel)} ${_sel.year}',
      ),
    ));
    if (mounted) setState(() {}); // dönünce işaretler güncellensin
  }

  // Takvimdeki tek gün hücresi
  Widget _cell(Pal p, DateTime d, bool hasNote, bool isSel, bool isToday) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => setState(() => _sel = d),
      child: Center(
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSel ? p.accent : null,
            border: (isToday && !isSel)
                ? Border.all(color: p.accent, width: 1.5)
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '${d.day}',
                style: TextStyle(
                  color: isSel ? p.onAccent : p.ink,
                  fontWeight: hasNote ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              // Notu olan günün altında küçük nokta
              if (hasNote)
                Positioned(
                  bottom: 4,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSel ? p.onAccent : p.accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        final today = dKey(DateTime.now());
        final selKey = dKey(_sel);
        final note = store.noteOf(selKey);

        // Ayın günleri: pazartesi başlangıçlı 7 sütunlu ızgara
        final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
        final lead = _month.weekday - 1; // ilk günden önceki boş hücreler
        final cells = <Widget>[
          for (var i = 0; i < lead; i++) const SizedBox(),
          for (var d = 1; d <= daysInMonth; d++)
            () {
              final date = DateTime(_month.year, _month.month, d);
              final k = dKey(date);
              return _cell(p, date, store.noteOf(k).isNotEmpty, k == selKey,
                  k == today);
            }(),
        ];
        while (cells.length % 7 != 0) {
          cells.add(const SizedBox());
        }
        final rows = <Widget>[
          for (var r = 0; r < cells.length ~/ 7; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(child: SizedBox(height: 46, child: cells[r * 7 + c])),
              ],
            ),
        ];

        return Scaffold(
          appBar: AppBar(
            backgroundColor: p.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(tx('Günlük')),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            children: [
              // Ay başlığı ve önceki / sonraki ay
              Row(
                children: [
                  IconButton(
                    onPressed: () => _moveMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${monName(_month.month)} ${_month.year}',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: p.ink),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _moveMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              // Gün adları
              Row(
                children: [
                  for (var d = 1; d <= 7; d++)
                    Expanded(
                      child: Center(
                        child: Text(wdShort(d),
                            style: TextStyle(fontSize: 12, color: p.soft)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ...rows,
              const SizedBox(height: 16),
              // Seçili günün notu
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${dateLabel(_sel)} ${_sel.year}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: p.ink)),
                    const SizedBox(height: 10),
                    if (note.isEmpty)
                      Text(tx('Bu gün için not yok'),
                          style: TextStyle(color: p.soft))
                    else
                      SelectableText(note,
                          style: TextStyle(color: p.ink, height: 1.4)),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _edit,
                        icon: Icon(note.isEmpty
                            ? Icons.add_rounded
                            : Icons.edit_rounded),
                        label:
                            Text(note.isEmpty ? tx('Not yaz') : tx('Düzenle')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
