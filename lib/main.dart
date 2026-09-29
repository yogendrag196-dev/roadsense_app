import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'core/theme.dart';
import 'core/routing.dart';
import 'services/db_service.dart';

import 'core/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // Initialize OneSignal (Mobile only)
  if (!kIsWeb) {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    final oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'];
    if (oneSignalAppId != null && oneSignalAppId.isNotEmpty) {
      OneSignal.initialize(oneSignalAppId);
      
      // Add Click Listener for deep linking
      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData;
        if (data != null && data.containsKey('complaint_id')) {
          final complaintId = data['complaint_id'];
          // Wait for the app to be fully mounted before navigating
          Future.delayed(const Duration(milliseconds: 500), () {
            goRouter.push('/track/$complaintId');
          });
        }
      });

      // Observer to capture push subscription ID and save to Supabase
      OneSignal.User.pushSubscription.addObserver((state) async {
        final currentId = state.current.id;
        if (currentId != null && currentId.isNotEmpty) {
          final dbService = DBService();
          await dbService.updateOneSignalId(currentId);
        }
      });
    }
  }

  runApp(
    const ProviderScope(
      child: RoadSenseApp(),
    ),
  );
}

class RoadSenseApp extends ConsumerWidget {
  const RoadSenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'RoadSense AI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
