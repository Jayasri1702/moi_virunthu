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
import 'screens/operator/event_dashboard_screen.dart'; // Add this import
import 'screens/operator/collect_moi_screen.dart';
import 'screens/operator/correct_village_name.dart'; // Add this line
import 'screens/operator/uncle_reorder_screen.dart'; // Add this line
import 'screens/operator/cash_withdrawal_screen.dart';
import 'screens/operator/exchange_denomination_screen.dart';
import 'screens/operator/collection_details_screen.dart';
import 'screens/operator/moi_receipt_preview_screen.dart';
import 'screens/admin/correct_person_data_screen.dart';
import 'screens/admin/cover_image_manager.dart';

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
        '/operator/event-dashboard': (context) => const EventDashboardScreen(), // Add this route
        '/operator/collect-moi': (context) => const CollectMoiScreen(),
        '/operator/correct-village-names': (context) => const CorrectVillageNamesScreen(eventId: '',),
        '/operator/uncle-reorder': (context) => const UncleReorderScreen(), // Add this line
        '/operator/cash_withdrawal': (context) => const CashWithdrawalScreen(),
        '/operator/exchange-denomination': (context) => const ExchangeDenominationScreen(),
        '/operator/collection-details': (context) => const CollectionDetailsScreen(),
        '/operator/moi-receipt-preview': (context) => const MoiReceiptPreviewScreen(),
        '/admin/correct-person-data': (context) => const CorrectPersonDataScreen(),
        '/admin/cover-image': (context) => const CoverImageManagerScreen(),
      },
    );
  }
}