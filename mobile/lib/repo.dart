import 'api_client.dart';
import 'models.dart';

/// Data access for Patela's domain. [ApiRepo] talks to the Flask backend;
/// [InMemoryRepo] backs widget tests and offline demos.
abstract class Repo {
  Future<List<Friend>> listFriends();
  Future<Friend> addFriend(String name);
  Future<void> deleteFriend(String id);

  Future<Bill> createBill({
    required String merchant,
    required double total,
    required List<Participant> participants,
  });
  Future<Txn> payParticipant({
    required Bill bill,
    required Participant participant,
    required String method,
  });
  Future<void> settleBill(String billId);

  Future<List<Txn>> listTransactions({int limit = 100});
  Future<SalesSummary> todaySales();
  Future<Txn> recordSale({
    required double amount,
    required String method,
    required String reference,
    required String subtitle,
  });
}

/// Backed by the Patela Flask API. All business rules (split maths, ownership,
/// settlement, idempotency) are enforced server-side; this just maps JSON.
class ApiRepo implements Repo {
  ApiRepo(this.api);

  final ApiClient api;

  @override
  Future<List<Friend>> listFriends() async {
    final rows = await api.listFriends();
    return rows.map((r) => Friend.fromRow(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<Friend> addFriend(String name) async {
    final row = await api.addFriend(name, hexFromColor(avatarColorFor(name)));
    return Friend.fromRow(row);
  }

  @override
  Future<void> deleteFriend(String id) => api.deleteFriend(id);

  @override
  Future<Bill> createBill({
    required String merchant,
    required double total,
    required List<Participant> participants,
  }) async {
    final row = await api.createBill(
      merchant: merchant,
      total: total,
      participants: participants
          .map((p) => {
                if (p.friendId != null) 'friend_id': p.friendId,
                'name': p.name,
                'color': hexFromColor(p.color),
                'amount': p.amount,
              })
          .toList(),
    );
    return Bill.fromRow(row);
  }

  @override
  Future<Txn> payParticipant({
    required Bill bill,
    required Participant participant,
    required String method,
  }) async {
    final body = await api.payParticipant(
      billId: bill.id,
      participantId: participant.id,
      method: method,
    );
    // The server returns the updated bill; mirror the paid state locally so the
    // collecting screen reflects it without a refetch.
    final updated = Bill.fromRow(body['bill'] as Map<String, dynamic>);
    for (final p in bill.participants) {
      final match = updated.participants.firstWhere(
        (u) => u.id == p.id,
        orElse: () => p,
      );
      p.paid = match.paid;
      p.method = match.method;
    }
    bill.settledAt = updated.settledAt;
    return Txn.fromRow(body['transaction'] as Map<String, dynamic>);
  }

  @override
  Future<void> settleBill(String billId) => api.settleBill(billId);

  @override
  Future<List<Txn>> listTransactions({int limit = 100}) async {
    final rows = await api.listTransactions(limit: limit);
    return rows.map((r) => Txn.fromRow(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<SalesSummary> todaySales() async {
    final row = await api.todaySales();
    return SalesSummary(
      count: (row['count'] as num?)?.toInt() ?? 0,
      total: (row['total'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Future<Txn> recordSale({
    required double amount,
    required String method,
    required String reference,
    required String subtitle,
  }) async {
    final row = await api.recordSale(
      amount: amount,
      method: method,
      reference: reference,
      subtitle: subtitle,
    );
    return Txn.fromRow(row);
  }
}

/// In-memory implementation for tests and offline demos.
class InMemoryRepo implements Repo {
  final List<Friend> _friends = [];
  final List<Txn> _txns = [];
  final Map<String, Bill> _bills = {};
  int _seq = 0;

  String _id() => 'mem-${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  /// Test seam: preload transactions (newest first) with fixed dates.
  void seedTransactions(List<Txn> txns) => _txns
    ..clear()
    ..addAll(txns);

  @override
  Future<List<Friend>> listFriends() async => List.of(_friends);

  @override
  Future<Friend> addFriend(String name) async {
    final f = Friend(id: _id(), name: name, color: avatarColorFor(name));
    _friends.add(f);
    return f;
  }

  @override
  Future<void> deleteFriend(String id) async => _friends.removeWhere((f) => f.id == id);

  @override
  Future<Bill> createBill({
    required String merchant,
    required double total,
    required List<Participant> participants,
  }) async {
    final parts = participants
        .map((p) => Participant(
              id: _id(),
              friendId: p.friendId,
              name: p.name,
              color: p.color,
              amount: p.amount,
            ))
        .toList();
    final bill = Bill(id: _id(), merchant: merchant, total: total, participants: parts);
    _bills[bill.id] = bill;
    return bill;
  }

  @override
  Future<Txn> payParticipant({
    required Bill bill,
    required Participant participant,
    required String method,
  }) async {
    participant.paid = true;
    participant.method = method;
    final txn = Txn(
      id: _id(),
      kind: 'split_incoming',
      title: participant.name,
      subtitle: 'Bill split · ${bill.merchant}',
      amount: participant.amount,
      method: method,
      createdAt: DateTime.now(),
    );
    _txns.insert(0, txn);
    return txn;
  }

  @override
  Future<void> settleBill(String billId) async => _bills[billId]?.settledAt = DateTime.now();

  @override
  Future<List<Txn>> listTransactions({int limit = 100}) async => _txns.take(limit).toList();

  @override
  Future<SalesSummary> todaySales() async {
    final today = _txns.where((t) => t.isSale);
    return SalesSummary(
      count: today.length,
      total: today.fold(0, (a, t) => a + t.amount),
    );
  }

  @override
  Future<Txn> recordSale({
    required double amount,
    required String method,
    required String reference,
    required String subtitle,
  }) async {
    final txn = Txn(
      id: _id(),
      kind: 'sale',
      title: 'Card sale',
      subtitle: subtitle,
      amount: amount,
      method: method,
      reference: reference,
      createdAt: DateTime.now(),
    );
    _txns.insert(0, txn);
    return txn;
  }
}
