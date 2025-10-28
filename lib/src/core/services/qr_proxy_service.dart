import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Response object containing the QR code image data.
class QrResponse {
  final Uint8List? imageBytes;
  final String? url;

  QrResponse({this.imageBytes, this.url});
}

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
  Future<QrResponse> create({
    required String data,
    Map<String, dynamic>? customStyle,
  }) async {
    // Build payload with only the data field
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
        'Accept': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception('QR proxy error ${res.statusCode}: ${res.body}');
    }

    final Map<String, dynamic> json = jsonDecode(res.body);

    // Extract the JPG download URL
    final String? jpgUrl = json['jpg'] as String?;
    if (jpgUrl == null) {
      throw Exception('Unexpected QR response format: ${res.body}');
    }

    // Web: return URL only to avoid CORS on fetch()
    if (kIsWeb) {
      return QrResponse(imageBytes: null, url: jpgUrl);
    }

    // Mobile/desktop: download bytes
    final imageRes = await http.get(Uri.parse(jpgUrl));
    if (imageRes.statusCode != 200) {
      throw Exception('Failed to download QR image: ${imageRes.statusCode}');
    }

    return QrResponse(
      imageBytes: imageRes.bodyBytes,
      url: jpgUrl,
    );
  }
}
