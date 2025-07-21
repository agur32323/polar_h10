import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:uyg/screens/heart_provider.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  List<ScanResult> _results = [];
  bool _isScanning = false;
  BluetoothDevice? _connectingDevice;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  BluetoothDevice? get _connectedDevice =>
      Provider.of<HeartProvider>(context, listen: false).device;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _startScan();
  }

  void _startScan() {
    _results = [];
    setState(() => _isScanning = true);

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() => _results = results);
      _fadeController.forward();
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _isScanning = false);
    });
  }

  void _connect(BluetoothDevice device) async {
    final heartProvider = Provider.of<HeartProvider>(context, listen: false);
    setState(() => _connectingDevice = device);

    await FlutterBluePlus.stopScan();
    setState(() => _isScanning = false);

    try {
      await device.connect();
    } catch (_) {}

    heartProvider.setDevice(device);

    final services = await device.discoverServices();
    for (var service in services) {
      for (var c in service.characteristics) {
        if (c.properties.notify) {
          await c.setNotifyValue(true);
          c.value.listen((value) {
            if (value.isNotEmpty && mounted) {
              heartProvider.updateBpm(value[1]);
            }
          });
        }
      }
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _connectingDevice = null);
        Navigator.pop(context);
      }
    });
  }

  Widget _buildDeviceCard(ScanResult result, bool isConnected) {
    final device = result.device;
    final isConnecting = _connectingDevice?.id == device.id;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          leading: const Icon(
            Icons.bluetooth,
            color: Color.fromRGBO(26, 35, 126, 1),
          ),
          title: Text(
            device.name.isNotEmpty ? device.name : "(İsimsiz)",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            device.id.toString(),
            style: const TextStyle(fontSize: 12),
          ),
          trailing:
              isConnected
                  ? ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[400],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "✔ Bağlanıldı",
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                  : ElevatedButton(
                    onPressed: isConnecting ? null : () => _connect(device),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child:
                        isConnecting
                            ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text(
                              "Bağlan",
                              style: TextStyle(fontSize: 12),
                            ),
                  ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectedDevice = _connectedDevice;
    final connectedId = connectedDevice?.id;

    final connectedDevices =
        _results.where((r) => r.device.id == connectedId).toList();
    final otherDevices =
        _results.where((r) => r.device.id != connectedId).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4FB),
      appBar: AppBar(
        title: const Text("Bluetooth Tarama"),
        backgroundColor: Colors.indigo[900],
      ),
      body:
          _isScanning
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
              ? const Center(
                child: Text(
                  "🔍 Cihaz bulunamadı",
                  style: TextStyle(fontSize: 16),
                ),
              )
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (connectedDevices.isNotEmpty) ...[
                    const Text(
                      "🔗 Bağlı Cihazlar",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color.from(
                          alpha: 1,
                          red: 0.102,
                          green: 0.137,
                          blue: 0.494,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...connectedDevices.map((r) => _buildDeviceCard(r, true)),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    "📡 Yakındaki Cihazlar",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color.from(
                        alpha: 1,
                        red: 0.102,
                        green: 0.137,
                        blue: 0.494,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...otherDevices.map((r) => _buildDeviceCard(r, false)),
                ],
              ),
    );
  }
}
