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

  /// Calls the proxy endpoint with query parameters.
  ///
  /// The proxy server will add the API key server-side for security.
  /// Includes retry logic with exponential backoff for throttle errors.
  Future<http.Response> _callProxy(Map<String, String> queryParams) async {
    final payload = {
      'chainId': config.chainId,
      'queryParams': queryParams,
    };

    const int maxAttempts = 4; // 1 try + 3 retries
    int baseDelayMs = 350;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final res = await _httpClient.post(
        Uri.parse(config.proxyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      // Pass through non-200 unless the body shows the known throttle condition.
      final bodyText = res.body.toLowerCase();
      final isThrottleHttp = res.statusCode == 429;
      final isThrottleBody = bodyText.contains('free api access is temporarily unavailable');

      if (!isThrottleHttp && !isThrottleBody) {
        return res;
      }

      // Last attempt: return whatever we got.
      if (attempt == maxAttempts) {
        return res;
      }

      // Backoff + jitter
      final jitter = (100 * attempt);
      final delay = Duration(milliseconds: baseDelayMs + jitter);
      await Future.delayed(delay);
      baseDelayMs *= 2;
    }

    // Unreachable
    return http.Response('Retry loop failed unexpectedly', 520);
  }

  /// Fetches the current block number from the blockchain.
  ///
  /// Uses proxy action: eth_blockNumber (hex response).
  /// Returns the block number as an integer.
  ///
  /// Throws an exception if the API call fails.
  Future<int> getCurrentBlock() async {
    debugPrint('🔍 EtherscanService.getCurrentBlock (via proxy)');

    final response = await _callProxy({
      'module': 'proxy',
      'action': 'eth_blockNumber',
    });

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch current block: ${response.statusCode}');
    }

    final dynamic data = jsonDecode(response.body);

    // JSON-RPC success shape: { "jsonrpc": "2.0", "id": 1, "result": "0x..." }
    if (data is Map && data.containsKey('jsonrpc')) {
      final hex = data['result'] as String? ?? (throw Exception('Missing result'));
      return int.parse(hex.startsWith('0x') ? hex.substring(2) : hex, radix: 16);
    }

    // Etherscan OK wrapper shape: { "status":"1","message":"OK","result":"0x..." }
    if (data is Map && data['status'] == '1' && data['result'] is String) {
      final hex = data['result'] as String;
      return int.parse(hex.startsWith('0x') ? hex.substring(2) : hex, radix: 16);
    }

    // Etherscan error/throttle shape: { "status":"0","message":"NOTOK","result":"Free API access ..." }
    if (data is Map && data['status'] == '0') {
      final msg = (data['result'] ?? data['message'] ?? 'Unknown error').toString();
      throw Exception('Etherscan error: $msg');
    }

    throw Exception('Unexpected response: ${response.body}');
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
    debugPrint('🔍 EtherscanService.getTokenTxPage (page $page, via proxy)');

    try {
      final response = await _callProxy({
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
  /// - [perPagePause]: Delay between pages to avoid rate limiting (default 300ms).
  ///
  /// Returns all transactions sorted in ascending order by block number.
  Future<List<Map<String, dynamic>>> getTokenTxFromBlock({
    required String address,
    required String contractAddress,
    required int startBlock,
    int offset = 1000,
    int maxPages = 10,
    Duration perPagePause = const Duration(milliseconds: 300),
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

      // Avoid short spikes > 5 rps
      await Future.delayed(perPagePause);
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
      debugPrint(
        '🔍 EtherscanService.getInboundTransferLogs (page $page, via proxy)',
      );

      try {
        final response = await _callProxy({
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
