import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _walletDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

class SksWallet {
  final String childId;
  final int balance;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SksWallet({
    required this.childId,
    required this.balance,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SksWallet.empty(String childId) {
    final now = DateTime.now();
    return SksWallet(
      childId: childId,
      balance: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory SksWallet.fromMap(Map<String, dynamic> map) {
    return SksWallet(
      childId: map['childId'] as String? ?? '',
      balance: (map['balance'] as num?)?.toInt() ?? 0,
      createdAt: _walletDate(map['createdAt']),
      updatedAt: _walletDate(map['updatedAt']),
    );
  }
}

class SksWalletOperation {
  final String id;
  final String childId;
  final String type;
  final int amount;
  final int delta;
  final String reason;
  final String actorUid;
  final int balanceAfter;
  final DateTime createdAt;

  const SksWalletOperation({
    required this.id,
    required this.childId,
    required this.type,
    required this.amount,
    required this.delta,
    required this.reason,
    required this.actorUid,
    required this.balanceAfter,
    required this.createdAt,
  });

  factory SksWalletOperation.fromMap(Map<String, dynamic> map) {
    return SksWalletOperation(
      id: map['id'] as String? ?? '',
      childId: map['childId'] as String? ?? '',
      type: map['type'] as String? ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      delta: (map['delta'] as num?)?.toInt() ?? 0,
      reason: map['reason'] as String? ?? '',
      actorUid: map['actorUid'] as String? ?? '',
      balanceAfter: (map['balanceAfter'] as num?)?.toInt() ?? 0,
      createdAt: _walletDate(map['createdAt']),
    );
  }
}

class SksWalletAdjustmentResult {
  final String operationId;
  final int balance;
  final bool idempotent;

  const SksWalletAdjustmentResult({
    required this.operationId,
    required this.balance,
    required this.idempotent,
  });

  factory SksWalletAdjustmentResult.fromData(Object? data) {
    if (data is! Map) {
      throw const FormatException('Réponse de cagnotte invalide.');
    }
    final map = Map<String, dynamic>.from(data);
    final operationId = map['operationId'];
    final balance = map['balance'];
    final idempotent = map['idempotent'];
    if (operationId is! String ||
        operationId.isEmpty ||
        balance is! num ||
        idempotent is! bool) {
      throw const FormatException('Réponse de cagnotte invalide.');
    }
    return SksWalletAdjustmentResult(
      operationId: operationId,
      balance: balance.toInt(),
      idempotent: idempotent,
    );
  }
}
