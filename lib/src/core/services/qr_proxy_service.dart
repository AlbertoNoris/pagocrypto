import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Response object containing the QR code image data.
///
/// Can hold either:
/// - bytes: decoded PNG data if API returned base64
/// - url: image URL if API returned a link
class QrResponse {
  final Uint8List? bytes;
  final String? url;

  QrResponse({this.bytes, this.url});
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
  /// Parameters:
  /// - data: The content to encode in the QR code (e.g., payment URL)
  /// - qrtype: Type of QR code (default: 'static')
  /// - backcolor: Background color (default: '#ecd354')
  /// - frontcolor: Foreground/data color (default: '#672300')
  /// - markerOut: Outer marker color (default: '#672300')
  /// - markerIn: Inner marker color (default: '#f76a00')
  /// - pattern: QR code pattern style (default: 'default')
  /// - marker: Marker style (default: 'default')
  /// - markerInShape: Inner marker shape (default: 'default')
  ///
  /// Returns a QrResponse containing either image bytes or a URL.
  /// Throws an Exception if the API call fails.
  Future<QrResponse> create({
    required String data,
    String qrtype = 'static',
    String backcolor = '#ecd354',
    String frontcolor = '#672300',
    String markerOut = '#672300',
    String markerIn = '#f76a00',
    String pattern = 'default',
    String marker = 'default',
    String markerInShape = 'default',
  }) async {
    final res = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'data': data,
        'qrtype': qrtype,
        'transparent': 'off',
        'backcolor': backcolor,
        'frontcolor': frontcolor,
        'marker_out_color': markerOut,
        'marker_in_color': markerIn,
        'pattern': pattern,
        'marker': marker,
        'marker_in': markerInShape,
        // The proxy injects the logo from server-side assets
        'no_logo_bg': 'off',
        'outer_frame': 'none',
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('QR proxy error ${res.statusCode}: ${res.body}');
    }

    final Map<String, dynamic> json = jsonDecode(res.body);

    // Handle different response formats from qr.io API

    // 1. Check for direct base64 'qrcode' field
    final String? qrcode = json['qrcode'] as String?;
    if (qrcode != null) {
      final String b64 = qrcode.startsWith('data:')
          ? qrcode.split(',').last
          : qrcode;
      return QrResponse(bytes: base64Decode(b64), url: null);
    }

    // 2. Check for direct 'url' field
    final String? url = json['url'] as String?;
    if (url != null) {
      return QrResponse(bytes: null, url: url);
    }

    // 3. Check for format-specific URLs (png, jpg, svg, etc.)
    // Prefer PNG for better quality
    final String? pngUrl = json['png'] as String?;
    if (pngUrl != null) {
      return QrResponse(bytes: null, url: pngUrl);
    }

    // Fallback to JPG if PNG not available
    final String? jpgUrl = json['jpg'] as String?;
    if (jpgUrl != null) {
      return QrResponse(bytes: null, url: jpgUrl);
    }

    // 4. Fallback: search for any URL-like string in response
    String? fallbackUrl;
    try {
      fallbackUrl = json.values.firstWhere(
        (v) => v is String && v.startsWith('http'),
      ) as String?;
    } catch (e) {
      fallbackUrl = null;
    }

    if (fallbackUrl != null) {
      return QrResponse(bytes: null, url: fallbackUrl);
    }

    throw Exception('Unexpected QR response format: ${res.body}');
  }
}
