import 'package:flutter/foundation.dart';
import 'package:pagocrypto/src/core/utils/amount_utils.dart';

/// Immutable data model for a parsed blockchain token transfer transaction.
///
/// This model represents an ERC-20 token transfer transaction received on the
/// blockchain, parsed from the Etherscan API response (tokentx action).
///
/// The model includes block anchoring information (blockNumber, transactionIndex)
/// to enable deterministic sorting and payment monitoring without relying on
/// timestamps.
@immutable
class ReceivedTransaction {
  final String hash;
  final String from;
  final String to;
  final int blockNumber;
  final int transactionIndex;
  final int timestamp; // seconds (Unix timestamp)
  final double amount; // normalized using tokenDecimal

  const ReceivedTransaction({
    required this.hash,
    required this.from,
    required this.to,
    required this.blockNumber,
    required this.transactionIndex,
    required this.timestamp,
    required this.amount,
  });

  /// Creates a ReceivedTransaction instance from a JSON map (Etherscan tokentx response).
  ///
  /// The JSON is expected to contain fields like:
  /// - hash: transaction hash
  /// - from: sender address
  /// - to: recipient address
  /// - blockNumber: block number (as string)
  /// - transactionIndex: transaction index in block (as string)
  /// - timeStamp: Unix timestamp in seconds (as string)
  /// - value: raw token amount in wei (as string)
  /// - tokenDecimal: token decimal places (as string)
  factory ReceivedTransaction.fromJson(Map<String, dynamic> json) {
    // Parse tokenDecimal to normalize the amount
    final int decimals = int.parse(json['tokenDecimal'] as String);

    // Parse the raw value (wei-like) as a BigInt to avoid precision loss
    final BigInt rawValue = BigInt.parse(json['value'] as String);
    final BigInt divisor = BigInt.from(10).pow(decimals);
    final double rawAmount = (rawValue / divisor).toDouble();

    // Apply floor rounding to 2 decimal places for payment verification
    // Example: if sender sends 9.99999, we consider it as 9.99
    final double normalizedAmount = floorToTwoDecimals(rawAmount);

    return ReceivedTransaction(
      hash: json['hash'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      blockNumber: int.parse(json['blockNumber'] as String),
      transactionIndex: int.parse(json['transactionIndex'] as String),
      timestamp: int.parse(json['timeStamp'] as String),
      amount: normalizedAmount,
    );
  }

  /// Converts the ReceivedTransaction instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'hash': hash,
      'from': from,
      'to': to,
      'blockNumber': blockNumber,
      'transactionIndex': transactionIndex,
      'timestamp': timestamp,
      'amount': amount,
    };
  }

  @override
  String toString() {
    return 'ReceivedTransaction(hash: $hash, from: $from, to: $to, '
        'blockNumber: $blockNumber, transactionIndex: $transactionIndex, '
        'timestamp: $timestamp, amount: $amount)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceivedTransaction &&
          runtimeType == other.runtimeType &&
          hash == other.hash &&
          from == other.from &&
          to == other.to &&
          blockNumber == other.blockNumber &&
          transactionIndex == other.transactionIndex &&
          timestamp == other.timestamp &&
          amount == other.amount;

  @override
  int get hashCode =>
      hash.hashCode ^
      from.hashCode ^
      to.hashCode ^
      blockNumber.hashCode ^
      transactionIndex.hashCode ^
      timestamp.hashCode ^
      amount.hashCode;
}
