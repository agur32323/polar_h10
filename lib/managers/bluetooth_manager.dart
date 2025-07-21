import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/db_service.dart';

class BluetoothManager extends ChangeNotifier {
  int currentBPM = 0;
  List<FlSpot> bpmData = [];
  int timeIndex = 0;

  final Guid heartRateServiceUUID = Guid(
    "0000180d-0000-1000-8000-00805f9b34fb",
  );
  final Guid heartRateMeasurementCharUUID = Guid(
    "00002a37-0000-1000-8000-00805f9b34fb",
  );

  BluetoothDevice? _connectedDevice;

  Future<void> startScanAndConnect() async {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.name.toLowerCase().contains("polar")) {
          await FlutterBluePlus.stopScan();
          await r.device.connect();
          _connectedDevice = r.device;
          final services = await r.device.discoverServices();

          for (BluetoothService service in services) {
            if (service.uuid == heartRateServiceUUID) {
              for (BluetoothCharacteristic c in service.characteristics) {
                if (c.uuid == heartRateMeasurementCharUUID) {
                  await c.setNotifyValue(true);
                  c.value.listen((value) {
                    if (value.isNotEmpty) {
                      final bpm = value[1];
                      currentBPM = bpm;
                      bpmData.add(FlSpot(timeIndex.toDouble(), bpm.toDouble()));
                      if (bpmData.length > 10) bpmData.removeAt(0);
                      timeIndex++;
                      DBService.insertMeasurement(bpm);
                      notifyListeners();
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

  double get average =>
      bpmData.map((e) => e.y).reduce((a, b) => a + b) / bpmData.length;
  int get max =>
      bpmData.map((e) => e.y).reduce((a, b) => a > b ? a : b).toInt();
  int get min =>
      bpmData.map((e) => e.y).reduce((a, b) => a < b ? a : b).toInt();
}
