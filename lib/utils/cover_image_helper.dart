// Create this as a separate helper file: lib/utils/cover_image_helper.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class CoverImageHelper {
  static const String customImageFileName = 'custom_receipt_bg.png';

  /// Get the cover image bytes - either custom or default
  static Future<Uint8List> getCoverImageBytes() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final customImagePath = path.join(appDir.path, customImageFileName);
      final customImageFile = File(customImagePath);

      if (await customImageFile.exists()) {
        // Use custom image
        return await customImageFile.readAsBytes();
      } else {
        // Use default asset image
        final byteData = await rootBundle.load('assets/images/receipt_bg.png');
        return byteData.buffer.asUint8List();
      }
    } catch (e) {
      // Fallback to asset image
      final byteData = await rootBundle.load('assets/images/receipt_bg.png');
      return byteData.buffer.asUint8List();
    }
  }

  /// Save a custom cover image
  static Future<bool> saveCustomImage(File sourceFile) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final customImagePath = path.join(appDir.path, customImageFileName);
      await sourceFile.copy(customImagePath);
      return true;
    } catch (e) {
      print('Error saving custom image: $e');
      return false;
    }
  }

  /// Delete custom image and revert to default
  static Future<bool> deleteCustomImage() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final customImagePath = path.join(appDir.path, customImageFileName);
      final customImageFile = File(customImagePath);

      if (await customImageFile.exists()) {
        await customImageFile.delete();
      }
      return true;
    } catch (e) {
      print('Error deleting custom image: $e');
      return false;
    }
  }

  /// Check if custom image exists
  static Future<bool> hasCustomImage() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final customImagePath = path.join(appDir.path, customImageFileName);
      final customImageFile = File(customImagePath);
      return await customImageFile.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get the custom image file if it exists
  static Future<File?> getCustomImageFile() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final customImagePath = path.join(appDir.path, customImageFileName);
      final customImageFile = File(customImagePath);

      if (await customImageFile.exists()) {
        return customImageFile;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}