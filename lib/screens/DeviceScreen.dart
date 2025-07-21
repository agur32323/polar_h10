import 'package:flutter/material.dart';

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1621),
      appBar: AppBar(
        title: const Text('Ölçüm Cihazlarım'),
        backgroundColor: const Color(0xFF0E1621),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          color: const Color(0xFFF3F2F7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/polar.png',
                  width: 100,
                  height: 50,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Polar H10",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "• Marka: Polar\n"
                    "• Bağlantı Türü: Bluetooth\n"
                    "• Desteklenen Uygulamalar: Polar Flow, Strava\n"
                    "• Otomatik Senkronizasyon: Aktif\n"
                    "• Son Kalibrasyon: 24.05.2025\n"
                    "• Pil Durumu: %75",
                    style: TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Bu cihaz, uygulamanızla otomatik olarak senkronize olur. Ek bir bağlantıya gerek yoktur.",
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
