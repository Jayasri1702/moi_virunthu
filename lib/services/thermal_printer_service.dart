import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:usb_serial/usb_serial.dart';

class ThermalPrinterService {
  static final ThermalPrinterService _instance = ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();

  UsbPort? _usbPort;
  UsbDevice? _connectedUsbDevice;

  static const String _lastPrinterKey = 'last_usb_printer';

  /// Check if USB printer is connected
  Future<bool> isUsbConnected() async {
    try {
      if (_usbPort != null) {
        return true;
      }

      List<UsbDevice> devices = await UsbSerial.listDevices();
      return devices.isNotEmpty;
    } catch (e) {
      print('❌ Error checking USB connection: $e');
      return false;
    }
  }

  /// Get list of USB devices
  Future<List<UsbDevice>> getUsbDevices() async {
    try {
      List<UsbDevice> devices = await UsbSerial.listDevices();
      print('🔌 Found ${devices.length} USB devices');

      for (var device in devices) {
        print('📱 Device: ${device.productName} - VID: ${device.vid}, PID: ${device.pid}');
      }

      return devices;
    } catch (e) {
      print('❌ Error getting USB devices: $e');
      return [];
    }
  }

  /// Connect to USB printer (Aptos Thermal Printer)
  Future<bool> connectUsb(UsbDevice device) async {
    try {
      print('🔌 Connecting to USB printer: ${device.productName}...');

      // Disconnect if already connected
      if (_usbPort != null) {
        await _usbPort!.close();
        _usbPort = null;
      }

      _usbPort = await device.create();

      if (_usbPort == null) {
        print('❌ Failed to create USB port');
        return false;
      }

      bool opened = await _usbPort!.open();

      if (!opened) {
        print('❌ Failed to open USB port');
        _usbPort = null;
        return false;
      }

      // Configure port for Aptos thermal printer
      await _usbPort!.setDTR(true);
      await _usbPort!.setRTS(true);

      // Try 115200 baud rate first (common for Aptos), fallback to 9600
      await _usbPort!.setPortParameters(
        115200, // Higher baud rate for better performance
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _connectedUsbDevice = device;

      // Save last used printer
      await _saveLastPrinterInfo(device.vid.toString(), device.pid.toString());

      print('✅ Connected to USB printer');

      // Initialize printer properly
      await Future.delayed(Duration(milliseconds: 200));
      await _usbPort!.write(Uint8List.fromList([0x1B, 0x40])); // ESC @ - Initialize
      await Future.delayed(Duration(milliseconds: 300));

      return true;
    } catch (e) {
      print('❌ USB connection error: $e');
      _usbPort = null;
      return false;
    }
  }

  /// Disconnect from USB printer
  Future<void> disconnect() async {
    try {
      if (_usbPort != null) {
        await _usbPort!.close();
        _usbPort = null;
        _connectedUsbDevice = null;
        print('✅ USB Disconnected');
      }
    } catch (e) {
      print('❌ Error disconnecting: $e');
    }
  }

  /// Convert image to ESC/POS format (optimized for Aptos)
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

      // Resize to 384 pixels width (suitable for 58mm thermal printer like Aptos)
      // Use 576 for 80mm printer if yours is 80mm
      int targetWidth = 384; // Change to 576 if you have 80mm printer
      image = img.copyResize(
          image,
          width: targetWidth,
          interpolation: img.Interpolation.linear
      );

      print('📏 Resized to: ${image.width}x${image.height}');

      // Convert to grayscale first
      image = img.grayscale(image);

      // Apply stronger contrast for thermal printing
      image = img.adjustColor(image, contrast: 1.6, brightness: 1.1);

      // Apply threshold to convert to pure black and white
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          img.Pixel pixel = image.getPixel(x, y);
          int gray = pixel.r.toInt();
          // Use 140 threshold for clearer printing
          int newValue = gray < 140 ? 0 : 255;
          image.setPixelRgba(x, y, newValue, newValue, newValue, 255);
        }
      }

      print('✨ Enhanced image quality');

      List<int> escPosData = [];

      int width = image.width;
      int height = image.height;

      print('🖨️ Generating ESC/POS commands...');

      // Initialize printer
      escPosData.addAll([0x1B, 0x40]); // ESC @ - Initialize printer

      // Set line spacing to 0 for continuous printing
      escPosData.addAll([0x1B, 0x33, 0x00]); // ESC 3 0

      // Print in 24-pixel chunks (standard for ESC/POS)
      int chunkCount = 0;
      for (int y = 0; y < height; y += 24) {
        chunkCount++;

        // ESC * m nL nH - Select bit-image mode
        // Mode 33 = 24-dot double-density
        escPosData.addAll([0x1B, 0x2A, 33]);

        // Width in little-endian format
        escPosData.add(width & 0xFF);
        escPosData.add((width >> 8) & 0xFF);

        // Process each column
        for (int x = 0; x < width; x++) {
          // Each column has 3 bytes (24 bits)
          for (int k = 0; k < 3; k++) {
            int slice = 0;
            for (int b = 0; b < 8; b++) {
              int py = y + (k * 8) + b;
              if (py < height) {
                img.Pixel pixel = image.getPixel(x, py);
                int gray = pixel.r.toInt();

                // Since we already thresholded, check if black
                if (gray < 128) {
                  slice |= (1 << (7 - b));
                }
              }
            }
            escPosData.add(slice);
          }
        }

        // Line feed after each chunk
        escPosData.add(0x0A);

        if (chunkCount % 5 == 0) {
          print('📊 Processed $chunkCount chunks...');
        }
      }

      print('✅ Generated ${escPosData.length} bytes in $chunkCount chunks');

      // Reset line spacing to default
      escPosData.addAll([0x1B, 0x32]); // ESC 2

      return escPosData;
    } catch (e) {
      print('❌ Error converting image: $e');
      return [];
    }
  }

  /// Print image bytes via USB
  Future<bool> printImageBytesUsb(Uint8List imageBytes) async {
    try {
      if (_usbPort == null) {
        print('❌ USB printer not connected');
        return false;
      }

      print('🖨️ Converting image for USB thermal printer...');

      // Convert image to ESC/POS format
      List<int> escPosData = _convertImageToEscPos(imageBytes);

      if (escPosData.isEmpty) {
        print('❌ Failed to convert image');
        return false;
      }

      print('🖨️ Sending ${escPosData.length} bytes to USB printer');

      // Send data in smaller chunks for stability
      const int chunkSize = 512; // Smaller chunks for better compatibility
      int totalChunks = (escPosData.length / chunkSize).ceil();

      print('📦 Sending in $totalChunks chunks of ${chunkSize}B...');

      for (int i = 0; i < escPosData.length; i += chunkSize) {
        int end = (i + chunkSize < escPosData.length)
            ? i + chunkSize
            : escPosData.length;

        Uint8List chunk = Uint8List.fromList(escPosData.sublist(i, end));

        await _usbPort!.write(chunk);

        // Important: Wait for printer buffer
        await Future.delayed(Duration(milliseconds: 100));

        if ((i / chunkSize).floor() % 5 == 0 || end >= escPosData.length) {
          int currentChunk = (i / chunkSize).floor() + 1;
          print('📤 Sent $currentChunk/$totalChunks chunks');
        }
      }

      print('✅ All data sent via USB');

      // Wait for printing to complete
      await Future.delayed(Duration(milliseconds: 1000));

      // Feed paper and cut
      await _usbPort!.write(Uint8List.fromList([
        0x0A, 0x0A, 0x0A, 0x0A // 4 line feeds
      ]));
      await Future.delayed(Duration(milliseconds: 300));

      // Cut paper - try both commands
      // GS V 0 (full cut)
      await _usbPort!.write(Uint8List.fromList([0x1D, 0x56, 0x00]));
      await Future.delayed(Duration(milliseconds: 200));

      // Alternative cut command (partial cut)
      // await _usbPort!.write(Uint8List.fromList([0x1D, 0x56, 0x01]));

      print('✅ USB Print completed');
      return true;
    } catch (e) {
      print('❌ USB Print error: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Print test page to verify connection
  Future<bool> printTestPage() async {
    try {
      if (_usbPort == null) {
        print('❌ USB printer not connected');
        return false;
      }

      print('🖨️ Printing test page...');

      // Initialize
      await _usbPort!.write(Uint8List.fromList([0x1B, 0x40]));
      await Future.delayed(Duration(milliseconds: 200));

      // Print test text
      String testText = "=== TEST PRINT ===\n";
      testText += "Aptos Thermal Printer\n";
      testText += "Connection: OK\n";
      testText += "==================\n\n\n";

      await _usbPort!.write(Uint8List.fromList(testText.codeUnits));
      await Future.delayed(Duration(milliseconds: 500));

      // Cut
      await _usbPort!.write(Uint8List.fromList([0x1D, 0x56, 0x00]));

      print('✅ Test page sent');
      return true;
    } catch (e) {
      print('❌ Test print error: $e');
      return false;
    }
  }

  /// Show USB printer selection dialog
  Future<UsbDevice?> showUsbPrinterSelectionDialog(BuildContext context) async {
    List<UsbDevice> devices = await getUsbDevices();

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
      return await showDialog<UsbDevice>(
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
                  title: Text(device.productName ?? 'USB Printer'),
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

  /// Connect and print image via USB
  Future<bool> connectAndPrintImage(BuildContext context, Uint8List imageBytes) async {
    try {
      print('🔌 Checking for USB printer...');

      // Check if already connected
      if (_usbPort != null) {
        print('✅ Already connected to USB printer');

        bool printSuccess = await printImageBytesUsb(imageBytes);

        if (printSuccess && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Receipt sent to USB printer'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        return printSuccess;
      }

      // Get USB devices
      List<UsbDevice> usbDevices = await getUsbDevices();

      if (usbDevices.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No USB printer found. Please connect your printer.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false;
      }

      // Try to auto-connect to last used printer
      String? lastVid = await _getLastPrinterVid();
      String? lastPid = await _getLastPrinterPid();

      UsbDevice? device;

      if (lastVid != null && lastPid != null) {
        try {
          device = usbDevices.firstWhere(
                (d) => d.vid.toString() == lastVid && d.pid.toString() == lastPid,
          );

          bool autoConnected = await connectUsb(device);
          if (!autoConnected) {
            device = null;
          } else {
            print('✅ Auto-connected to last used printer');
          }
        } catch (e) {
          device = null;
        }
      }

      // If no auto-connect, show selection dialog or connect to first device
      if (device == null) {
        if (usbDevices.length == 1) {
          // Only one device, connect automatically
          device = usbDevices[0];
          bool connectSuccess = await connectUsb(device);

          if (!connectSuccess) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Failed to connect to USB printer'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return false;
          }
        } else {
          // Multiple devices, show selection
          device = await showUsbPrinterSelectionDialog(context);

          if (device == null) {
            return false;
          }

          bool connectSuccess = await connectUsb(device);
          if (!connectSuccess) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('❌ Failed to connect to ${device.productName}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return false;
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Connected to ${device.productName ?? "USB Printer"}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }

      // Print via USB
      bool printSuccess = await printImageBytesUsb(imageBytes);

      if (printSuccess && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Receipt sent to USB printer'),
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

  /// Save last used printer info
  Future<void> _saveLastPrinterInfo(String vid, String pid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_lastPrinterKey}_vid', vid);
      await prefs.setString('${_lastPrinterKey}_pid', pid);
    } catch (e) {
      print('Error saving last printer: $e');
    }
  }

  /// Get last used printer VID
  Future<String?> _getLastPrinterVid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('${_lastPrinterKey}_vid');
    } catch (e) {
      print('Error getting last printer VID: $e');
      return null;
    }
  }

  /// Get last used printer PID
  Future<String?> _getLastPrinterPid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('${_lastPrinterKey}_pid');
    } catch (e) {
      print('Error getting last printer PID: $e');
      return null;
    }
  }

  /// Connect and print file (accepts File directly)
  Future<bool> connectAndPrint(BuildContext context, File file) async {
    try {
      // Read file as bytes
      Uint8List imageBytes = await file.readAsBytes();

      // Use the existing connectAndPrintImage method
      return await connectAndPrintImage(context, imageBytes);
    } catch (e) {
      print('❌ Error in connectAndPrint: $e');
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
}