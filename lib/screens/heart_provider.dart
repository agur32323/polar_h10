import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class HeartProvider with ChangeNotifier {
  int? _bpm;
  String? _deviceName;
  BluetoothDevice? _device;

  int? get bpm => _bpm;
  String? get deviceName => _deviceName;
  BluetoothDevice? get device => _device;

  void updateBpm(int value) {
    _bpm = value;
    notifyListeners();
  }

  void setDevice(BluetoothDevice device) {
    _device = device;
    _deviceName = device.name;
    notifyListeners();
  }

  void clear() {
    _bpm = null;
    _deviceName = null;
    _device = null;
    notifyListeners();
  }
}
