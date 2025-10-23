import 'package:flutter/foundation.dart';

/// Immutable data model for a parsed blockchain transaction.
///
/// This model represents a token transfer transaction received on the blockchain,
/// parsed from the BscScan API response.
@immutable
class ReceivedTransaction {
  final String hash;
  final double amount;
  final int timestamp;
  final String from;
  final String to;

  const ReceivedTransaction({
    required this.hash,
    required this.amount,
    required this.timestamp,
    required this.from,
    required this.to,
  });

  /// Creates a ReceivedTransaction instance from a JSON map (API response).
  factory ReceivedTransaction.fromJson(Map<String, dynamic> json) {
    return ReceivedTransaction(
      hash: json['hash'] as String,
      amount: json['amount'] as double,
      timestamp: json['timestamp'] as int,
      from: json['from'] as String,
      to: json['to'] as String,
    );
  }

  /// Converts the ReceivedTransaction instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'hash': hash,
      'amount': amount,
      'timestamp': timestamp,
      'from': from,
      'to': to,
    };
  }

  @override
  String toString() {
    return 'ReceivedTransaction(hash: $hash, amount: $amount, timestamp: $timestamp, from: $from, to: $to)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceivedTransaction &&
          runtimeType == other.runtimeType &&
          hash == other.hash &&
          amount == other.amount &&
          timestamp == other.timestamp &&
          from == other.from &&
          to == other.to;

  @override
  int get hashCode =>
      hash.hashCode ^
      amount.hashCode ^
      timestamp.hashCode ^
      from.hashCode ^
      to.hashCode;
}
