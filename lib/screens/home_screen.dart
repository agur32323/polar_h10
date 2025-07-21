import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uyg/managers/bluetooth_manager.dart';
import 'package:uyg/screens/AppConnectionsScreen.dart';
import 'package:uyg/screens/PersonalCareScreen.dart';
import 'package:uyg/screens/SettingsScreen.dart';
import 'package:uyg/screens/apple_ekg_screen.dart';
import 'package:uyg/screens/hearthAnalysis_screen.dart';
import 'package:uyg/screens/hrv_screen.dart' hide AppleEKGScreen;
import 'package:uyg/screens/notification_service.dart';
import 'package:uyg/screens/scan_screen.dart';
import 'package:uyg/screens/statistics_screen.dart';
import 'package:uyg/services/db_service.dart';
import 'history_screen.dart';
import 'package:uyg/screens/emergency_contacts_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_sms/flutter_sms.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Guid heartRateServiceUUID = Guid(
    "0000180d-0000-1000-8000-00805f9b34fb",
  );
  final Guid heartRateMeasurementCharUUID = Guid(
    "00002a37-0000-1000-8000-00805f9b34fb",
  );

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final manager = Provider.of<BluetoothManager>(context, listen: false);
      manager.startScanAndConnect();
    });
    _connectToPolarH10();
  }

  void _connectToPolarH10() async {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.name.toLowerCase().contains("polar")) {
          await FlutterBluePlus.stopScan();
          await r.device.connect();
          final services = await r.device.discoverServices();

          for (BluetoothService service in services) {
            if (service.uuid == heartRateServiceUUID) {
              for (BluetoothCharacteristic c in service.characteristics) {
                if (c.uuid == heartRateMeasurementCharUUID) {
                  await c.setNotifyValue(true);
                  c.value.listen((value) async {
                    if (value.isNotEmpty && mounted) {
                      final bpm = value[1];

                      setState(() {
                        final manager = Provider.of<BluetoothManager>(
                          context,
                          listen: false,
                        );

                        manager.currentBPM = bpm;
                        manager.bpmData.add(
                          FlSpot(manager.timeIndex.toDouble(), bpm.toDouble()),
                        );
                        if (manager.bpmData.length > 10) {
                          manager.bpmData.removeAt(0);
                        }
                        manager.timeIndex++;
                      });

                      DBService.insertMeasurement(bpm);
                      await _checkAndSendEmergency(bpm);
                    }
                  });
                }
              }
            }
          }
          break;
        }
      }
    });
  }

  Future<void> _checkAndSendEmergency(int bpm) async {
    if (bpm == 0) {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getString('emergency_contacts');
      if (contactsJson == null) return;

      final contacts = List<Map<String, String>>.from(jsonDecode(contactsJson));
      final recipients = contacts.map((c) => c['phone']!).toList();

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final message =
          "🆘 Kalp atışı algılanmadı! Konum: https://maps.google.com/?q=${position.latitude},${position.longitude}";

      try {
        await sendSMS(
          message: message,
          recipients: recipients,
          sendDirect: true,
        );
      } catch (_) {}
    }
  }

  Future<void> _selectTimeAndScheduleNotification(BuildContext context) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime != null && mounted) {
      NotificationService.showDailyReminder(pickedTime.hour, pickedTime.minute);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🔔 Hatırlatma kuruldu: ${pickedTime.format(context)}"),
        ),
      );
    }
  }

  Future<void> _cancelNotifications(BuildContext context) async {
    await NotificationService.cancelAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🚫 Tüm hatırlatmalar iptal edildi")),
      );
    }
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

  double _averageBpm() {
    final manager = Provider.of<BluetoothManager>(context, listen: false);

    return manager.bpmData.map((e) => e.y).reduce((a, b) => a + b) /
        manager.bpmData.length;
  }

  int _maxBpm() {
    final manager = Provider.of<BluetoothManager>(context, listen: false);

    return manager.bpmData
        .map((e) => e.y)
        .reduce((a, b) => a > b ? a : b)
        .toInt();
  }

  int _minBpm() {
    final manager = Provider.of<BluetoothManager>(context, listen: false);

    return manager.bpmData
        .map((e) => e.y)
        .reduce((a, b) => a < b ? a : b)
        .toInt();
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<BluetoothManager>(context);
    final bpm = manager.currentBPM;
    final bpmData = manager.bpmData;
    final timeIndex = manager.timeIndex;
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      appBar: AppBar(
        title: const Text('Ana Sayfa'),
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: _openHistory),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
            tooltip: 'Çıkış Yap',
          ),
        ],
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color.fromRGBO(26, 35, 126, 1)),
              child: Text(
                'Menü',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Ana Sayfa'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.bluetooth),
              title: const Text('Bluetooth Bağlantı'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('İstatistikler'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StatisticsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.self_improvement),
              title: const Text('Kişisel Bakımım'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PersonalCareScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.monitor_heart),
              title: const Text('Kalp Analizi'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HeartAnalysisScreen(),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('HRV & RR Intervals '),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HRVScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.balcony),
              title: const Text('EKG Grafiği'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AppleEKGScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.devices),
              title: const Text('Uygulama Bağlantıları'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AppConnectionsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Geçmiş'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: const Text('Acil Kişiler'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EmergencyContactsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Ayarlar'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          children: [
            Text(
              "${manager.currentBPM} BPM",
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Anlık Kalp Atışı",
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "📈 BPM Trend (Son 10 ölçüm)",
                style: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  backgroundColor: Colors.transparent,
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget:
                            (value, _) => Text(
                              '${value.toInt()}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: manager.bpmData,
                      isCurved: true,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      color: Colors.redAccent,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "🕒 Ölçüm Geçmişi (Son 5)",
                style: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                itemCount: manager.bpmData.length,
                itemBuilder: (context, index) {
                  final bpm = manager.bpmData[index].y.toInt();
                  final time = bpmData[index].x.toInt();
                  return Text(
                    "⏱ $time sn → $bpm BPM",
                    style: const TextStyle(color: Colors.white60),
                  );
                },
              ),
            ),
            if (bpmData.length > 1) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "📊 Özet",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
              Text("🧠 Ortalama: ${manager.average.toStringAsFixed(1)} BPM"),
              Text("📈 Maksimum: ${manager.max} BPM"),
              Text("📉 Minimum: ${manager.min} BPM"),
              Text("🧾 Ölçüm Sayısı: ${bpmData.length}"),
            ],
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: "reminderSet",
            onPressed: () => _selectTimeAndScheduleNotification(context),
            backgroundColor: Colors.orange,
            child: const Icon(Icons.alarm),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: "reminderClear",
            onPressed: () => _cancelNotifications(context),
            backgroundColor: Colors.redAccent,
            child: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
