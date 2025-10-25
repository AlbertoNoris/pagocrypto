import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pagocrypto/src/core/config/chain_config.dart';
import 'package:pagocrypto/src/features/payment_generator/models/received_transaction.dart';

/// Service for interacting with the Etherscan V2 API.
///
/// This service encapsulates all Etherscan API calls for:
/// - Fetching the current block number
/// - Retrieving token transfer transactions
/// - Optional: Fetching logs for transfer events
///
/// The service uses Etherscan V2 API format: https://api.etherscan.io/v2/api
/// with chain-specific configuration via ChainConfig.
class EtherscanService {
  final http.Client _httpClient;
  final ChainConfig config;

  EtherscanService({required this.config, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Builds a V2 API URI with common parameters.
  ///
  /// All Etherscan V2 requests require apikey and chainid query parameters.
  Uri _buildV2Uri(Map<String, String> queryParams) {
    final allParams = {
      'apikey': config.apiKey,
      'chainid': config.chainId.toString(),
      ...queryParams,
    };
    return Uri.parse(
      '${config.apiBaseUrl}/v2/api',
    ).replace(queryParameters: allParams);
  }

  /// Fetches the current block number from the blockchain.
  ///
  /// Uses proxy action: eth_blockNumber (hex response).
  /// Returns the block number as an integer.
  ///
  /// Throws an exception if the API call fails.
  Future<int> getCurrentBlock() async {
    final uri = _buildV2Uri({'module': 'proxy', 'action': 'eth_blockNumber'});

    debugPrint('🔍 EtherscanService.getCurrentBlock: $uri');

    try {
      final response = await _httpClient.get(uri);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch current block: ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final result = data['result'];

      if (result == null) {
        throw Exception('No result in getCurrentBlock response');
      }

      // Parse hex string to int
      final hex = result as String;
      final blockNumber = int.parse(
        hex.startsWith('0x') ? hex.substring(2) : hex,
        radix: 16,
      );

      debugPrint('📦 Current block: $blockNumber');
      return blockNumber;
    } catch (e) {
      debugPrint('❌ Error fetching current block: $e');
      rethrow;
    }
  }

  /// Fetches a page of token transactions for an address.
  ///
  /// Parameters:
  /// - [address]: Wallet address to query transactions for.
  /// - [contractAddress]: ERC-20 token contract address.
  /// - [startBlock]: Block number to start searching from.
  /// - [page]: Pagination page number (1-based).
  /// - [offset]: Number of results per page (max 10000).
  /// - [asc]: If true, sort ascending; if false, sort descending.
  ///
  /// No `tag=latest` parameter is used. The API supports block ranges via
  /// startblock and endblock parameters only.
  Future<List<Map<String, dynamic>>> getTokenTxPage({
    required String address,
    required String contractAddress,
    required int startBlock,
    required int page,
    int offset = 1000,
    bool asc = true,
  }) async {
    final uri = _buildV2Uri({
      'module': 'account',
      'action': 'tokentx',
      'contractaddress': contractAddress,
      'address': address,
      'startblock': startBlock.toString(),
      'endblock': '9999999999',
      'sort': asc ? 'asc' : 'desc',
      'page': page.toString(),
      'offset': offset.toString(),
    });

    debugPrint('🔍 EtherscanService.getTokenTxPage (page $page): $uri');

    try {
      final response = await _httpClient.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch transactions: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['status'] != '1') {
        if (data['message'] == 'No transactions found') {
          debugPrint('ℹ️ No transactions found');
          return [];
        }
        throw Exception('API Error: ${data['message']} - ${data['result']}');
      }

      final result = data['result'];
      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching token transactions (page $page): $e');
      rethrow;
    }
  }

  /// Fetches all token transactions for an address starting from a given block.
  ///
  /// This method handles pagination automatically, fetching multiple pages
  /// until all results are retrieved or the maximum number of pages is reached.
  ///
  /// Parameters:
  /// - [address]: Wallet address to query.
  /// - [contractAddress]: ERC-20 token contract address.
  /// - [startBlock]: Block number to start from (block-cursor anchoring).
  /// - [offset]: Results per page (default 1000, max 10000).
  /// - [maxPages]: Maximum number of pages to fetch (default 10).
  ///
  /// Returns all transactions sorted in ascending order by block number.
  Future<List<Map<String, dynamic>>> getTokenTxFromBlock({
    required String address,
    required String contractAddress,
    required int startBlock,
    int offset = 1000,
    int maxPages = 10,
  }) async {
    final results = <Map<String, dynamic>>[];

    for (int page = 1; page <= maxPages; page++) {
      final batch = await getTokenTxPage(
        address: address,
        contractAddress: contractAddress,
        startBlock: startBlock,
        page: page,
        offset: offset,
        asc: true,
      );

      if (batch.isEmpty) {
        debugPrint('ℹ️ Pagination complete at page $page');
        break;
      }

      results.addAll(batch);

      // If we got fewer results than the offset, we've reached the end
      if (batch.length < offset) {
        debugPrint('ℹ️ Last page reached (${batch.length} < $offset)');
        break;
      }
    }

    debugPrint('📊 Retrieved ${results.length} transactions total');
    return results;
  }

  /// Fetches inbound transfer logs for a recipient address (optional Logs API path).
  ///
  /// This method uses the Logs API to find ERC-20 transfer events where
  /// the recipient is the target address. It filters by:
  /// - Topic 0: ERC-20 Transfer(from, to, value) event signature
  /// - Topic 2: Recipient address (the `to` parameter in Transfer event)
  ///
  /// Parameters:
  /// - [recipientAddress]: The address that received the tokens.
  /// - [fromBlock]: Starting block number.
  /// - [toBlock]: Ending block number (default 999999999).
  /// - [offset]: Results per page (default 1000).
  /// - [maxPages]: Maximum pages to fetch (default 10).
  ///
  /// Returns raw log data from the API.
  Future<List<Map<String, dynamic>>> getInboundTransferLogs({
    required String recipientAddress,
    required int fromBlock,
    int toBlock = 999999999,
    int offset = 1000,
    int maxPages = 10,
  }) async {
    // ERC-20 Transfer event signature: Transfer(address indexed from, address indexed to, uint256 value)
    const transferTopic =
        '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';

    // Topic 2 is the `to` parameter (recipient). Pad address to 64 hex chars.
    final topic2 =
        '0x${recipientAddress.replaceFirst('0x', '').padLeft(64, '0').toLowerCase()}';

    final results = <Map<String, dynamic>>[];

    for (int page = 1; page <= maxPages; page++) {
      final uri = _buildV2Uri({
        'module': 'logs',
        'action': 'getLogs',
        'address': config.tokenAddress,
        'fromBlock': fromBlock.toString(),
        'toBlock': toBlock.toString(),
        'topic0': transferTopic,
        'topic2': topic2,
        'page': page.toString(),
        'offset': offset.toString(),
      });

      debugPrint(
        '🔍 EtherscanService.getInboundTransferLogs (page $page): $uri',
      );

      try {
        final response = await _httpClient.get(uri);

        if (response.statusCode != 200) {
          throw Exception('Failed to fetch logs: ${response.statusCode}');
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['status'] != '1') {
          if (data['message'] == 'No logs found') {
            debugPrint('ℹ️ No logs found');
            break;
          }
          throw Exception('API Error: ${data['message']} - ${data['result']}');
        }

        final result = data['result'];
        if (result is List) {
          final batch = result.cast<Map<String, dynamic>>();
          results.addAll(batch);

          if (batch.length < offset) {
            debugPrint('ℹ️ Last page reached');
            break;
          }
        } else {
          break;
        }
      } catch (e) {
        debugPrint('❌ Error fetching logs (page $page): $e');
        rethrow;
      }
    }

    debugPrint('📊 Retrieved ${results.length} logs total');
    return results;
  }

  /// Legacy method for backward compatibility.
  ///
  /// Deprecated: Use getTokenTxFromBlock() with ChainConfig instead.
  Future<List<ReceivedTransaction>> getTokenTransactions({
    required String apiBaseUrl,
    required String address,
    required String contractAddress,
    required String apiKey,
    required int chainId,
  }) async {
    // This method is kept for backward compatibility during transition.
    // New code should use ChainConfig and getTokenTxFromBlock().
    final raw = await getTokenTxFromBlock(
      address: address,
      contractAddress: contractAddress,
      startBlock: 0,
    );

    final transactions = <ReceivedTransaction>[];
    for (final item in raw) {
      try {
        transactions.add(ReceivedTransaction.fromJson(item));
      } catch (e) {
        debugPrint('Error parsing transaction ${item['hash']}: $e');
      }
    }
    return transactions;
  }
}
