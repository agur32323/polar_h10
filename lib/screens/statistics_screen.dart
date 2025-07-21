import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:uyg/services/db_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<int> bpmHistory = [];

  @override
  void initState() {
    super.initState();
    _loadBpmData();
  }

  Future<void> _loadBpmData() async {
    final bpmList = await DBService.getLast20Measurements();
    setState(() => bpmHistory = bpmList);
  }

  int get average =>
      bpmHistory.isNotEmpty
          ? (bpmHistory.reduce((a, b) => a + b) / bpmHistory.length).round()
          : 0;

  int get maxBpm =>
      bpmHistory.isNotEmpty ? bpmHistory.reduce((a, b) => a > b ? a : b) : 0;

  int get minBpm =>
      bpmHistory.isNotEmpty ? bpmHistory.reduce((a, b) => a < b ? a : b) : 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      appBar: AppBar(
        title: const Text("İstatistikler"),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child:
            bpmHistory.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                  children: [
                    const Text(
                      "📈 Son 20 Ölçüm BPM Trend",
                      style: TextStyle(color: Colors.white, fontSize: 22),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(height: 200, child: _buildLineChart()),

                    const SizedBox(height: 32),
                    const Text(
                      "📊 BPM Sütun Grafiği",
                      style: TextStyle(color: Colors.white, fontSize: 22),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(height: 200, child: _buildBarChart()),

                    const SizedBox(height: 32),
                    const Text(
                      "🧩 BPM Dağılımı (Düşük / Normal / Yüksek)",
                      style: TextStyle(color: Colors.white, fontSize: 22),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(height: 250, child: _buildPieChart()),

                    const SizedBox(height: 32),
                    _buildStatTile("Ortalama BPM", average.toString()),
                    _buildStatTile("Maksimum BPM", maxBpm.toString()),
                    _buildStatTile("Minimum BPM", minBpm.toString()),
                  ],
                ),
      ),
    );
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt() + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: Colors.redAccent,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: Colors.red.withOpacity(0.3),
            ),
            dotData: FlDotData(show: true),
            spots: List.generate(
              bpmHistory.length,
              (i) => FlSpot(i.toDouble(), bpmHistory[i].toDouble()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt() + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                );
              },
              reservedSize: 24,
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          bpmHistory.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: bpmHistory[i].toDouble(),
                color: Colors.greenAccent,
                width: 10,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    int low = bpmHistory.where((bpm) => bpm < 60).length;
    int normal = bpmHistory.where((bpm) => bpm >= 60 && bpm <= 100).length;
    int high = bpmHistory.where((bpm) => bpm > 100).length;
    final total = bpmHistory.length;

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: low.toDouble(),
            title: 'Düşük\n${(low / total * 100).toStringAsFixed(1)}%',
            color: Colors.blue,
            radius: 60,
            titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          PieChartSectionData(
            value: normal.toDouble(),
            title: 'Normal\n${(normal / total * 100).toStringAsFixed(1)}%',
            color: Colors.green,
            radius: 60,
            titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          PieChartSectionData(
            value: high.toDouble(),
            title: 'Yüksek\n${(high / total * 100).toStringAsFixed(1)}%',
            color: Colors.red,
            radius: 60,
            titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
        sectionsSpace: 4,
        centerSpaceRadius: 40,
      ),
    );
  }

  Widget _buildStatTile(String title, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
