import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class StyledQr extends StatelessWidget {
  final String data; // plain text
  final ImageProvider?
  logoImage; // e.g., AssetImage('assets/qr_center2.png') or MemoryImage(bytes)

  const StyledQr({super.key, required this.data, this.logoImage});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2A7AFB), // backcolor; transparent = off
      padding: const EdgeInsets.all(16),
      child: Center(
        child: QrImageView(
          data: data,
          version: QrVersions.auto,
          size: 380,
          // High EC level to tolerate the logo
          errorCorrectionLevel: QrErrorCorrectLevel.Q,
          backgroundColor: Colors.transparent, // keep only container color
          dataModuleStyle: const QrDataModuleStyle(
            // pattern: default
            dataModuleShape: QrDataModuleShape.circle,
            color: Colors.white, // frontcolor
          ),
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.circle, // marker: circle
            color: Colors.white, // marker_out/in colors
          ),
          embeddedImage: logoImage,
          embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(110, 110)),
        ),
      ),
    );
  }
}
