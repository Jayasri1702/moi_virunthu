// File: lib/services/thermal_printer_service.dart
// UNIFIED - USB (Priority) + Bluetooth (Fallback)

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:permission_handler/permission_handler.dart';

// USB Device Info
class UsbDeviceInfo {
  final int vid;
  final int pid;
  final String deviceName;
  final String productName;
  final String manufacturerName;
  final String serialNumber;

  UsbDeviceInfo({
    required this.vid,
    required this.pid,
    required this.deviceName,
    required this.productName,
    required this.manufacturerName,
    required this.serialNumber,
  });

  factory UsbDeviceInfo.fromMap(Map<dynamic, dynamic> map) {
    return UsbDeviceInfo(
      vid: map['vid'] as int,
      pid: map['pid'] as int,
      deviceName: map['deviceName'] as String,
      productName: map['productName'] as String,
      manufacturerName: map['manufacturerName'] as String,
      serialNumber: map['serialNumber'] as String,
    );
  }
}

class ThermalPrinterService {
  static final ThermalPrinterService _instance = ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();

  // USB
  static const MethodChannel _usbChannel = MethodChannel('usb_printer_native');
  UsbDeviceInfo? _connectedUsbDevice;

  // Bluetooth
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;
  BluetoothDevice? _connectedBluetoothDevice;

  static const String _lastUsbPrinterKey = 'last_usb_printer';
  static const String _lastBluetoothPrinterKey = 'last_bluetooth_printer';

  // ==================== CONNECTION METHODS ====================

  Future<bool> isUsbConnected() async {
    try {
      final bool? connected = await _usbChannel.invokeMethod('isConnected');
      return connected ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isBluetoothConnected() async {
    try {
      return await _bluetooth.isConnected ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<List<UsbDeviceInfo>> getUsbDevices() async {
    try {
      final List<dynamic>? devices = await _usbChannel.invokeMethod('getUsbDevices');
      if (devices == null) return [];
      return devices.map((d) => UsbDeviceInfo.fromMap(d)).toList();
    } catch (e) {
      print('❌ Error getting USB devices: $e');
      return [];
    }
  }

  Future<List<BluetoothDevice>> getBluetoothDevices() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      bool allGranted = statuses.values.every((status) => status.isGranted);
      if (!allGranted) return [];

      List<BluetoothDevice> devices = await _bluetooth.getBondedDevices();
      print('📱 Found ${devices.length} Bluetooth devices');
      return devices;
    } catch (e) {
      print('❌ Error getting Bluetooth devices: $e');
      return [];
    }
  }

  Future<bool> connectUsb(UsbDeviceInfo device) async {
    try {
      print('🔌 Connecting to USB: ${device.productName}...');

      final bool? success = await _usbChannel.invokeMethod('connectUsb', {
        'vid': device.vid,
        'pid': device.pid,
      });

      if (success == true) {
        _connectedUsbDevice = device;
        await _saveLastUsbPrinter(device.vid.toString(), device.pid.toString());
        print('✅ USB Connected');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ USB connection error: $e');
      return false;
    }
  }

  Future<bool> connectBluetooth(BluetoothDevice device) async {
    try {
      print('🔌 Connecting to Bluetooth: ${device.name}...');

      bool? isConnected = await _bluetooth.isConnected;
      if (isConnected == true) {
        await _bluetooth.disconnect();
        await Future.delayed(const Duration(seconds: 1));
      }

      await _bluetooth.connect(device);
      _connectedBluetoothDevice = device;
      await _saveLastBluetoothPrinter(device.address ?? '');
      print('✅ Bluetooth Connected');
      return true;
    } catch (e) {
      print('❌ Bluetooth connection error: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _usbChannel.invokeMethod('disconnect');
      _connectedUsbDevice = null;

      await _bluetooth.disconnect();
      _connectedBluetoothDevice = null;

      print('✅ Disconnected');
    } catch (e) {
      print('❌ Disconnect error: $e');
    }
  }

  // ==================== IMAGE CONVERSION ====================

  List<int> _convertImageToEscPos(Uint8List imageBytes) {
    try {
      print('🔄 Starting image conversion...');

      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        print('❌ Failed to decode image');
        return [];
      }

      print('📏 Original size: ${image.width}x${image.height}');

      int targetWidth = 576; // 80mm printer
      image = img.copyResize(
        image,
        width: targetWidth,
        interpolation: img.Interpolation.cubic,
      );

      print('📏 Resized to: ${image.width}x${image.height}');

      // Trim white space
      image = img.trim(image, mode: img.TrimMode.transparent);

      // Convert to grayscale
      image = img.grayscale(image);

      // Enhance contrast
      image = img.adjustColor(image, contrast: 1.4, brightness: 1.05);

      // Sharpen
      image = img.convolution(image, filter: [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0
      ]);

      print('✨ Enhanced image quality');

      List<int> escPosData = [];
      int width = image.width;
      int height = image.height;

      // Initialize printer
      escPosData.addAll([0x1B, 0x40]); // ESC @
      escPosData.addAll([0x1B, 0x33, 0x00]); // Line spacing 0

      // Print in 24-pixel chunks
      int chunkCount = 0;
      for (int y = 0; y < height; y += 24) {
        chunkCount++;

        escPosData.addAll([0x1B, 0x2A, 33]); // ESC * 33
        escPosData.add(width & 0xFF);
        escPosData.add((width >> 8) & 0xFF);

        for (int x = 0; x < width; x++) {
          for (int k = 0; k < 3; k++) {
            int slice = 0;
            for (int b = 0; b < 8; b++) {
              int py = y + (k * 8) + b;
              if (py < height) {
                img.Pixel pixel = image.getPixel(x, py);
                int gray = pixel.r.toInt();
                if (gray < 128) {
                  slice |= (1 << (7 - b));
                }
              }
            }
            escPosData.add(slice);
          }
        }

        escPosData.add(0x0A); // Line feed
      }

      print('✅ Generated ${escPosData.length} bytes in $chunkCount chunks');

      // Reset line spacing
      escPosData.addAll([0x1B, 0x32]); // ESC 2

      return escPosData;
    } catch (e) {
      print('❌ Image conversion error: $e');
      return [];
    }
  }

  // ==================== PRINT METHODS ====================

  Future<bool> printImageBytesUsb(Uint8List imageBytes) async {
    try {
      if (!await isUsbConnected()) {
        print('❌ USB not connected');
        return false;
      }

      print('🖨️ USB: Converting image...');
      List<int> escPosData = _convertImageToEscPos(imageBytes);

      if (escPosData.isEmpty) return false;

      // ✅ FIX: Add more line feeds before cut to ensure signature section prints
      escPosData.addAll([0x0A, 0x0A, 0x0A, 0x0A, 0x0A]); // 5 line feeds
      escPosData.addAll([0x1D, 0x56, 0x00]); // Full cut

      print('🖨️ USB: Sending ${escPosData.length} bytes...');

      final bool? success = await _usbChannel.invokeMethod('printRawBytes', {
        'data': Uint8List.fromList(escPosData),
      });

      if (success == true) {
        print('✅ USB Print successful');

        // ✅ Increased delay to ensure paper feed completes
        await Future.delayed(const Duration(milliseconds: 300));

        return true;
      }

      return false;
    } catch (e) {
      print('❌ USB Print error: $e');
      return false;
    }
  }

  Future<bool> printImageBytesBluetooth(Uint8List imageBytes) async {
    try {
      if (!await isBluetoothConnected()) {
        print('❌ Bluetooth not connected');
        return false;
      }

      print('🖨️ Bluetooth: Converting image...');
      List<int> escPosData = _convertImageToEscPos(imageBytes);

      if (escPosData.isEmpty) return false;

      print('🖨️ Bluetooth: Sending ${escPosData.length} bytes...');

      // Send in 4KB chunks
      const int chunkSize = 4096;
      for (int i = 0; i < escPosData.length; i += chunkSize) {
        int end = (i + chunkSize < escPosData.length)
            ? i + chunkSize
            : escPosData.length;

        await _bluetooth.writeBytes(
            Uint8List.fromList(escPosData.sublist(i, end))
        );
      }

      print('✅ Bluetooth: All data sent');

      // ✅ FIX: Add more line feeds before cut to ensure signature section prints
      await _bluetooth.printNewLine();
      await _bluetooth.printNewLine();
      await _bluetooth.printNewLine();
      await _bluetooth.printNewLine();
      await _bluetooth.printNewLine();

      // Cut
      await _bluetooth.paperCut();

      print('✅ Bluetooth Print completed');
      return true;

    } catch (e) {
      print('❌ Bluetooth Print error: $e');
      return false;
    }
  }

  // ==================== SMART CONNECT & PRINT ====================

  Future<bool> connectAndPrintImage(BuildContext context, Uint8List imageBytes) async {
    try {
      print('🔌 ========== SMART PRINT JOB STARTED ==========');

      // ✅ PRIORITY 1: Try USB first
      print('🔌 Step 1: Checking USB...');

      if (await isUsbConnected()) {
        print('✅ USB already connected, printing...');
        bool success = await printImageBytesUsb(imageBytes);

        if (success) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Printed via USB'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
          return true;
        }
      }

      // Try to connect to USB
      List<UsbDeviceInfo> usbDevices = await getUsbDevices();
      print('🔌 Found ${usbDevices.length} USB devices');

      if (usbDevices.isNotEmpty) {
        // Try auto-connect to last USB printer
        String? lastVid = await _getLastUsbVid();
        String? lastPid = await _getLastUsbPid();
        UsbDeviceInfo? usbDevice;

        if (lastVid != null && lastPid != null) {
          try {
            usbDevice = usbDevices.firstWhere(
                  (d) => d.vid.toString() == lastVid && d.pid.toString() == lastPid,
            );
            if (await connectUsb(usbDevice)) {
              print('✅ USB auto-connected');
              bool success = await printImageBytesUsb(imageBytes);

              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Printed via USB'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              return success;
            }
          } catch (e) {
            // Continue to manual selection
          }
        }

        // Connect to first USB device
        usbDevice = usbDevices[0];
        if (await connectUsb(usbDevice)) {
          print('✅ USB connected to ${usbDevice.productName}');
          bool success = await printImageBytesUsb(imageBytes);

          if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Printed via USB: ${usbDevice.productName}'),
                backgroundColor: Colors.green,
              ),
            );
          }
          return success;
        }
      }

      // ✅ PRIORITY 2: Fallback to Bluetooth
      print('🔌 Step 2: USB not available, trying Bluetooth...');

      if (await isBluetoothConnected()) {
        print('✅ Bluetooth already connected, printing...');
        bool success = await printImageBytesBluetooth(imageBytes);

        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Printed via Bluetooth'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        return success;
      }

      // Try to connect to Bluetooth
      List<BluetoothDevice> btDevices = await getBluetoothDevices();
      print('🔌 Found ${btDevices.length} Bluetooth devices');

      if (btDevices.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No USB or Bluetooth printer found'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return false;
      }

      // Try auto-connect to last Bluetooth printer
      String? lastBtAddress = await _getLastBluetoothAddress();
      BluetoothDevice? btDevice;

      if (lastBtAddress != null) {
        try {
          btDevice = btDevices.firstWhere((d) => d.address == lastBtAddress);
          if (await connectBluetooth(btDevice)) {
            print('✅ Bluetooth auto-connected');
            bool success = await printImageBytesBluetooth(imageBytes);

            if (success && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Printed via Bluetooth'),
                  backgroundColor: Colors.blue,
                ),
              );
            }
            return success;
          }
        } catch (e) {
          // Continue to manual selection
        }
      }

      // Show Bluetooth device selection
      btDevice = await _showBluetoothSelectionDialog(context, btDevices);
      if (btDevice == null) return false;

      if (await connectBluetooth(btDevice)) {
        print('✅ Bluetooth connected to ${btDevice.name}');
        bool success = await printImageBytesBluetooth(imageBytes);

        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Printed via Bluetooth: ${btDevice.name}'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        return success;
      }

      // If all failed
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to connect to any printer'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;

    } catch (e) {
      print('❌ Error in connectAndPrintImage: $e');

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

  Future<bool> connectAndPrint(BuildContext context, File file) async {
    try {
      Uint8List imageBytes = await file.readAsBytes();
      return await connectAndPrintImage(context, imageBytes);
    } catch (e) {
      print('❌ Error reading file: $e');
      return false;
    }
  }

  // ==================== SELECTION DIALOGS ====================

  Future<BluetoothDevice?> _showBluetoothSelectionDialog(
      BuildContext context,
      List<BluetoothDevice> devices,
      ) async {
    if (!context.mounted) return null;

    return await showDialog<BluetoothDevice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Select Bluetooth Printer',
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
                leading: const Icon(Icons.bluetooth, color: Colors.blue),
                title: Text(device.name ?? 'Unknown'),
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

  // ==================== STORAGE ====================

  Future<void> _saveLastUsbPrinter(String vid, String pid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_lastUsbPrinterKey}_vid', vid);
    await prefs.setString('${_lastUsbPrinterKey}_pid', pid);
  }

  Future<String?> _getLastUsbVid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_lastUsbPrinterKey}_vid');
  }

  Future<String?> _getLastUsbPid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_lastUsbPrinterKey}_pid');
  }

  Future<void> _saveLastBluetoothPrinter(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBluetoothPrinterKey, address);
  }

  Future<String?> _getLastBluetoothAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastBluetoothPrinterKey);
  }
}