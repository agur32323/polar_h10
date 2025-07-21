import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class EKGResult {
  final String classification;
  final double heartRate;
  final DateTime time;
  final List<double> voltages;
  EKGResult({
    required this.time,
    required this.classification,
    required this.heartRate,
    required this.voltages,
  });
}

class AppleEKGScreen extends StatefulWidget {
  const AppleEKGScreen({super.key});
  @override
  State<AppleEKGScreen> createState() => _AppleEKGScreenState();
}

class _AppleEKGScreenState extends State<AppleEKGScreen> {
  static const platform = MethodChannel('com.bitirme/ekg');
  List<Map<String, dynamic>> ekgResults = [];
  final List<GlobalKey> _chartKeys = [];

  @override
  void initState() {
    super.initState();
    _fetchEKGData();
  }

  Future<void> _fetchEKGData() async {
    try {
      final List<dynamic> results = await platform.invokeMethod('getEKG');
      setState(() {
        ekgResults =
            results
                .cast<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
        _chartKeys
          ..clear()
          ..addAll(List.generate(ekgResults.length, (_) => GlobalKey()));
      });
    } catch (e) {
      debugPrint('EKG verisi alınamadı: $e');
    }
  }

  Future<void> _exportPDF(
    GlobalKey chartKey,
    String fileName,
    String comment,
  ) async {
    try {
      final boundary =
          chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final imageBytes = byteData!.buffer.asUint8List();

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build:
              (_) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '🩺 EKG Ölçüm Raporu',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Image(pw.MemoryImage(imageBytes), height: 200),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    '🧠 Yapay Zeka Yorumu',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(comment, style: pw.TextStyle(fontSize: 12)),
                ],
              ),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: '$fileName.pdf',
      );
    } catch (e) {
      debugPrint('PDF oluşturma hatası: $e');
    }
  }

  Future<void> _analyzeEKG(EKGResult result, GlobalKey chartKey) async {
    try {
      final response = await http.post(
        Uri.parse('https://ekg-gpt4-api-18.onrender.com/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'voltages': result.voltages.take(30).toList(),
          'heartRate': result.heartRate,
        }),
      );

      final comment =
          response.statusCode == 200
              ? jsonDecode(response.body)['comment']
              : 'Hata Kodu: ${response.statusCode}\nCevap: ${response.body}';

      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text("🧠 Yapay Zeka Yorumu"),
              content: SingleChildScrollView(child: Text(comment)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Tamam"),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("PDF Kaydet"),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _exportPDF(
                      chartKey,
                      DateFormat('yyyyMMdd_HHmm').format(result.time),
                      comment,
                    );
                  },
                ),
              ],
            ),
      );
    } catch (e) {
      debugPrint('❌ Yorumlama hatası: $e');
    }
  }

  Widget _buildChart(List<double> voltages, GlobalKey key) {
    final spots = List.generate(
      voltages.length,
      (i) => FlSpot(i / 300, voltages[i]),
    );
    final minY = voltages.reduce((a, b) => a < b ? a : b);
    final maxY = voltages.reduce((a, b) => a > b ? a : b);

    return RepaintBoundary(
      key: key,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: voltages.length * 2.0,
          height: 200,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  barWidth: 2,
                  color: Colors.redAccent,
                  dotData: FlDotData(show: false),
                ),
              ],
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 5,
                    getTitlesWidget:
                        (value, _) => Text(
                          "${value.toStringAsFixed(1)}s",
                          style: const TextStyle(fontSize: 10),
                        ),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🩺 EKG Ölçümleri"),
        backgroundColor: Colors.indigo,
      ),
      body:
          ekgResults.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: ekgResults.length,
                itemBuilder: (context, index) {
                  final ekg = ekgResults[index];
                  final date = DateTime.parse(ekg['date']);
                  final voltages = List<double>.from(ekg['voltages']);
                  final chartKey = _chartKeys[index];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('dd MMMM HH:mm', 'tr_TR').format(date),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildChart(voltages, chartKey),
                          const SizedBox(height: 12),
                          Text("Nabız: ${ekg['averageHeartRate']} bpm"),
                          Text("Sınıflandırma: ${ekg['classification']}"),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: const Icon(Icons.auto_awesome),
                              tooltip: "Yapay Zeka Yorumu",
                              onPressed:
                                  () => _analyzeEKG(
                                    EKGResult(
                                      time: date,
                                      classification: ekg['classification'],
                                      heartRate:
                                          (ekg['averageHeartRate'] as num)
                                              .toDouble(),
                                      voltages: voltages,
                                    ),
                                    chartKey,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
