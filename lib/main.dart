import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/constants.dart';
import 'screens/admin/login_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/create_operator_screen.dart';
import 'screens/admin/user_list_screen.dart';
import 'screens/admin/create_event_screen.dart';
import 'screens/admin/all_events_screen.dart';
import 'screens/admin/todays_events_screen.dart';
import 'screens/admin/event_expenses_screen.dart';
import 'screens/operator/home_screen.dart';
import 'screens/operator/event_dashboard_screen.dart';
import 'screens/operator/collect_moi_screen.dart';
import 'screens/operator/correct_village_name.dart';
import 'screens/operator/uncle_reorder_screen.dart';
import 'screens/operator/cash_withdrawal_screen.dart';
import 'screens/operator/exchange_denomination_screen.dart';
import 'screens/operator/collection_details_screen.dart';
import 'screens/operator/moi_receipt_preview_screen.dart';
import 'screens/admin/correct_person_data_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Auth Starter',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/admin': (context) => const AdminDashboard(),
        '/admin/create-operator': (context) => const CreateOperatorScreen(),
        '/admin/user-list': (context) => const UserListScreen(),
        '/admin/create-event': (context) => const CreateEventScreen(),
        '/admin/all-events': (context) => const AllEventsScreen(),
        '/admin/todays-event': (context) => const TodaysEventsScreen(),
        '/admin/event-expenses': (context) => const EventExpensesScreen(),
        '/operator/home': (context) => const OperatorHomeScreen(),
        '/operator/event-dashboard': (context) => const EventDashboardScreen(),
        '/operator/collect-moi': (context) => const CollectMoiScreen(),
        '/operator/correct-village-names': (context) => const CorrectVillageNamesScreen(),
        '/operator/uncle-reorder': (context) => const UncleReorderScreen(),
        '/operator/cash_withdrawal': (context) => const CashWithdrawalScreen(),
        '/operator/exchange-denomination': (context) => const ExchangeDenominationScreen(),
        '/operator/collection-details': (context) => const CollectionDetailsScreen(),
        '/operator/moi-receipt-preview': (context) => const MoiReceiptPreviewScreen(),
        '/admin/correct-person-data': (context) => const CorrectPersonDataScreen(),
      },
      builder: (context, child) {
        return ErrorHandlerWrapper(child: child ?? Container());
      },
    );
  }
}

// Global Error Handler Wrapper
class ErrorHandlerWrapper extends StatelessWidget {
  final Widget child;

  const ErrorHandlerWrapper({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

// Utility function to show connection error dialog
void showConnectionErrorDialog(BuildContext context, {String? customMessage}) {
  if (!context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Icon(
              Icons.wifi_off,
              color: Colors.red[700],
              size: 30,
            ),
            const SizedBox(width: 10),
            const Text(
              'Connection Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please check your internet connection and try again.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Optionally trigger a retry action here
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      );
    },
  );
}

// Helper function to handle Supabase errors globally
void handleSupabaseError(dynamic error, BuildContext context) {
  String errorMessage = 'An error occurred';

  if (error.toString().contains('ClientException') ||
      error.toString().contains('Connection closed') ||
      error.toString().contains('Connection terminated') ||
      error.toString().contains('SocketException') ||
      error.toString().contains('HandshakeException') ||
      error.toString().contains('TimeoutException')) {
    errorMessage = 'Connection error';
    showConnectionErrorDialog(context, customMessage: errorMessage);
  } else if (error is PostgrestException) {
    errorMessage = error.message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Database Error: $errorMessage'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${error.toString()}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}