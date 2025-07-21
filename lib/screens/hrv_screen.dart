import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;

class HRVScreen extends StatefulWidget {
  const HRVScreen({super.key});

  @override
  State<HRVScreen> createState() => _HRVScreenState();
}

class _HRVScreenState extends State<HRVScreen> {
  List<int> rrIntervals = [];
  BluetoothDevice? connectedDevice;

  final Guid heartRateServiceUUID = Guid(
    "0000180d-0000-1000-8000-00805f9b34fb",
  );
  final Guid heartRateMeasurementUUID = Guid(
    "00002a37-0000-1000-8000-00805f9b34fb",
  );

  @override
  void initState() {
    super.initState();
    _connectToDeviceAndListenRR();
  }

  void _connectToDeviceAndListenRR() async {
    if (connectedDevice != null) return;

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) async {
      for (var r in results) {
        if (r.device.name.toLowerCase().contains("polar")) {
          await FlutterBluePlus.stopScan();
          try {
            await r.device.connect();
          } catch (_) {}

          connectedDevice = r.device;
          final services = await connectedDevice!.discoverServices();

          for (var service in services) {
            if (service.uuid == heartRateServiceUUID) {
              for (var char in service.characteristics) {
                if (char.uuid == heartRateMeasurementUUID) {
                  await char.setNotifyValue(true);
                  char.value.listen((value) => _parseRRIntervals(value));
                }
              }
            }
          }
          break;
        }
      }
    });
  }

  Future<void> _analyzeRRWithAI() async {
    if (rrIntervals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Yorumlama için yeterli RR verisi yok."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://ekg-gpt4-api-18.onrender.com/analyze_hrv_rr'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "rr_intervals": rrIntervals,
          "sdnn": calculateSDNN(rrIntervals),
          "rmssd": calculateRMSSD(rrIntervals),
        }),
      );

      final interpretation =
          response.statusCode == 200
              ? jsonDecode(response.body)['hrv_interpretation']
              : 'Hata Kodu: ${response.statusCode}\nCevap: ${response.body}';

      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text("🧠 Yapay Zeka Yorumu"),
              content: Text(interpretation),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Tamam"),
                ),
              ],
            ),
      );
    } catch (e) {
      print("❌ AI yorum hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Yorumlama sırasında hata oluştu."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _parseRRIntervals(List<int> data) {
    if (data.isEmpty || data.length < 2) return;

    int flags = data[0];
    int rrIndex = (flags & 0x10) != 0 ? 2 : 1;
    List<int> extractedRR = [];

    while (rrIndex + 1 < data.length) {
      int rr = (data[rrIndex + 1] << 8) | data[rrIndex];
      extractedRR.add(rr);
      rrIndex += 2;
    }

    setState(() {
      rrIntervals.insertAll(0, extractedRR);
      if (rrIntervals.length > 20) {
        rrIntervals = rrIntervals.sublist(0, 20);
      }
    });
  }

  List<FlSpot> _buildChartData() {
    return List.generate(
      rrIntervals.length,
      (i) => FlSpot(i.toDouble(), rrIntervals[i].toDouble()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      appBar: AppBar(
        title: const Text("HRV & RR Intervals"),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology_alt_outlined),
            tooltip: "Yapay Zeka Yorumu",
            onPressed: _analyzeRRWithAI,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            rrIntervals.isEmpty
                ? const Center(
                  child: Text(
                    "RR verisi okunuyor...",
                    style: TextStyle(color: Colors.white70),
                  ),
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "HRV (Kalp Atım Değişkenliği): Vücudun stres ve iyileşme dengesini gösterir.",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "RR Interval: İki kalp atımı arasındaki milisaniye cinsinden süredir.",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "RMSSD: Kalp atım aralıklarındaki ardışık değişiklikleri ölçer (dinlenme/rahatlama ile ilişkilidir).",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      "SDNN: Kalp atım aralıklarının genel değişkenliğini gösterir (stres ile ilişkilidir).",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          backgroundColor: Colors.transparent,
                          gridData: FlGridData(show: true),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true),
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
                              spots: _buildChartData(),
                              isCurved: true,
                              barWidth: 3,
                              color: Colors.cyanAccent,
                              dotData: FlDotData(show: false),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: rrIntervals.length,
                        itemBuilder: (context, index) {
                          final rr = rrIntervals[index];
                          final seconds = (rr / 1000).toStringAsFixed(2);
                          return Card(
                            color: Colors.white10,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: const Icon(
                                Icons.favorite,
                                color: Colors.redAccent,
                              ),
                              title: Text(
                                "$rr ms",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "$seconds saniye aralık",
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

/// SDNN hesaplama: RR aralıklarının standart sapması
double calculateSDNN(List<int> rr) {
  if (rr.isEmpty) return 0;
  final avg = rr.reduce((a, b) => a + b) / rr.length;
  final squaredDiffs = rr.map((r) => pow(r - avg, 2));
  return sqrt(squaredDiffs.reduce((a, b) => a + b) / rr.length);
}

/// RMSSD hesaplama: RR aralıklarının ardışık farklarının karelerinin ortalaması
double calculateRMSSD(List<int> rr) {
  if (rr.length < 2) return 0;
  final diffs = List.generate(rr.length - 1, (i) => rr[i + 1] - rr[i]);
  final squaredDiffs = diffs.map((d) => d * d);
  return sqrt(squaredDiffs.reduce((a, b) => a + b) / diffs.length);
}
