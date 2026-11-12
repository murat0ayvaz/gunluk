import 'package:flutter/material.dart';
import 'data.dart';
import 'notify.dart';
import 'reminders.dart' show permissionMessage;
import 'strings.dart';
import 'theme.dart' show Pal;
import 'tools.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// CÜZDAN (Araçlar > Para): harcamalar, borç, alacak
// Birden fazla cüzdan (Murat, Eymen ...). Tutarlar kuruş (tam sayı) tutulur.
// ---------------------------------------------------------------

const _incColor = Color(0xFF2E9E6B);
const _expColor = Color(0xFFD1495B);

const _catColors = [
  Color(0xFF3E9FD6),
  Color(0xFFE8883A),
  Color(0xFF8A6FD1),
  Color(0xFFD1495B),
  Color(0xFF2E9E6B),
  Color(0xFFC9A227),
  Color(0xFF4F8FA0),
  Color(0xFFB5658D),
  Color(0xFF6B8E3D),
  Color(0xFF7A7F88),
];

const _payNames = ['Peşin', 'Kredi kartı', 'Banka kartı'];
const _payIcons = [
  Icons.payments_rounded,
  Icons.credit_card_rounded,
  Icons.account_balance_rounded,
];

/// 1234567 -> "12.345,67 ₺"
String money(int k, {bool sign = false}) {
  final neg = k < 0;
  final a = k.abs();
  final whole = (a ~/ 100).toString();
  final b = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) b.write('.');
    b.write(whole[i]);
  }
  final c = (a % 100).toString().padLeft(2, '0');
  final s = neg ? '-' : (sign && k > 0 ? '+' : '');
  return '$s$b,$c ₺';
}

String _plain(int k) {
  final c = k % 100;
  return c == 0 ? '${k ~/ 100}' : '${k ~/ 100},${c.toString().padLeft(2, '0')}';
}

int? parseMoney(String s) {
  var t = s.trim().replaceAll(' ', '');
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else {
    final n = '.'.allMatches(t).length;
    if (n > 1) {
      t = t.replaceAll('.', '');
    } else if (n == 1 && t.length - t.indexOf('.') - 1 == 3) {
      t = t.replaceAll('.', '');
    }
  }
  final v = double.tryParse(t);
  if (v == null || v <= 0) return null;
  return (v * 100).round();
}

int _ms(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
DateTime _dt(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);
String _dLabel(DateTime d) => '${d.day} ${monName(d.month)} ${d.year}';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  int _tab = 0; // 0 harcamalar, 1 borç, 2 alacak
  int _per = 2; // 0 gün, 1 hafta, 2 ay, 3 yıl
  DateTime _anchor = dayOnly(DateTime.now());

  String get _sel {
    final s = store.walletSel;
    if (s == '*' && store.wallets.length > 1) return '*';
    if (store.wallets.any((w) => w.id == s)) return s;
    return store.wallets.isEmpty ? '' : store.wallets.first.id;
  }

  bool _inSel(String wid) => _sel == '*' || wid == _sel;

  String _wname(String wid) {
    for (final w in store.wallets) {
      if (w.id == wid) return w.name;
    }
    return '';
  }

  (DateTime, DateTime) _range() {
    final a = _anchor;
    switch (_per) {
      case 0:
        return (a, DateTime(a.year, a.month, a.day + 1));
      case 1:
        final s = DateTime(a.year, a.month, a.day - (a.weekday - 1));
        return (s, DateTime(s.year, s.month, s.day + 7));
      case 2:
        return (DateTime(a.year, a.month, 1), DateTime(a.year, a.month + 1, 1));
      default:
        return (DateTime(a.year, 1, 1), DateTime(a.year + 1, 1, 1));
    }
  }

  String _rangeLabel() {
    final r = _range();
    switch (_per) {
      case 0:
        return dateLabel(r.$1);
      case 1:
        final e = DateTime(r.$2.year, r.$2.month, r.$2.day - 1);
        return '${r.$1.day} ${monName(r.$1.month)} - ${e.day} ${monName(e.month)} ${e.year}';
      case 2:
        return '${monName(r.$1.month)} ${r.$1.year}';
      default:
        return '${r.$1.year}';
    }
  }

  void _shift(int dir) {
    final a = _anchor;
    setState(() {
      switch (_per) {
        case 0:
          _anchor = DateTime(a.year, a.month, a.day + dir);
          break;
        case 1:
          _anchor = DateTime(a.year, a.month, a.day + 7 * dir);
          break;
        case 2:
          _anchor = DateTime(a.year, a.month + dir, 1);
          break;
        default:
          _anchor = DateTime(a.year + dir, 1, 1);
      }
    });
  }

  // ---------- cüzdanlar ----------

  Future<void> _addWallet() async {
    final n = await askText(context, tx('Yeni cüzdan'), label: tx('Cüzdan adı'));
    if (n == null || n.trim().isEmpty) return;
    store.addWallet(n);
  }

  Future<void> _walletMenu(Wallet w) async {
    final act = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: Text(tx('Yeniden adlandır')),
              onTap: () => Navigator.pop(ctx, 'ren'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(tx('Sil')),
              onTap: () => Navigator.pop(ctx, 'del'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || act == null) return;
    if (act == 'ren') {
      final n = await askText(context, tx('Cüzdan adı'), initial: w.name);
      if (n != null && n.trim().isNotEmpty) store.renameWallet(w, n);
    } else {
      final ok = await confirmDialog(
        context,
        tx('Cüzdan silinsin mi?'),
        tx('“{0}” cüzdanı ve içindeki tüm kayıtlar silinecek.', [w.name]),
        okLabel: tx('Sil'),
      );
      if (ok) {
        for (final d in List.of(store.wdebts)) {
          if (d.wid == w.id) Notifier.cancelDebt(d);
        }
        store.deleteWallet(w);
      }
    }
  }

  Widget _walletChips(Pal p) {
    final ws = store.wallets;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final w in ws)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onLongPress: () => _walletMenu(w),
                child: ChoiceChip(
                  avatar: const Icon(Icons.account_balance_wallet_rounded,
                      size: 18),
                  label: Text(w.name),
                  selected: _sel == w.id,
                  onSelected: (_) => store.selectWallet(w.id),
                ),
              ),
            ),
          if (ws.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(tx('Hepsi')),
                selected: _sel == '*',
                onSelected: (_) => store.selectWallet('*'),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: Text(tx('Ekle')),
            onPressed: _addWallet,
          ),
        ],
      ),
    );
  }

  // ---------- genel yardımcılar ----------

  Widget _box(Pal p, Widget child,
          {EdgeInsets pad = const EdgeInsets.all(14)}) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: pad,
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.line),
        ),
        child: child,
      );

  Widget _swipe(Pal p, String tag, VoidCallback onDel, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Dismissible(
            key: ValueKey('wl_$tag'),
            direction: DismissDirection.startToEnd,
            background: Container(
              color: p.delBg,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: const Icon(Icons.delete_outline_rounded),
            ),
            confirmDismiss: (dir) async {
              onDel();
              return false;
            },
            child: child,
          ),
        ),
      );

  Widget _bars(Pal p, List<(String, int, Color)> items, int total) {
    if (items.isEmpty || total <= 0) return const SizedBox.shrink();
    return Column(
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration:
                          BoxDecoration(color: it.$3, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(it.$1,
                          style: TextStyle(
                              color: p.ink,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ),
                    Text('%${(it.$2 * 100 / total).round()}',
                        style: TextStyle(color: p.soft, fontSize: 13)),
                    const SizedBox(width: 10),
                    Text(money(it.$2),
                        style: TextStyle(
                            color: p.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: it.$2 / total,
                    minHeight: 7,
                    backgroundColor: p.line,
                    color: it.$3,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tabs(Pal p) {
    final names = [tx('Harcamalar'), tx('Borç'), tx('Alacak')];
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
              child: Material(
                color: _tab == i ? p.accent : p.card,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _tab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.line),
                    ),
                    child: Text(names[i],
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _tab == i ? p.onAccent : p.ink)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---------- harcamalar ----------

  List<WalletTx> _periodTx() {
    final r = _range();
    final a = r.$1.millisecondsSinceEpoch;
    final b = r.$2.millisecondsSinceEpoch;
    final l = store.wtx
        .where((t) => _inSel(t.wid) && t.ms >= a && t.ms < b)
        .toList();
    l.sort((x, y) => y.ms != x.ms ? y.ms.compareTo(x.ms) : y.id.compareTo(x.id));
    return l;
  }

  List<Widget> _spendBody(Pal p) {
    final list = _periodTx();
    var inc = 0, exp = 0;
    final byCat = <String, int>{};
    final byPay = <int, int>{};
    for (final t in list) {
      if (t.income) {
        inc += t.amount;
      } else {
        exp += t.amount;
        byCat[t.cat] = (byCat[t.cat] ?? 0) + t.amount;
        byPay[t.pay] = (byPay[t.pay] ?? 0) + t.amount;
      }
    }
    final cats = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final perNames = [tx('Gün'), tx('Hafta'), tx('Ay'), tx('Yıl')];

    var owe = 0, due = 0;
    for (final d in store.wdebts) {
      if (!_inSel(d.wid) || d.done) continue;
      if (d.theirs) {
        due += d.left;
      } else {
        owe += d.left;
      }
    }

    return [
      Row(
        children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 3 ? 6 : 0),
                child: ChoiceChip(
                  showCheckmark: false,
                  label: SizedBox(
                      width: double.infinity,
                      child: Text(perNames[i], textAlign: TextAlign.center)),
                  selected: _per == i,
                  onSelected: (_) => setState(() => _per = i),
                ),
              ),
            ),
        ],
      ),
      Row(
        children: [
          IconButton(
              onPressed: () => _shift(-1),
              icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _anchor = dayOnly(DateTime.now())),
              child: Text(_rangeLabel(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: p.ink, fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ),
          IconButton(
              onPressed: () => _shift(1),
              icon: const Icon(Icons.chevron_right_rounded)),
        ],
      ),
      _box(
        p,
        Column(
          children: [
            Row(
              children: [
                _sumCell(p, tx('Gelir'), money(inc), _incColor),
                _sumCell(p, tx('Gider'), money(exp), _expColor),
                _sumCell(p, tx('Net'), money(inc - exp, sign: true), p.ink),
              ],
            ),
          ],
        ),
      ),
      if (owe > 0 || due > 0)
        _box(
          p,
          Row(
            children: [
              _sumCell(p, tx('Borç'), money(owe), _expColor),
              _sumCell(p, tx('Alacak'), money(due), _incColor),
              _sumCell(p, tx('Net'), money(due - owe, sign: true), p.ink),
            ],
          ),
        ),
      if (cats.isNotEmpty)
        _box(
          p,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _boxTitle(p, Icons.pie_chart_rounded, tx('Kategoriye göre')),
              _bars(p, [
                for (var i = 0; i < cats.length; i++)
                  (tx(cats[i].key), cats[i].value, _catColors[i % _catColors.length])
              ], exp),
            ],
          ),
        ),
      if (byPay.isNotEmpty)
        _box(
          p,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _boxTitle(p, Icons.credit_card_rounded, tx('Ödeme şekline göre')),
              _bars(p, [
                for (final k in [0, 1, 2])
                  if ((byPay[k] ?? 0) > 0)
                    (tx(_payNames[k]), byPay[k]!, _catColors[k])
              ], exp),
            ],
          ),
        ),
      const SizedBox(height: 4),
      if (list.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(tx('Bu dönemde kayıt yok.'),
              textAlign: TextAlign.center, style: TextStyle(color: p.soft)),
        ),
      for (final t in list) _txRow(p, t),
    ];
  }

  Widget _boxTitle(Pal p, IconData i, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(i, size: 20, color: p.ink),
            const SizedBox(width: 8),
            Text(s,
                style: TextStyle(
                    color: p.ink, fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
      );

  Widget _sumCell(Pal p, String label, String value, Color c) => Expanded(
        child: Column(
          children: [
            Text(label, style: TextStyle(color: p.soft, fontSize: 13)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      color: c, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ],
        ),
      );

  Widget _txRow(Pal p, WalletTx t) {
    final sub = [
      _dLabel(_dt(t.ms)),
      if (!t.income) tx(_payNames[t.pay.clamp(0, 2).toInt()]),
      if (_sel == '*') _wname(t.wid),
      if (t.note.isNotEmpty) t.note,
    ].join(' · ');
    return _swipe(
      p,
      'tx_${t.id}',
      () => _delTx(t),
      Material(
        color: p.card,
        child: InkWell(
          onTap: () => _editTx(t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: p.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      (t.income ? _incColor : _expColor).withOpacity(0.15),
                  child: Icon(
                      t.income
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      size: 18,
                      color: t.income ? _incColor : _expColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tx(t.cat),
                          style: TextStyle(
                              color: p.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      Text(sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.soft, fontSize: 12.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(money(t.income ? t.amount : -t.amount, sign: true),
                    style: TextStyle(
                        color: t.income ? _incColor : _expColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _delTx(WalletTx t) {
    store.walletRemoveTx(t);
    showUndo(context, tx('Kayıt silindi'), () => store.walletAddTx(t));
  }

  Future<void> _editTx(WalletTx? t, {bool income = false}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TxSheet(
        t: t,
        wid: _sel == '*' || _sel.isEmpty ? store.wallets.first.id : _sel,
        income: income,
      ),
    );
  }

  // ---------- borç / alacak ----------

  List<Widget> _debtBody(Pal p, bool theirs) {
    final all = store.wdebts
        .where((d) => d.theirs == theirs && _inSel(d.wid))
        .toList();
    final open = all.where((d) => !d.done).toList()
      ..sort((a, b) {
        final x = a.dueMs == 0 ? 1 << 60 : a.dueMs;
        final y = b.dueMs == 0 ? 1 << 60 : b.dueMs;
        return x.compareTo(y);
      });
    final done = all.where((d) => d.done).toList();
    final left = open.fold<int>(0, (a, d) => a + d.left);
    final today = _ms(DateTime.now());
    final lateN = open.where((d) => d.dueMs > 0 && d.dueMs < today).length;
    return [
      _box(
        p,
        Row(
          children: [
            _sumCell(
                p,
                theirs ? tx('Toplam alacak') : tx('Toplam borç'),
                money(left),
                theirs ? _incColor : _expColor),
            _sumCell(p, tx('Açık kayıt'), '${open.length}', p.ink),
            if (lateN > 0) _sumCell(p, tx('Vadesi geçen'), '$lateN', _expColor),
          ],
        ),
      ),
      if (all.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
              theirs
                  ? tx('Alacak kaydı yok. Sağ alttaki + ile ekleyebilirsin.')
                  : tx('Borç kaydı yok. Sağ alttaki + ile ekleyebilirsin.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: p.soft)),
        ),
      for (final d in open) _debtRow(p, d, today),
      if (done.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Text(theirs ? tx('Tahsil edildi') : tx('Ödendi'),
              style: TextStyle(
                  color: p.soft, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        for (final d in done) _debtRow(p, d, today),
      ],
    ];
  }

  Widget _debtRow(Pal p, WalletDebt d, int today) {
    final overdue = !d.done && d.dueMs > 0 && d.dueMs < today;
    final sub = <String>[
      tx('Toplam {0}', [money(d.total)]),
      if (d.paid > 0) tx('Ödenen {0}', [money(d.paid)]),
      if (_sel == '*') _wname(d.wid),
      if (d.note.isNotEmpty) d.note,
    ].join(' · ');
    final row = Material(
      color: p.card,
      child: InkWell(
        onTap: () => _editDebt(d),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: overdue ? _expColor : p.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    (d.theirs ? _incColor : _expColor).withOpacity(0.15),
                child: Icon(
                    d.done
                        ? Icons.check_rounded
                        : (d.theirs
                            ? Icons.call_received_rounded
                            : Icons.call_made_rounded),
                    size: 18,
                    color: d.theirs ? _incColor : _expColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.person,
                        style: TextStyle(
                            color: p.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    Text(sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.soft, fontSize: 12.5)),
                    if (d.dueMs > 0 && !d.done)
                      Text(
                          overdue
                              ? tx('Vade geçti: {0}', [_dLabel(_dt(d.dueMs))])
                              : tx('Vade: {0}', [_dLabel(_dt(d.dueMs))]),
                          style: TextStyle(
                              color: overdue ? _expColor : p.soft,
                              fontWeight:
                                  overdue ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(money(d.done ? d.total : d.left),
                      style: TextStyle(
                          color: d.theirs ? _incColor : _expColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                  if (!d.done && d.paid > 0)
                    Text(tx('kalan'),
                        style: TextStyle(color: p.soft, fontSize: 11.5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return _swipe(p, 'debt_${d.id}', () => _delDebt(d),
        d.done ? Opacity(opacity: 0.5, child: row) : row);
  }

  void _delDebt(WalletDebt d) {
    Notifier.cancelDebt(d);
    store.walletRemoveDebt(d);
    showUndo(context, tx('Kayıt silindi'), () {
      store.walletAddDebt(d);
      Notifier.syncDebt(d);
    });
  }

  Future<void> _editDebt(WalletDebt? d, {bool theirs = false}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DebtSheet(
        d: d,
        theirs: d?.theirs ?? theirs,
        wid: _sel == '*' || _sel.isEmpty ? store.wallets.first.id : _sel,
      ),
    );
  }

  void _add() {
    if (_tab == 0) {
      _editTx(null);
    } else {
      _editDebt(null, theirs: _tab == 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final empty = store.wallets.isEmpty;
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            backgroundColor: p.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(tx('Cüzdan')),
            actions: const [ToolsButton()],
          ),
          endDrawer: const ToolsDrawer(replace: true),
          floatingActionButton: empty
              ? null
              : FloatingActionButton(
                  onPressed: _add,
                  child: const Icon(Icons.add_rounded),
                ),
          body: SafeArea(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: empty
                  ? [
                      const SizedBox(height: 40),
                      Icon(Icons.account_balance_wallet_rounded,
                          size: 64, color: p.soft),
                      const SizedBox(height: 14),
                      Text(
                          tx('Harcama, borç ve alacaklarını takip etmek için önce bir cüzdan ekle (ör. Murat, Eymen).'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.soft, height: 1.4)),
                      const SizedBox(height: 18),
                      Center(
                        child: FilledButton.icon(
                          onPressed: _addWallet,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(tx('Cüzdan ekle')),
                        ),
                      ),
                    ]
                  : [
                      _walletChips(p),
                      const SizedBox(height: 12),
                      _tabs(p),
                      const SizedBox(height: 10),
                      if (_tab == 0) ..._spendBody(p),
                      if (_tab == 1) ..._debtBody(p, false),
                      if (_tab == 2) ..._debtBody(p, true),
                    ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------
// Harcama / gelir ekleme-düzenleme paneli
// ---------------------------------------------------------------
class _TxSheet extends StatefulWidget {
  final WalletTx? t;
  final String wid;
  final bool income;
  const _TxSheet({required this.t, required this.wid, required this.income});

  @override
  State<_TxSheet> createState() => _TxSheetState();
}

class _TxSheetState extends State<_TxSheet> {
  late bool _in;
  late String _cat;
  late int _pay;
  late DateTime _d;
  late String _wid;
  bool _err = false;
  final _amt = TextEditingController();
  final _note = TextEditingController();

  List<String> get _cats => _in ? store.walletIncCats : store.walletExpCats;

  @override
  void initState() {
    super.initState();
    final t = widget.t;
    if (t != null) {
      _in = t.income;
      _cat = t.cat;
      _pay = t.pay;
      _d = _dt(t.ms);
      _wid = t.wid;
      _amt.text = _plain(t.amount);
      _note.text = t.note;
    } else {
      _in = widget.income;
      _cat = _cats.isEmpty ? 'Diğer' : _cats.first;
      _pay = 0;
      _d = dayOnly(DateTime.now());
      _wid = widget.wid;
    }
  }

  @override
  void dispose() {
    _amt.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final r = await showDatePicker(
      context: context,
      initialDate: _d,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (r != null) setState(() => _d = dayOnly(r));
  }

  Future<void> _addCat() async {
    final n = await askText(context, tx('Yeni kategori'),
        label: tx('Kategori adı'));
    if (n == null || n.trim().isEmpty) return;
    final name = n.trim();
    if (!_cats.contains(name)) {
      store.walletSetCats(_in, [..._cats, name]);
    }
    setState(() => _cat = name);
  }

  Future<void> _delCat(String c) async {
    if (_cats.length <= 1) return;
    final ok = await confirmDialog(context, tx('Kategori silinsin mi?'),
        tx('“{0}” listeden kaldırılacak. Eski kayıtlar etkilenmez.', [tx(c)]),
        okLabel: tx('Sil'));
    if (!ok) return;
    final l = [..._cats]..remove(c);
    store.walletSetCats(_in, l);
    setState(() {
      if (_cat == c) _cat = l.first;
    });
  }

  void _save() {
    final a = parseMoney(_amt.text);
    if (a == null) {
      setState(() => _err = true);
      return;
    }
    final t = widget.t;
    if (t == null) {
      store.walletAddTx(WalletTx(store.newId(), _wid, _ms(_d), a, _in, _cat,
          _in ? 0 : _pay, _note.text.trim()));
    } else {
      t.wid = _wid;
      t.ms = _ms(_d);
      t.amount = a;
      t.income = _in;
      t.cat = _cat;
      t.pay = _in ? 0 : _pay;
      t.note = _note.text.trim();
      store.walletSave();
    }
    Navigator.pop(context);
  }

  Widget _label(Pal p, String s) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(s,
            style: TextStyle(
                color: p.soft, fontWeight: FontWeight.w700, fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    showCheckmark: false,
                    label: SizedBox(
                        width: double.infinity,
                        child: Text(tx('Gider'), textAlign: TextAlign.center)),
                    selected: !_in,
                    onSelected: (_) => setState(() {
                      _in = false;
                      _cat = _cats.isEmpty ? 'Diğer' : _cats.first;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    showCheckmark: false,
                    label: SizedBox(
                        width: double.infinity,
                        child: Text(tx('Gelir'), textAlign: TextAlign.center)),
                    selected: _in,
                    onSelected: (_) => setState(() {
                      _in = true;
                      _cat = _cats.isEmpty ? 'Diğer' : _cats.first;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amt,
              autofocus: widget.t == null,
              keyboardType: numberKeyboard,
              inputFormatters: numberFormatters,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                labelText: tx('Tutar'),
                suffixText: '₺',
                errorText: _err ? tx('Geçerli bir tutar gir') : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_err) setState(() => _err = false);
              },
            ),
            if (store.wallets.length > 1) ...[
              _label(p, tx('Cüzdan')),
              Wrap(
                spacing: 8,
                children: [
                  for (final w in store.wallets)
                    ChoiceChip(
                      label: Text(w.name),
                      selected: _wid == w.id,
                      onSelected: (_) => setState(() => _wid = w.id),
                    ),
                ],
              ),
            ],
            _label(p, tx('Kategori')),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in _cats)
                  GestureDetector(
                    onLongPress: () => _delCat(c),
                    child: ChoiceChip(
                      label: Text(tx(c)),
                      selected: _cat == c,
                      onSelected: (_) => setState(() => _cat = c),
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: Text(tx('Ekle')),
                  onPressed: _addCat,
                ),
              ],
            ),
            if (!_in) ...[
              _label(p, tx('Ödeme şekli')),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < 3; i++)
                    ChoiceChip(
                      avatar: Icon(_payIcons[i], size: 18),
                      label: Text(tx(_payNames[i])),
                      selected: _pay == i,
                      onSelected: (_) => setState(() => _pay = i),
                    ),
                ],
              ),
            ],
            _label(p, tx('Tarih')),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_rounded),
              label: Text(_dLabel(_d)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: tx('Not'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                  onPressed: _save, child: Text(tx('Kaydet'))),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Borç / alacak ekleme-düzenleme paneli (kısmi ödemeler dahil)
// ---------------------------------------------------------------
class _DebtSheet extends StatefulWidget {
  final WalletDebt? d;
  final bool theirs;
  final String wid;
  const _DebtSheet({required this.d, required this.theirs, required this.wid});

  @override
  State<_DebtSheet> createState() => _DebtSheetState();
}

class _DebtSheetState extends State<_DebtSheet> {
  late DateTime _d;
  DateTime? _due;
  late String _wid;
  late bool _remind;
  bool _errA = false;
  bool _errP = false;
  final _who = TextEditingController();
  final _amt = TextEditingController();
  final _note = TextEditingController();
  late List<List<int>> _pays;

  bool get _theirs => widget.theirs;

  @override
  void initState() {
    super.initState();
    final d = widget.d;
    if (d != null) {
      _d = _dt(d.ms);
      _due = d.dueMs > 0 ? _dt(d.dueMs) : null;
      _wid = d.wid;
      _remind = d.remind;
      _who.text = d.person;
      _amt.text = _plain(d.total);
      _note.text = d.note;
      _pays = d.pays;
    } else {
      _d = dayOnly(DateTime.now());
      _wid = widget.wid;
      _remind = false;
      _pays = [];
    }
  }

  @override
  void dispose() {
    _who.dispose();
    _amt.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _total => parseMoney(_amt.text) ?? widget.d?.total ?? 0;
  int get _paid => _pays.fold<int>(0, (a, b) => a + b[1]);

  Future<void> _pickDate(bool due) async {
    final r = await showDatePicker(
      context: context,
      initialDate: due ? (_due ?? _d) : _d,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (r == null) return;
    setState(() {
      if (due) {
        _due = dayOnly(r);
      } else {
        _d = dayOnly(r);
      }
    });
  }

  void _afterPayChange() {
    final d = widget.d;
    if (d != null) {
      store.walletSave();
      Notifier.syncDebt(d);
    }
    setState(() {});
  }

  Future<void> _addPay({bool all = false}) async {
    int? k;
    if (all) {
      k = (_total - _paid) > 0 ? _total - _paid : null;
    } else {
      final v = await askNumber(context,
          title: _theirs ? tx('Tahsilat tutarı') : tx('Ödeme tutarı'),
          unit: '₺');
      if (v != null && v > 0) k = (v * 100).round();
    }
    if (k == null) return;
    _pays.add([_ms(DateTime.now()), k]);
    _afterPayChange();
  }

  void _save() {
    final who = _who.text.trim();
    final a = parseMoney(_amt.text);
    if (who.isEmpty || a == null) {
      setState(() {
        _errP = who.isEmpty;
        _errA = a == null;
      });
      return;
    }
    final dueMs = _due == null ? 0 : _ms(_due!);
    var d = widget.d;
    if (d == null) {
      d = WalletDebt(store.newId(), _wid, _theirs, who, a, _ms(_d), dueMs,
          _note.text.trim(), _remind && dueMs > 0, store.newNid(), _pays);
      store.walletAddDebt(d);
    } else {
      d.wid = _wid;
      d.person = who;
      d.total = a;
      d.ms = _ms(_d);
      d.dueMs = dueMs;
      d.note = _note.text.trim();
      d.remind = _remind && dueMs > 0;
      if (d.nid == 0) d.nid = store.newNid();
      store.walletSave();
    }
    Notifier.syncDebt(d);
    Navigator.pop(context);
  }

  Widget _label(Pal p, String s) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(s,
            style: TextStyle(
                color: p.soft, fontWeight: FontWeight.w700, fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final left = (_total - _paid) < 0 ? 0 : _total - _paid;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                _theirs
                    ? (widget.d == null ? tx('Yeni alacak') : tx('Alacağı düzenle'))
                    : (widget.d == null ? tx('Yeni borç') : tx('Borcu düzenle')),
                style: TextStyle(
                    color: p.ink, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: _who,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _theirs ? tx('Kimden alacaklısın') : tx('Kime borçlusun'),
                errorText: _errP ? tx('Kişi adı gir') : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_errP) setState(() => _errP = false);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amt,
              keyboardType: numberKeyboard,
              inputFormatters: numberFormatters,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                labelText: tx('Tutar'),
                suffixText: '₺',
                errorText: _errA ? tx('Geçerli bir tutar gir') : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _errA = false),
            ),
            if (store.wallets.length > 1) ...[
              _label(p, tx('Cüzdan')),
              Wrap(
                spacing: 8,
                children: [
                  for (final w in store.wallets)
                    ChoiceChip(
                      label: Text(w.name),
                      selected: _wid == w.id,
                      onSelected: (_) => setState(() => _wid = w.id),
                    ),
                ],
              ),
            ],
            _label(p, tx('Tarih')),
            OutlinedButton.icon(
              onPressed: () => _pickDate(false),
              icon: const Icon(Icons.event_rounded),
              label: Text(_dLabel(_d)),
            ),
            _label(p, tx('Vade (isteğe bağlı)')),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(true),
                    icon: const Icon(Icons.alarm_rounded),
                    label: Text(_due == null ? tx('Vade yok') : _dLabel(_due!)),
                  ),
                ),
                if (_due != null)
                  IconButton(
                    onPressed: () => setState(() => _due = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            if (_due != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tx('Vade gününde hatırlat')),
                value: _remind,
                onChanged: (v) async {
                  setState(() => _remind = v);
                  if (v) {
                    final msg = await permissionMessage();
                    if (!mounted) return;
                    if (msg != null) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(msg)));
                    }
                  }
                },
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: tx('Not'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (widget.d != null) ...[
              _label(p, _theirs ? tx('Tahsilatlar') : tx('Ödemeler')),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _pays.length; i++)
                      Row(
                        children: [
                          Expanded(
                            child: Text(_dLabel(_dt(_pays[i][0])),
                                style: TextStyle(color: p.soft)),
                          ),
                          Text(money(_pays[i][1]),
                              style: TextStyle(
                                  color: p.ink, fontWeight: FontWeight.w700)),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              _pays.removeAt(i);
                              _afterPayChange();
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                    if (_pays.isEmpty)
                      Text(tx('Henüz kayıt yok.'),
                          style: TextStyle(color: p.soft)),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(tx('Kalan'),
                              style: TextStyle(
                                  color: p.ink, fontWeight: FontWeight.w800)),
                        ),
                        Text(money(left),
                            style: TextStyle(
                                color: left == 0 ? _incColor : p.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _addPay(),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(_theirs
                              ? tx('Tahsilat ekle')
                              : tx('Ödeme ekle')),
                        ),
                        if (left > 0)
                          FilledButton.tonalIcon(
                            onPressed: () => _addPay(all: true),
                            icon: const Icon(Icons.done_all_rounded),
                            label: Text(_theirs
                                ? tx('Tamamı tahsil edildi')
                                : tx('Tamamı ödendi')),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                  onPressed: _save, child: Text(tx('Kaydet'))),
            ),
          ],
        ),
      ),
    );
  }
}
