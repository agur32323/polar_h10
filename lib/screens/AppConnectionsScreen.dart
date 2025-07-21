import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppConnectionsScreen extends StatelessWidget {
  const AppConnectionsScreen({super.key});

  Future<void> _launchAppleHealth() async {
    const url = 'x-apple-health://';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Apple Health açılamadı.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkBackground = Colors.black;
    final textColor = Colors.white;

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: darkBackground,
        elevation: 0,
        title: Text('Uyg. Bağlantıları', style: TextStyle(color: textColor)),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Durumu görüntülemek veya paylaşım izinlerini ayarlamak için aşağıdaki bir uygulamaya dokunun.',
              style: TextStyle(color: textColor.withOpacity(0.8)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Card(
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Image.asset(
                  'assets/images/aple_health.png',
                  width: 40,
                  height: 40,
                ),
                title: Text('Apple Health', style: TextStyle(color: textColor)),
                trailing: Icon(Icons.arrow_forward_ios, color: textColor),
                onTap: _launchAppleHealth,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
