import 'package:flutter/material.dart';

import 'package:uyg/screens/AccountScreen.dart';
import 'package:uyg/screens/DeviceScreen.dart';
import 'package:uyg/screens/PermissionsScreen.dart';
import 'package:uyg/screens/login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _navigate(BuildContext context, String title) {
    switch (title) {
      case "Ölçüm Cihazlarım":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DeviceScreen()),
        );
        break;
      case "Hesabım":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AccountScreen()),
        );
        break;
      case "Uygulama İzinleri":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PermissionsScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        backgroundColor: const Color(0xFF0E1621),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _buildSettingTile(context, "Ölçüm Cihazlarım"),
          _buildSettingTile(context, "Hesabım"),
          _buildSettingTile(context, "Uygulama İzinleri"),

          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E1621),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
              ),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text(
                'Çıkış Yap',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(BuildContext context, String title) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _navigate(context, title),
    );
  }
}
