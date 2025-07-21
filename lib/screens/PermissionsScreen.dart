import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  bool notificationGranted = false;
  bool locationGranted = false;
  bool bluetoothGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkPermissions();
    }
  }

  Future<void> checkPermissions() async {
    final notifStatus = await Permission.notification.status;
    final locationStatus = await Permission.location.status;
    final currentState = FlutterBluePlus.adapterStateNow;

    setState(() {
      notificationGranted = notifStatus.isGranted;
      locationGranted = locationStatus.isGranted;
      bluetoothGranted = currentState == BluetoothAdapterState.on;
    });
  }

  Future<void> requestPermission(Permission permission) async {
    final status = await permission.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  Widget buildPermissionTile(
    String title,
    bool granted,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: granted ? Colors.green : Colors.red),
      title: Text(
        title,
        style: TextStyle(
          color: granted ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(granted ? "Açık ✅" : "Kapalı ❌ (İzin Ver)"),
      trailing:
          granted
              ? const Icon(Icons.check, color: Colors.green)
              : ElevatedButton(onPressed: onTap, child: const Text("İzin Ver")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1621),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1621),
        title: const Text("📲 Uygulama İzinleri"),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Uygulamanın aşağıdakilere erişmesine izin veriliyor:",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  children: [
                    buildPermissionTile(
                      "Bildirimler",
                      notificationGranted,
                      Icons.notifications,
                      () => requestPermission(Permission.notification),
                    ),
                    buildPermissionTile(
                      "Konum",
                      locationGranted,
                      Icons.location_on,
                      () => requestPermission(Permission.location),
                    ),
                    buildPermissionTile(
                      "Bluetooth",
                      bluetoothGranted,
                      Icons.bluetooth,
                      () {
                        if (!bluetoothGranted) openAppSettings();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
