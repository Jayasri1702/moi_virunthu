// File: lib/services/thermal_printer_service.dart
// UPDATED - Matches Bluetooth quality

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;

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

  static const MethodChannel _channel = MethodChannel('usb_printer_native');
  static const String _lastPrinterKey = 'last_usb_printer';

  UsbDeviceInfo? _connectedDevice;

  Future<bool> isUsbConnected() async {
    try {
      final bool? connected = await _channel.invokeMethod('isConnected');
      return connected ?? false;
    } catch (e) {
      print('❌ Error checking connection: $e');
      return false;
    }
  }

  Future<List<UsbDeviceInfo>> getUsbDevices() async {
    try {
      final List<dynamic>? devices = await _channel.invokeMethod('getUsbDevices');
      if (devices == null) return [];

      print('🔌 Found ${devices.length} USB devices');
      return devices.map((d) => UsbDeviceInfo.fromMap(d)).toList();
    } catch (e) {
      print('❌ Error getting USB devices: $e');
      return [];
    }
  }

  Future<bool> connectUsb(UsbDeviceInfo device) async {
    try {
      print('🔌 Connecting to ${device.productName}...');

      final bool? success = await _channel.invokeMethod('connectUsb', {
        'vid': device.vid,
        'pid': device.pid,
      });

      if (success == true) {
        _connectedDevice = device;
        await _saveLastPrinterInfo(device.vid.toString(), device.pid.toString());
        print('✅ Connected successfully');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Connection error: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
      _connectedDevice = null;
      print('✅ Disconnected');
    } catch (e) {
      print('❌ Disconnect error: $e');
    }
  }

  // ✅ FIXED - Matches Bluetooth quality
  List<int> _convertImageToEscPos(Uint8List imageBytes) {
    try {
      print('🔄 Starting image conversion...');

      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        print('❌ Failed to decode image');
        return [];
      }

      print('📏 Original size: ${image.width}x${image.height}');

      // ✅ CRITICAL: Use 576 pixels for 80mm printer (matches Bluetooth)
      int targetWidth = 576;

      // ✅ Use cubic interpolation for smoother resizing
      image = img.copyResize(
          image,
          width: targetWidth,
          interpolation: img.Interpolation.cubic
      );

      print('📏 Resized to: ${image.width}x${image.height}');

      // ✅ Trim white space/borders
      image = img.trim(image, mode: img.TrimMode.transparent);

      // Convert to grayscale
      image = img.grayscale(image);

      print('🎨 Converted to grayscale');

      // ✅ Better contrast (1.4 instead of 1.6)
      image = img.adjustColor(image, contrast: 1.4, brightness: 1.05);

      // ✅ Sharpen for clearer text
      image = img.convolution(image, filter: [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0
      ]);

      print('✨ Enhanced image quality');

      List<int> escPosData = [];

      int width = image.width;
      int height = image.height;

      print('🖨️ Generating ESC/POS commands...');

      // Initialize printer
      escPosData.addAll([0x1B, 0x40]); // ESC @ - Initialize printer

      // Set line spacing to 0
      escPosData.addAll([0x1B, 0x33, 0x00]); // ESC 3 0

      // Print in 24-pixel chunks
      int chunkCount = 0;
      for (int y = 0; y < height; y += 24) {
        chunkCount++;

        // ESC * 33 (24-dot double-density)
        escPosData.addAll([0x1B, 0x2A, 33]);

        // Width in little-endian
        escPosData.add(width & 0xFF);
        escPosData.add((width >> 8) & 0xFF);

        // Process each column
        for (int x = 0; x < width; x++) {
          for (int k = 0; k < 3; k++) {
            int slice = 0;
            for (int b = 0; b < 8; b++) {
              int py = y + (k * 8) + b;
              if (py < height) {
                img.Pixel pixel = image.getPixel(x, py);
                int gray = pixel.r.toInt();

                // ✅ Use 128 threshold (matches Bluetooth)
                if (gray < 128) {
                  slice |= (1 << (7 - b));
                }
              }
            }
            escPosData.add(slice);
          }
        }

        // Line feed
        escPosData.add(0x0A);

        if (chunkCount % 10 == 0) {
          print('📊 Processed $chunkCount chunks...');
        }
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

  Future<bool> printImageBytesUsb(Uint8List imageBytes) async {
    try {
      if (!await isUsbConnected()) {
        print('❌ Not connected');
        return false;
      }

      print('🖨️ Converting image...');
      List<int> escPosData = _convertImageToEscPos(imageBytes);

      if (escPosData.isEmpty) {
        print('❌ Conversion failed');
        return false;
      }

      // Add spacing and cut (matches Bluetooth)
      escPosData.addAll([0x0A, 0x0A, 0x0A]); // 3 line feeds
      escPosData.addAll([0x1D, 0x56, 0x00]); // GS V - Full cut

      print('🖨️ Sending ${escPosData.length} bytes...');

      final bool? success = await _channel.invokeMethod('printRawBytes', {
        'data': Uint8List.fromList(escPosData),
      });

      if (success == true) {
        print('✅ Print successful');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Print error: $e');
      return false;
    }
  }

  Future<bool> printTestPage() async {
    try {
      if (!await isUsbConnected()) {
        print('❌ Not connected');
        return false;
      }

      List<int> data = [];
      data.addAll([0x1B, 0x40]); // Initialize

      String text = "=== TEST PRINT ===\n";
      text += "ATPOS AT-301\n";
      text += "USB Native Print\n";
      text += "Connection: OK\n";
      text += "==================\n\n\n";

      data.addAll(text.codeUnits);
      data.addAll([0x1D, 0x56, 0x00]); // Cut

      final bool? success = await _channel.invokeMethod('printRawBytes', {
        'data': Uint8List.fromList(data),
      });

      return success ?? false;
    } catch (e) {
      print('❌ Test print error: $e');
      return false;
    }
  }

  Future<UsbDeviceInfo?> showUsbPrinterSelectionDialog(BuildContext context) async {
    List<UsbDeviceInfo> devices = await getUsbDevices();

    if (devices.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No USB printers found. Please connect your printer.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return null;
    }

    if (context.mounted) {
      return await showDialog<UsbDeviceInfo>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Select USB Printer',
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
                  title: Text(device.productName),
                  subtitle: Text('VID: ${device.vid}, PID: ${device.pid}'),
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

  Future<bool> connectAndPrintImage(BuildContext context, Uint8List imageBytes) async {
    try {
      print('🔌 ========== PRINT JOB STARTED ==========');

      // Check if already connected
      if (await isUsbConnected()) {
        print('✅ Already connected to USB printer');
        bool success = await printImageBytesUsb(imageBytes);

        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Receipt printed successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        return success;
      }

      // Get devices
      List<UsbDeviceInfo> devices = await getUsbDevices();

      if (devices.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No USB printer found. Please connect your printer.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return false;
      }

      // Try auto-connect to last used printer
      String? lastVid = await _getLastPrinterVid();
      String? lastPid = await _getLastPrinterPid();

      UsbDeviceInfo? device;

      if (lastVid != null && lastPid != null) {
        try {
          device = devices.firstWhere(
                (d) => d.vid.toString() == lastVid && d.pid.toString() == lastPid,
          );

          if (await connectUsb(device)) {
            print('✅ Auto-connected to last used printer');
          } else {
            device = null;
          }
        } catch (e) {
          device = null;
        }
      }

      // If no auto-connect, show selection or connect to first device
      if (device == null) {
        if (devices.length == 1) {
          device = devices[0];

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🔌 Connecting to ${device.productName}...'),
                duration: const Duration(seconds: 2),
              ),
            );
          }

          if (!await connectUsb(device)) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Failed to connect. Please check:\n'
                      '1. USB cable is connected\n'
                      '2. Printer is powered on\n'
                      '3. Grant USB permission when prompted'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
            return false;
          }
        } else {
          device = await showUsbPrinterSelectionDialog(context);

          if (device == null) {
            return false;
          }

          if (!await connectUsb(device)) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('❌ Failed to connect to ${device.productName}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            return false;
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Connected to ${device.productName}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }

      // Print
      bool success = await printImageBytesUsb(imageBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '✅ Receipt printed successfully' : '❌ Print failed'),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: Duration(seconds: success ? 2 : 3),
          ),
        );
      }

      return success;
    } catch (e) {
      print('❌ Error in connectAndPrintImage: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Print failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to read file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return false;
    }
  }

  Future<void> _saveLastPrinterInfo(String vid, String pid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_lastPrinterKey}_vid', vid);
      await prefs.setString('${_lastPrinterKey}_pid', pid);
    } catch (e) {
      print('Error saving last printer: $e');
    }
  }

  Future<String?> _getLastPrinterVid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('${_lastPrinterKey}_vid');
    } catch (e) {
      print('Error getting last printer VID: $e');
      return null;
    }
  }

  Future<String?> _getLastPrinterPid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('${_lastPrinterKey}_pid');
    } catch (e) {
      print('Error getting last printer PID: $e');
      return null;
    }
  }
}