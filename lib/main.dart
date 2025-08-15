import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// UUIDs ini harus SAMA PERSIS dengan yang ada di kode ESP32
final Guid SERVICE_UUID = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
final Guid CHARACTERISTIC_UUID = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");

void main() {
  runApp(const DoorLockApp());
}

class DoorLockApp extends StatelessWidget {
  const DoorLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Door Lock App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DoorLockPage(),
    );
  }
}

class DoorLockPage extends StatefulWidget {
  const DoorLockPage({super.key});

  @override
  State<DoorLockPage> createState() => _DoorLockPageState();
}

class _DoorLockPageState extends State<DoorLockPage> {
  // GANTI DENGAN MAC ADDRESS IPHONE ANDA
  final String _targetDeviceAddress = "AA:BB:CC:DD:EE:FF"; 

  bool isLocked = true;
  BluetoothDevice? _targetDevice;
  BluetoothCharacteristic? _targetCharacteristic;
  String _connectionStatus = "Disconnected";

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() {
    setState(() {
      _connectionStatus = "Scanning for devices...";
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        // Di iOS, alamat MAC tidak diekspos, jadi kita cari berdasarkan nama
        // Pastikan nama di ESP32 Anda unik dan cocok
        if (r.device.platformName == 'ESP32_Door_Lock') {
          _targetDevice = r.device;
          _connectToDevice();
          FlutterBluePlus.stopScan();
          break;
        }
      }
    });
  }

  void _connectToDevice() async {
    if (_targetDevice == null) return;

    setState(() {
      _connectionStatus = "Connecting...";
    });

    await _targetDevice!.connect();

    setState(() {
      _connectionStatus = "Connected! Discovering services...";
    });

    List<BluetoothService> services = await _targetDevice!.discoverServices();
    for (var service in services) {
      if (service.uuid == SERVICE_UUID) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid == CHARACTERISTIC_UUID) {
            _targetCharacteristic = characteristic;
            setState(() {
              _connectionStatus = "Ready to use!";
            });
            return;
          }
        }
      }
    }
  }

  void _sendCommand(String command) async {
    if (_targetCharacteristic == null) return;
    
    // Mengubah string menjadi list of bytes
    List<int> bytes = utf8.encode(command);
    await _targetCharacteristic!.write(bytes);
    print("Sent command: $command");
  }

  void toggleLock() {
    if (_targetCharacteristic == null) {
      print("Not connected to any device.");
      return;
    }

    setState(() {
      isLocked = !isLocked;
      String command = isLocked ? "off" : "on";
      _sendCommand(command);
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = _targetCharacteristic != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Door Lock Controller')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_connectionStatus),
            const SizedBox(height: 20),
            Icon(
              isLocked ? Icons.lock : Icons.lock_open,
              size: 100,
              color: isLocked ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isConnected ? toggleLock : null, // Tombol non-aktif jika tidak terhubung
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              child: Text(isLocked ? 'Unlock' : 'Lock', style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}