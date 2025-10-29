import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;

/// Service to generate QR codes via a Vercel proxy endpoint.
///
/// This service calls a Vercel serverless function that proxies requests
/// to the qr.io API, keeping the API key secure on the server side.
class QrProxyService {
  final String endpoint;

  const QrProxyService(this.endpoint);

  /// Creates a QR code by calling the Vercel proxy endpoint.
  ///
  /// The proxy server uses default styling configuration:
  /// - Background: #2a7afb (blue)
  /// - Foreground: #ffffff (white)
  /// - Markers: circle with rounded inner
  /// - Logo: qr_center.png from server assets
  ///
  /// Parameters:
  /// - data: The content to encode in the QR code (e.g., payment URL)
  /// - customStyle: Optional map to override default server styling
  ///
  /// Returns a QrResponse containing the image bytes downloaded from the URL.
  /// Throws an Exception if the API call fails.
  Future<Uint8List> create({
    required String data,
    Map<String, dynamic>? customStyle,
  }) async {
    // The server will apply its defaults
    final payload = <String, dynamic>{'data': data};

    // Merge any custom style overrides if provided
    if (customStyle != null) {
      payload.addAll(customStyle);
    }

    final res = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'image/jpeg', // We now expect an image back
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      // Our proxy API *will* return JSON/text on error, so this is correct.
      throw Exception('QR proxy error ${res.statusCode}: ${res.body}');
    }

    // If status is 200, the body is the image data directly.
    return res.bodyBytes;
  }
}
