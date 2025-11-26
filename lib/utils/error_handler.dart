import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorHandler {
  // Show connection error dialog
  static void showConnectionErrorDialog(
      BuildContext context, {
        String? customMessage,
        VoidCallback? onRetry,
      }) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(
                Icons.wifi_off_rounded,
                color: Colors.red[700],
                size: 32,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Internet Connection',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customMessage ?? 'Unable to connect to the server.',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Please check your internet connection and try again.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
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
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (onRetry != null) {
                  onRetry();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text(
                'Retry',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Check if error is a connection error
  static bool isConnectionError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    return errorString.contains('clientexception') ||
        errorString.contains('connection closed') ||
        errorString.contains('connection terminated') ||
        errorString.contains('socketexception') ||
        errorString.contains('handshakeexception') ||
        errorString.contains('timeoutexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection reset');
  }

  // Handle any Supabase or network error
  static void handleError(
      dynamic error,
      BuildContext context, {
        VoidCallback? onRetry,
        bool showSnackBar = true,
      }) {
    if (!context.mounted) return;

    // Check if it's a connection error
    if (isConnectionError(error)) {
      showConnectionErrorDialog(
        context,
        customMessage: 'Connection Error',
        onRetry: onRetry,
      );
      return;
    }

    // Handle PostgrestException (Supabase database errors)
    if (error is PostgrestException) {
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Database Error: ${error.message}')),
              ],
            ),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Handle AuthException
    if (error is AuthException) {
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.lock_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Auth Error: ${error.message}')),
              ],
            ),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Generic error handling
    if (showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Error: ${error.toString()}')),
            ],
          ),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Wrap async operations with error handling
  static Future<T?> handleAsyncOperation<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    VoidCallback? onRetry,
    String? errorMessage,
  }) async {
    try {
      return await operation();
    } catch (e) {
      if (context.mounted) {
        handleError(e, context, onRetry: onRetry);
      }
      return null;
    }
  }
}