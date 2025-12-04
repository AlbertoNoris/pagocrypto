import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pagocrypto/src/core/config/chain_config.dart';
import 'package:pagocrypto/src/features/payment_generator/models/received_transaction.dart';

/// Service for interacting with the Moralis API.
///
/// This service replaces EtherscanService and uses Moralis for:
/// - Fetching token transfer history (indexed)
/// - Getting current block number (via dateToBlock)
class MoralisService {
  final http.Client _httpClient;
  final ChainConfig config;
  final String _baseUrl = 'https://deep-index.moralis.io/api/v2.2';

  MoralisService({required this.config, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Helper to get the chain ID in hex format (e.g., 56 -> 0x38)
  String get _hexChainId => '0x${config.chainId.toRadixString(16)}';

  /// Fetches the current block number using Moralis dateToBlock endpoint.
  ///
  /// We use the current timestamp to find the closest block.
  Future<int> getCurrentBlock({String? apiKey}) async {
    debugPrint('🔍 MoralisService.getCurrentBlock');

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Moralis API Key is required');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final uri = Uri.parse('$_baseUrl/dateToBlock');
    final queryParams = {'chain': _hexChainId, 'date': now};

    try {
      final response = await _httpClient.get(
        uri.replace(queryParameters: queryParams),
        headers: {'accept': 'application/json', 'X-API-Key': apiKey},
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch current block: ${response.statusCode} ${response.body}',
        );
      }

      final data = jsonDecode(response.body);
      return data['block'] as int;
    } catch (e) {
      debugPrint('❌ Error fetching current block: $e');
      rethrow;
    }
  }

  /// Fetches token transactions for an address.
  ///
  /// Uses Moralis `getWalletTokenTransfers` endpoint.
  ///
  /// Parameters:
  /// - [address]: Wallet address to query.
  /// - [contractAddress]: ERC-20 token contract address.
  /// - [startBlock]: Optional start block to filter results (client-side filtering might be needed if API doesn't support strict from_block in all plans, but Moralis does support `from_block`).
  /// - [limit]: Number of results to fetch (default 50).
  /// - [apiKey]: Required Moralis API Key.
  Future<List<ReceivedTransaction>> getTokenTransactions({
    required String address,
    required String contractAddress,
    int? startBlock,
    int limit = 50,
    required String apiKey,
  }) async {
    debugPrint('🔍 MoralisService.getTokenTransactions (limit $limit)');

    final uri = Uri.parse('$_baseUrl/$address/erc20/transfers');
    final queryParams = {
      'chain': _hexChainId,
      'contract_addresses[]': contractAddress, // Filter by specific token
      'order': 'DESC', // Newest first
      'limit': limit.toString(),
      if (startBlock != null) 'from_block': startBlock.toString(),
    };

    try {
      final response = await _httpClient.get(
        uri.replace(queryParameters: queryParams),
        headers: {'accept': 'application/json', 'X-API-Key': apiKey},
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch transactions: ${response.statusCode} ${response.body}',
        );
      }

      final data = jsonDecode(response.body);
      final results = data['result'] as List<dynamic>;

      return results
          .map((json) => _mapMoralisToReceivedTransaction(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching token transactions: $e');
      rethrow;
    }
  }

  /// Maps Moralis JSON response to ReceivedTransaction model.
  ReceivedTransaction _mapMoralisToReceivedTransaction(
    Map<String, dynamic> json,
  ) {
    // Moralis returns values as strings, similar to Etherscan but with different keys.
    // We need to map them to the format ReceivedTransaction expects or create a new factory.
    // Since ReceivedTransaction.fromJson expects Etherscan format, we'll manually construct it here.

    final int decimals = json['token_decimals'] != null
        ? int.parse(json['token_decimals'] as String)
        : config.tokenDecimals;
    final BigInt rawValue = BigInt.parse(json['value'] as String);
    final BigInt divisor = BigInt.from(10).pow(decimals);
    // Avoid division by zero if decimals is 0 (unlikely for ERC20 but possible)
    final double rawAmount =
        (rawValue / (divisor == BigInt.zero ? BigInt.one : divisor)).toDouble();

    // Use the same rounding logic as before
    // We need to import amount_utils.dart or duplicate the logic.
    // Since this is a service, duplicating the simple floor logic is acceptable to avoid circular deps if any,
    // but better to use the util if accessible.
    // I'll assume I can't easily access the private function from here without import,
    // so I'll implement the simple math: (amount * 100).floor() / 100
    final double normalizedAmount = (rawAmount * 100).floorToDouble() / 100;

    return ReceivedTransaction(
      hash: json['transaction_hash'] as String,
      from: json['from_address'] as String,
      to: json['to_address'] as String,
      blockNumber: int.parse(json['block_number'] as String),
      transactionIndex:
          json['transaction_index']
              as int, // Moralis returns int for this usually, but let's check spec. Spec says Int.
      timestamp:
          DateTime.parse(
            json['block_timestamp'] as String,
          ).millisecondsSinceEpoch ~/
          1000,
      amount: normalizedAmount,
    );
  }
}
