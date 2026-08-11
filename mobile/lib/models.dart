import 'package:flutter/material.dart';

/// Formats an amount in South African Rand, e.g. R128.40.
String fmt(num n) => 'R${n.toStringAsFixed(2)}';

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

const List<Color> _avatarPalette = [
  Color(0xFFE08579),
  Color(0xFF6E78CE),
  Color(0xFFA67BD4),
  Color(0xFF3FA796),
  Color(0xFFE0A458),
  Color(0xFF5C86C7),
];

/// Deterministic avatar colour so a given name always renders the same hue.
Color avatarColorFor(String seed) {
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _avatarPalette[seed.isEmpty ? 0 : h % _avatarPalette.length];
}

Color colorFromHex(String hex) {
  final v = hex.replaceFirst('#', '');
  return Color(int.parse('FF$v', radix: 16));
}

String hexFromColor(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// A saved contact a personal user can split bills with.
class Friend {
  Friend({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final Color color;

  String get initials => initialsOf(name);
  String get firstName => name.split(RegExp(r'\s+')).first;

  factory Friend.fromRow(Map<String, dynamic> r) => Friend(
        id: r['id'] as String,
        name: r['name'] as String,
        color: colorFromHex(r['color'] as String? ?? '#2E3A87'),
      );
}

/// A friend's share of a specific bill.
class Participant {
  Participant({
    required this.id,
    this.friendId,
    required this.name,
    required this.color,
    required this.amount,
    this.paid = false,
    this.method,
  });

  final String id;
  final String? friendId;
  final String name;
  final Color color;
  double amount;
  bool paid;
  String? method;

  String get initials => initialsOf(name);
  String get firstName => name.split(RegExp(r'\s+')).first;

  factory Participant.fromRow(Map<String, dynamic> r) => Participant(
        id: r['id'] as String,
        friendId: r['friend_id'] as String?,
        name: r['name'] as String,
        color: colorFromHex(r['color'] as String? ?? '#E08579'),
        amount: (r['amount'] as num).toDouble(),
        paid: r['paid'] as bool? ?? false,
        method: r['method'] as String?,
      );
}

/// A split: where you paid, the total, and who owes what.
class Bill {
  Bill({
    required this.id,
    required this.merchant,
    required this.total,
    required this.participants,
    this.settledAt,
  });

  final String id;
  final String merchant;
  final double total;
  final List<Participant> participants;
  DateTime? settledAt;

  double get owedTotal => participants.fold(0.0, (a, p) => a + p.amount);
  double get collected =>
      participants.where((p) => p.paid).fold(0.0, (a, p) => a + p.amount);
  double get yourShare {
    final v = ((total - owedTotal) * 100).round() / 100;
    return v < 0 ? 0 : v;
  }

  int get paidCount => participants.where((p) => p.paid).length;
  bool get allPaid => participants.isNotEmpty && participants.every((p) => p.paid);

  factory Bill.fromRow(Map<String, dynamic> r) => Bill(
        id: r['id'] as String,
        merchant: r['merchant'] as String,
        total: (r['total'] as num).toDouble(),
        participants: ((r['participants'] as List?) ?? const [])
            .map((p) => Participant.fromRow(p as Map<String, dynamic>))
            .toList(),
        settledAt: r['settled_at'] == null
            ? null
            : DateTime.parse(r['settled_at'] as String).toLocal(),
      );
}

/// A ledger entry backing the Activity feed and receipts.
class Txn {
  Txn({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    required this.amount,
    this.method,
    this.reference,
    required this.createdAt,
  });

  final String id;
  final String kind; // 'sale' | 'split_incoming'
  final String title;
  final String? subtitle;
  final double amount;
  final String? method;
  final String? reference;
  final DateTime createdAt;

  bool get isSale => kind == 'sale';
  bool get positive => amount >= 0;
  String get amountStr => (positive ? '+' : '−') + fmt(amount.abs());
  String get initials => initialsOf(title);
  Color get color => avatarColorFor(title);

  String get methodLabel => methodLabelFor(method);

  String get dateLabel => formatTxnDate(createdAt);

  factory Txn.fromRow(Map<String, dynamic> r) => Txn(
        id: r['id'] as String,
        kind: r['kind'] as String,
        title: r['title'] as String,
        subtitle: r['subtitle'] as String?,
        amount: (r['amount'] as num).toDouble(),
        method: r['method'] as String?,
        reference: r['reference'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      );
}

String methodLabelFor(String? method) {
  switch (method) {
    case 'apple_pay':
      return 'Apple Pay';
    case 'google_pay':
      return 'Google Pay';
    case 'card':
      return 'Contactless card';
    default:
      return '—';
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String formatTxnDate(DateTime d) {
  final h24 = d.hour;
  final ampm = h24 >= 12 ? 'PM' : 'AM';
  var h = h24 % 12;
  if (h == 0) h = 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '${_months[d.month - 1]} ${d.day}, ${d.year} · $h:$m $ampm';
}

class SalesSummary {
  const SalesSummary({required this.count, required this.total});
  const SalesSummary.empty() : count = 0, total = 0;

  final int count;
  final double total;

  double get avg => count == 0 ? 0 : (total / count);
}
