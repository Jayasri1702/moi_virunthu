import 'dart:io';
import 'dart:typed_data'; // ✅ ADD THIS IMPORT
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThermalPrinterService {
  static final ThermalPrinterService _instance = ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();

  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;
  BluetoothDevice? _connectedDevice;

  // ✅ Remember last used printer
  static const String _lastPrinterKey = 'last_printer_address';

  /// Check if printer is connected
  Future<bool> isConnected() async {
    try {
      return await _bluetooth.isConnected ?? false;
    } catch (e) {
      print('❌ Error checking connection: $e');
      return false;
    }
  }

  /// Request Bluetooth permissions
  Future<bool> requestPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      bool allGranted = statuses.values.every((status) => status.isGranted);

      if (!allGranted) {
        print('⚠️ Some permissions not granted');
      }

      return allGranted;
    } catch (e) {
      print('❌ Error requesting permissions: $e');
      return false;
    }
  }

  /// Get list of paired Bluetooth devices
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      bool permissionsGranted = await requestPermissions();
      if (!permissionsGranted) {
        return [];
      }

      List<BluetoothDevice> devices = await _bluetooth.getBondedDevices();
      print('📱 Found ${devices.length} paired devices');
      return devices;
    } catch (e) {
      print('❌ Error getting paired devices: $e');
      return [];
    }
  }

  /// Connect to printer
  Future<bool> connect(BluetoothDevice device) async {
    try {
      print('🔌 Connecting to ${device.name}...');

      bool? isConnected = await _bluetooth.isConnected;
      if (isConnected == true) {
        await _bluetooth.disconnect();
        await Future.delayed(const Duration(seconds: 1));
      }

      await _bluetooth.connect(device);
      _connectedDevice = device;

      print('✅ Connected to ${device.name}');
      return true;
    } catch (e) {
      print('❌ Connection error: $e');
      return false;
    }
  }

  /// Disconnect from printer
  Future<void> disconnect() async {
    try {
      await _bluetooth.disconnect();
      _connectedDevice = null;
      print('✅ Disconnected');
    } catch (e) {
      print('❌ Error disconnecting: $e');
    }
  }

  /// Print PDF file directly to thermal printer
  Future<bool> printPdfFile(File pdfFile) async {
    try {
      bool connected = await isConnected();
      if (!connected) {
        print('❌ Printer not connected');
        return false;
      }

      print('🖨️ Printing PDF: ${pdfFile.path}');

      // Read PDF bytes
      List<int> bytes = await pdfFile.readAsBytes();

      // ✅ FIXED: Convert List<int> to Uint8List
      Uint8List uint8bytes = Uint8List.fromList(bytes);

      // Send to printer
      await _bluetooth.writeBytes(uint8bytes);

      // Cut paper
      _bluetooth.paperCut();

      print('✅ Print job sent');
      return true;
    } catch (e) {
      print('❌ Print error: $e');
      return false;
    }
  }

  /// Show printer selection dialog
  Future<BluetoothDevice?> showPrinterSelectionDialog(BuildContext context) async {
    bool permissionsGranted = await requestPermissions();
    if (!permissionsGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Bluetooth permissions required'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }

    List<BluetoothDevice> devices = await getPairedDevices();

    if (devices.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No paired Bluetooth devices found. Please pair your printer first.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return null;
    }

    if (context.mounted) {
      return await showDialog<BluetoothDevice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Select Printer',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  leading: const Icon(Icons.print, color: Colors.blue),
                  title: Text(device.name ?? 'Unknown Device'),
                  subtitle: Text(device.address ?? ''),
                  onTap: () => Navigator.pop(context, device),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
          ],
        ),
      );
    }

    return null;
  }

  /// Connect and print in one go
  Future<bool> connectAndPrint(BuildContext context, File pdfFile) async {
    try {
      // Check if already connected
      bool connected = await isConnected();

      if (!connected) {
        // ✅ Try to auto-connect to last used printer
        String? lastPrinterAddress = await _getLastPrinterAddress();
        BluetoothDevice? device;

        if (lastPrinterAddress != null) {
          List<BluetoothDevice> devices = await getPairedDevices();
          device = devices.firstWhere(
                (d) => d.address == lastPrinterAddress,
            orElse: () => devices.first,
          );

          // Try auto-connect
          bool autoConnected = await connect(device);
          if (!autoConnected) {
            device = null; // Reset if auto-connect failed
          }
        }

        // If no auto-connect, show selection dialog
        if (device == null) {
          device = await showPrinterSelectionDialog(context);

          if (device == null) {
            return false; // User cancelled
          }

          // Connect to selected printer
          bool connectSuccess = await connect(device);
          if (!connectSuccess) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('❌ Failed to connect to ${device.name}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return false;
          }
        }

        // ✅ Save last used printer
        await _saveLastPrinterAddress(device.address ?? '');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Connected to ${device.name}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }

      // Print the PDF
      bool printSuccess = await printPdfFile(pdfFile);

      if (printSuccess && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Receipt sent to printer'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      return printSuccess;
    } catch (e) {
      print('❌ Error in connectAndPrint: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Print failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  // ✅ Save last used printer address
  Future<void> _saveLastPrinterAddress(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastPrinterKey, address);
    } catch (e) {
      print('Error saving last printer: $e');
    }
  }

  // ✅ Get last used printer address
  Future<String?> _getLastPrinterAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastPrinterKey);
    } catch (e) {
      print('Error getting last printer: $e');
      return null;
    }
  }
}