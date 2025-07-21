import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:uyg/services/db_service.dart';

class HeartAnalysisScreen extends StatefulWidget {
  const HeartAnalysisScreen({super.key});

  @override
  State<HeartAnalysisScreen> createState() => _HeartAnalysisScreenState();
}

class _HeartAnalysisScreenState extends State<HeartAnalysisScreen> {
  List<int> bpmList = [];
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isAnalyzing = true);
    try {
      final data = await DBService.getLast20Measurements();
      setState(() {
        bpmList = data;
      });
    } catch (e) {
      print("Veri yüklenirken hata oluştu: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Kalp atışı verileri yüklenirken hata oluştu: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  double get average {
    final validBpmList = bpmList.where((bpm) => bpm > 0).toList();
    return validBpmList.isEmpty
        ? 0
        : validBpmList.reduce((a, b) => a + b) / validBpmList.length;
  }

  int get min {
    final validBpmList = bpmList.where((bpm) => bpm > 0).toList();
    if (validBpmList.isEmpty) return 0;
    return validBpmList.reduce((a, b) => a < b ? a : b);
  }

  int get max {
    final validBpmList = bpmList.where((bpm) => bpm > 0).toList();
    if (validBpmList.isEmpty) return 0;
    return validBpmList.reduce((a, b) => a > b ? a : b);
  }

  Future<void> _analyzeHeartWithAI() async {
    final validBpmList = bpmList.where((bpm) => bpm > 0).toList();
    if (validBpmList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Yorumlama için geçerli kalp atışı verisi yok."),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://ekg-gpt4-api-18.onrender.com/analyze_heart'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "bpm_values": validBpmList,
          "min": min,
          "max": max,
          "average": average,
        }),
      );

      if (response.statusCode == 200) {
        final comment = jsonDecode(response.body)['heart_interpretation'];
        _showAIComment(comment);
      } else {
        final errorComment =
            'Hata Kodu: ${response.statusCode}\nCevap: ${response.body}';
        _showAIComment("Hata oluştu:\n$errorComment");
      }
    } catch (e) {
      print("❌ Yapay zeka yorum hatası: $e");
      _showAIComment("Yorum alınırken bir hata oluştu: $e");
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  void _showAIComment(String comment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final List<Widget> commentWidgets = [];
        final lines = comment.split('\n');

        for (var line in lines) {
          if (line.startsWith('**') && line.endsWith(':**')) {
            commentWidgets.add(
              Padding(
                padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                child: Text(
                  line.replaceAll('**', ''),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
            );
          } else if (line.trim().isNotEmpty) {
            commentWidgets.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  line.trim(),
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            );
          }
        }

        return FractionallySizedBox(
          heightFactor: 0.95,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "🧠 Yapay Zeka Yorumu",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20, thickness: 1, color: Colors.grey),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: commentWidgets,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Kapat"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<int> validBpmForChart = bpmList.where((bpm) => bpm > 0).toList();
    double chartMinY = 0;
    double chartMaxY = 120;

    if (validBpmForChart.isNotEmpty) {
      chartMinY = (validBpmForChart.reduce((a, b) => a < b ? a : b).toDouble() -
              10)
          .clamp(30.0, double.infinity);
      chartMaxY =
          (validBpmForChart.reduce((a, b) => a > b ? a : b).toDouble() + 10);
    }

    String minBpmDisplay = min > 0 ? min.toString() : "N/A";

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B4C),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        title: const Text(
          'Kalp  Analizi',
          style: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
        ),
        iconTheme: const IconThemeData(color: Color.fromARGB(255, 0, 0, 0)),
        actions: [
          _isAnalyzing
              ? const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
              : IconButton(
                icon: const Icon(
                  Icons.psychology_alt_outlined,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
                tooltip: "Yapay Zeka Yorumu",
                onPressed: _analyzeHeartWithAI,
              ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            bpmList.isEmpty
                ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "🫀 Son 20 Kalp Atışı",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: LineChart(
                        LineChartData(
                          backgroundColor: Colors.transparent,
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(color: Colors.white30, width: 1),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  if (value % 10 == 0 ||
                                      value == chartMinY ||
                                      value == chartMaxY) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                    );
                                  }
                                  return Container();
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                getTitlesWidget: (value, meta) {
                                  final int index = value.toInt();
                                  if (bpmList.length <= 5 ||
                                      index % 4 == 0 ||
                                      index == bpmList.length - 1) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        (index + 1).toString(),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  }
                                  return Container();
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            getDrawingHorizontalLine:
                                (value) => const FlLine(
                                  color: Colors.white24,
                                  strokeWidth: 0.5,
                                ),
                            getDrawingVerticalLine:
                                (value) => const FlLine(
                                  color: Colors.white24,
                                  strokeWidth: 0.5,
                                ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              isCurved: true,
                              color: Colors.redAccent,
                              barWidth: 3,
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.red.withOpacity(0.3),
                              ),
                              spots:
                                  bpmList
                                      .asMap()
                                      .entries
                                      .map(
                                        (e) => FlSpot(
                                          e.key.toDouble(),
                                          e.value.toDouble(),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ],
                          minX: 0,
                          maxX: bpmList.length.toDouble() - 1,
                          minY: chartMinY,
                          maxY: chartMaxY,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "📊 Özet",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "🔺 Maksimum: ${max} BPM",
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      "🔻 Minimum: $minBpmDisplay BPM",
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      "📈 Ortalama: ${average.toStringAsFixed(1)} BPM",
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "📋 Ölçüm Tablosu",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: bpmList.length,
                        itemBuilder: (context, index) {
                          return Card(
                            color: Colors.indigo[800],
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: ListTile(
                              leading: const Icon(
                                Icons.favorite,
                                color: Colors.pinkAccent,
                              ),
                              title: Text(
                                "${index + 1}. Ölçüm: ${bpmList[index]} BPM",
                                style: const TextStyle(color: Colors.white),
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
