import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class PersonalCareScreen extends StatefulWidget {
  @override
  _PersonalCareScreenState createState() => _PersonalCareScreenState();
}

class _PersonalCareScreenState extends State<PersonalCareScreen> {
  static const healthChannel = MethodChannel('com.uyg/health');

  int steps = 0;
  double calories = 0.0;
  double moveCalories = 0.0;
  int exerciseMinutes = 0;

  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _requestPermissions().then((_) => fetchHealthData());
  }

  Future<void> _requestPermissions() async {
    try {
      await healthChannel.invokeMethod('requestAuthorization');
    } catch (e) {
      print('Health izin hatası: $e');
    }

    if (!await Permission.notification.isGranted) {
      await Permission.notification.request();
    }

    if (!await Permission.location.isGranted) {
      await Permission.location.request();
    }
    final adapterState = FlutterBluePlus.adapterStateNow;
    if (adapterState != BluetoothAdapterState.on) {
      await openAppSettings();
    }
  }

  Future<void> fetchHealthData() async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final result = await healthChannel.invokeMethod<Map>(
        'fetchHealthData',
        dateStr,
      );
      if (result != null) {
        setState(() {
          steps = result['steps'] ?? 0;
          calories = (result['calories'] ?? 0.0).toDouble();
          moveCalories = (result['moveCalories'] ?? 0.0).toDouble();
          exerciseMinutes = result['exerciseMinutes'] ?? 0;
        });
      }
    } catch (e) {
      print('Hata: $e');
    }
  }

  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      fetchHealthData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkBlue = const Color(0xFF0D1B2A);
    final cardColor = const Color(0xFF1B263B);
    final textColor = Colors.indigo[100] ?? Colors.white;

    return Scaffold(
      backgroundColor: Colors.indigo[900],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Kişisel Bakımım', style: TextStyle(color: Colors.black)),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: textColor),
            onPressed: () => selectDate(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('d MMMM y', 'tr_TR').format(selectedDate),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoTile(
              "👣 Toplam Adım",
              "$steps adım",
              cardColor,
              textColor,
            ),
            _buildInfoTile(
              "🔥 Kalori",
              "${calories.toStringAsFixed(1)} kcal",
              cardColor,
              textColor,
            ),
            _buildInfoTile(
              "⚡ Hareket",
              "${moveCalories.toStringAsFixed(1)}/330 kcal",
              cardColor,
              textColor,
            ),
            _buildInfoTile(
              "🏋️ Egzersiz",
              "$exerciseMinutes/30 dk",
              cardColor,
              textColor,
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Aktivite Halkaları",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildActivityRings(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    String title,
    String value,
    Color bgColor,
    Color txtColor,
  ) {
    return Card(
      color: bgColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Text(title, style: TextStyle(fontSize: 16, color: txtColor)),
        trailing: Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w500, color: txtColor),
        ),
      ),
    );
  }

  Widget _buildActivityRings() {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildSingleRing(moveCalories / 330, Colors.red, 140),
              _buildSingleRing(exerciseMinutes / 30, Colors.green, 110),
              _buildSingleRing(calories / 500, Colors.orange, 80),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildRingLabel("Hareket", Colors.red),
            _buildRingLabel("Egzersiz", Colors.green),
            _buildRingLabel("Kalori", Colors.orange),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleRing(double progress, Color color, double radius) {
    progress = progress.clamp(0.0, 1.0);
    return CustomPaint(
      painter: RingPainter(progress, color),
      size: Size(radius, radius),
    );
  }

  Widget _buildRingLabel(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 14, color: Colors.white)),
      ],
    );
  }
}

class RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  RingPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 10.0;
    final rect = Offset.zero & size;
    final bgPaint =
        Paint()
          ..color = color.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;
    final fgPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 3.14, 3.14, false, bgPaint);
    canvas.drawArc(rect, 3.14, 3.14 * progress, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
