import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class NetworkUtils {

  static Future<bool> hasConnection() async {
    // Skip pre-check - let the actual API call determine connectivity
    // Pre-checks are unreliable on mobile networks
    return true;
  }

  static bool isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Catches all SocketException variants (JIO, Airtel, BSNL, etc.)
    if (errorString.contains('socketexception')) return true;

    // HTTP client errors from dio/http package
    if (errorString.contains('connection refused')) return true;
    if (errorString.contains('connection reset')) return true;
    if (errorString.contains('connection timed out')) return true;
    if (errorString.contains('connectiontimeout')) return true;
    if (errorString.contains('sendtimeout')) return true;
    if (errorString.contains('receivetimeout')) return true;

    // OS-level network errors
    if (errorString.contains('network is unreachable')) return true;
    if (errorString.contains('no internet')) return true;
    if (errorString.contains('no address associated')) return true;
    if (errorString.contains('failed host lookup')) return true;
    if (errorString.contains('unable to resolve')) return true;
    if (errorString.contains('network error')) return true;

    // Supabase/Postgrest specific
    if (errorString.contains('clientexception')) return true;
    if (errorString.contains('handshakeexception')) return true;
    if (errorString.contains('tlsexception')) return true;

    // Timeout (treat as network issue for retry dialog)
    if (errorString.contains('timeoutexception')) return true;

    return false;
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
                'Unable to connect to the internet. Please check your connection.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                '• Move closer to your WiFi router\n• Try switching to mobile data\n• Restart your WiFi/mobile connection\n• Try again in a moment',
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
      final message = customMessage ?? 'Error: ${error.toString()}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
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