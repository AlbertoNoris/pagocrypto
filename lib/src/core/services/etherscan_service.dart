import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pagocrypto/src/features/payment_generator/models/received_transaction.dart';

class EtherscanService {
  final http.Client _httpClient;

  EtherscanService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  Future<List<ReceivedTransaction>> getTokenTransactions({
    required String apiBaseUrl,
    required String address,
    required String contractAddress,
    required String apiKey,
    required int chainId,
  }) async {
    // Etherscan v2 API endpoint with required parameters
    final uri = Uri.parse(
      '$apiBaseUrl/v2/api'
      '?apikey=$apiKey'
      '&chainid=$chainId'
      '&module=account'
      '&action=tokentx'
      '&contractaddress=$contractAddress'
      '&address=$address'
      '&startblock=0'
      '&endblock=99999999'
      '&sort=desc'
      '&tag=latest'
      '&page=1'
      '&offset=10000',
    );

    debugPrint('🔍 EtherscanService: Requesting URL: $uri');

    try {
      final response = await _httpClient.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Failed to load transactions: ${response.body}');
      }

      final data = jsonDecode(response.body);

      if (data['status'] != '1') {
        if (data['message'] == 'No transactions found') {
          return []; // Return empty list if no transactions
        }
        throw Exception('API Error: ${data['message']} - ${data['result']}');
      }

      final List<dynamic> results = data['result'];
      final List<ReceivedTransaction> transactions = [];

      for (final item in results) {
        try {
          final BigInt value = BigInt.parse(item['value']);
          final int decimals = int.parse(item['tokenDecimal']);
          final int timestamp = int.parse(item['timeStamp']);
          final double amount = value / BigInt.from(pow(10, decimals));

          transactions.add(
            ReceivedTransaction(
              hash: item['hash'],
              amount: amount,
              timestamp: timestamp,
              from: item['from'],
              to: item['to'],
            ),
          );
        } catch (e) {
          debugPrint('Error parsing transaction ${item['hash']}: $e');
        }
      }
      return transactions;
    } catch (e) {
      debugPrint('EtherscanService Error: $e');
      throw Exception('Failed to fetch or parse transactions.');
    }
  }
}
