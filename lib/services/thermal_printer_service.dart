import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;

class ThermalPrinterService {
  static final ThermalPrinterService _instance = ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();

  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;
  BluetoothDevice? _connectedDevice;

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

  // ✅ CHANGES TO thermal_printer_service.dart

// Replace _convertImageToEscPos method with this OPTIMIZED version:

  List<int> _convertImageToEscPos(Uint8List imageBytes) {
    try {
      print('🔄 Starting OPTIMIZED image conversion...');

      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        print('❌ Failed to decode image');
        return [];
      }

      print('📏 Original size: ${image.width}x${image.height}');

      // ✅ OPTIMIZATION 1: Reduce target width for faster processing
      // 384 pixels = 48mm width (still good quality for 80mm paper)
      // ATPOS AT-301 optimal width: 576 pixels (80mm at 203 DPI)
      int targetWidth = 576;

// ✅ FIX: Maintain aspect ratio when resizing
      double aspectRatio = image.height / image.width;
      int targetHeight = (targetWidth * aspectRatio).round();

      image = img.copyResize(
        image,
        width: targetWidth,
        height: targetHeight,  // ✅ ADD THIS
        interpolation: img.Interpolation.linear,
      );

      print('📏 Resized to: ${image.width}x${image.height}');

      // Convert to grayscale
      image = img.grayscale(image);

      // ✅ OPTIMIZATION 2: Simpler enhancement (faster processing)
      image = img.adjustColor(image, contrast: 1.3, brightness: 1.1);

      print('✨ Enhanced contrast');

      List<int> escPosData = [];

      int width = image.width;
      int height = image.height;

      print('🖨️ Generating ESC/POS commands...');

      // Initialize printer
      escPosData.addAll([0x1B, 0x40]); // ESC @ - Initialize

      // ✅ OPTIMIZATION 3: Use faster printing mode (single-density)
      // Mode 0 = 8-dot single density (faster than 24-dot)
      escPosData.addAll([0x1B, 0x33, 0x00]); // Line spacing = 0

      // ✅ OPTIMIZATION 4: Process in 8-pixel chunks (3x faster than 24-pixel)
      for (int y = 0; y < height; y += 8) {
        // ESC * 0 command (8-dot single-density - FASTEST mode)
        escPosData.addAll([0x1B, 0x2A, 0]);

        // Width in little-endian
        escPosData.add(width & 0xFF);
        escPosData.add((width >> 8) & 0xFF);

        // Process pixels
        for (int x = 0; x < width; x++) {
          int slice = 0;
          for (int b = 0; b < 8; b++) {
            int py = y + b;
            if (py < height) {
              img.Pixel pixel = image.getPixel(x, py);
              int gray = pixel.r.toInt();

              // Threshold for black/white (higher = darker print)
              if (gray < 180) {
                slice |= (1 << (7 - b));
              }
            }
          }
          escPosData.add(slice);
        }

        // Line feed
        escPosData.add(0x0A);
      }

      print('✅ Generated ${escPosData.length} bytes (optimized)');

      // Reset line spacing
      escPosData.addAll([0x1B, 0x32]);

      return escPosData;
    } catch (e) {
      print('❌ Error converting image: $e');
      return [];
    }
  }

// ✅ OPTIMIZATION 5: Increase chunk size for faster data transfer
  Future<bool> printImageBytes(Uint8List imageBytes) async {
    try {
      bool connected = await isConnected();
      if (!connected) {
        print('❌ Printer not connected');
        return false;
      }

      print('🖨️ Converting image for thermal printer...');

      // Convert image to ESC/POS format
      List<int> escPosData = _convertImageToEscPos(imageBytes);

      if (escPosData.isEmpty) {
        print('❌ Failed to convert image');
        return false;
      }

      print('🖨️ Sending ${escPosData.length} bytes to printer');

      // ✅ INCREASED: Send 2KB chunks (faster than 1KB)
      const int chunkSize = 2048;
      int totalChunks = (escPosData.length / chunkSize).ceil();

      print('📦 Sending in $totalChunks chunks of ${chunkSize}B...');

      for (int i = 0; i < escPosData.length; i += chunkSize) {
        int end = (i + chunkSize < escPosData.length)
            ? i + chunkSize
            : escPosData.length;

        await _bluetooth.writeBytes(
            Uint8List.fromList(escPosData.sublist(i, end))
        );

        // ✅ REDUCED: Smaller delay (20ms instead of 50ms)
        if (end < escPosData.length) {
          await Future.delayed(const Duration(milliseconds: 20));
        }

        // Progress logging
        if ((i / chunkSize).floor() % 10 == 0 || end >= escPosData.length) {
          int currentChunk = (i / chunkSize).floor() + 1;
          print('📤 Sent $currentChunk/$totalChunks');
        }
      }

      print('✅ All data sent');

      // Add spacing
      await _bluetooth.printNewLine();
      await _bluetooth.printNewLine();
      await _bluetooth.printNewLine();

      // Cut paper
      await _bluetooth.paperCut();

      print('✅ Print completed');
      return true;
    } catch (e) {
      print('❌ Print error: $e');
      return false;
    }
  }

  /// Print PDF file (for WhatsApp - keep this for backward compatibility)
  Future<bool> printPdfFile(File pdfFile) async {
    try {
      bool connected = await isConnected();
      if (!connected) {
        print('❌ Printer not connected');
        return false;
      }

      print('🖨️ Printing PDF (trying image path method)');

      // Try using printImage with file path
      await _bluetooth.printImage(pdfFile.path);

      // Add spacing
      _bluetooth.printNewLine();
      _bluetooth.printNewLine();

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

  /// Connect and print image bytes
  Future<bool> connectAndPrintImage(BuildContext context, Uint8List imageBytes) async {
    try {
      // Check if already connected
      bool connected = await isConnected();

      if (!connected) {
        // Try to auto-connect to last used printer
        String? lastPrinterAddress = await _getLastPrinterAddress();
        BluetoothDevice? device;

        if (lastPrinterAddress != null) {
          List<BluetoothDevice> devices = await getPairedDevices();
          try {
            device = devices.firstWhere(
                  (d) => d.address == lastPrinterAddress,
            );

            // Try auto-connect
            bool autoConnected = await connect(device);
            if (!autoConnected) {
              device = null;
            }
          } catch (e) {
            device = null;
          }
        }

        // If no auto-connect, show selection dialog
        if (device == null) {
          device = await showPrinterSelectionDialog(context);

          if (device == null) {
            return false;
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

        // Save last used printer
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

      // Print the image
      bool printSuccess = await printImageBytes(imageBytes);

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

  /// Connect and print PDF (keep for backward compatibility)
  Future<bool> connectAndPrint(BuildContext context, File pdfFile) async {
    try {
      // Check if already connected
      bool connected = await isConnected();

      if (!connected) {
        // Try to auto-connect to last used printer
        String? lastPrinterAddress = await _getLastPrinterAddress();
        BluetoothDevice? device;

        if (lastPrinterAddress != null) {
          List<BluetoothDevice> devices = await getPairedDevices();
          try {
            device = devices.firstWhere(
                  (d) => d.address == lastPrinterAddress,
            );

            // Try auto-connect
            bool autoConnected = await connect(device);
            if (!autoConnected) {
              device = null;
            }
          } catch (e) {
            device = null;
          }
        }

        // If no auto-connect, show selection dialog
        if (device == null) {
          device = await showPrinterSelectionDialog(context);

          if (device == null) {
            return false;
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

        // Save last used printer
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

  /// Save last used printer address
  Future<void> _saveLastPrinterAddress(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastPrinterKey, address);
    } catch (e) {
      print('Error saving last printer: $e');
    }
  }

  /// Get last used printer address
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