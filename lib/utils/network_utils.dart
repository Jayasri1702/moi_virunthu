import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkUtils {
  // Check if device has internet connection
  static Future<bool> hasConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Check if error is network-related
  static bool isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('software caused connection abort') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection timed out') ||
        errorString.contains('no address associated with hostname');
  }

  // Show connection error dialog with retry option
  static void showConnectionErrorDialog(
      BuildContext context, {
        VoidCallback? onRetry,
      }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text(
                'No Internet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please check your internet connection and try again.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                '• Check if WiFi or mobile data is enabled\n• Check if you have network coverage',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (onRetry != null) {
                  onRetry();
                }
              },
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6B4C9A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Handle error globally - use this in all your catch blocks
  static void handleError(
      BuildContext context,
      dynamic error, {
        VoidCallback? onRetry,
        String? customMessage,
      }) {
    if (!context.mounted) return;

    if (isNetworkError(error)) {
      showConnectionErrorDialog(context, onRetry: onRetry);
    } else {
      // Show other errors in SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(customMessage ?? 'Error: ${error.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: onRetry != null
              ? SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: onRetry,
          )
              : null,
        ),
      );
    }
  }

  // Check connection before making API calls
  static Future<bool> checkConnectionBeforeRequest(
      BuildContext context, {
        VoidCallback? onRetry,
      }) async {
    bool isConnected = await hasConnection();
    if (!isConnected && context.mounted) {
      showConnectionErrorDialog(context, onRetry: onRetry);
    }
    return isConnected;
  }
}