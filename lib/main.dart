import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/fcm_service.dart';
import 'features/notifications/services/notification_service.dart';
import 'package:go_router/go_router.dart';
import 'features/bills/pages/bill_detail_page.dart';

// Global navigator key untuk dialog yang perlu ditampilkan meskipun widget unmounted
final globalNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  navigatorKey: globalNavigatorKey,
  routes: [
    GoRoute(
      path: '/bill/:id',
      name: 'bill-detail',
      builder: (context, state) {
        final billId = state.pathParameters['id']!;
        return BillDetailPage(billId: billId);
      },
    ),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Initialize Supabase
  await SupabaseConfig.initialize();

  // Initialize local notifications
  final notificationService = NotificationService();
  await notificationService.initializeLocalNotifications();

  // Setup realtime listener jika user sudah login
  final currentSession = Supabase.instance.client.auth.currentSession;
  if (currentSession != null) {
    print('✅ User already signed in, setting up realtime listener');
    FCMService().initialize();
    notificationService.setupRealtimeListener();
  }

  // Setup deep link listener untuk email confirmation dengan logging detail
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    final session = data.session;

    print('🔐 Auth event: $event');
    if (session?.user != null) {
      print('📧 Session: ${session!.user.email ?? "no email"}');
      print('✉️ Email confirmed: ${session.user.emailConfirmedAt != null}');
      print('👤 User ID: ${session.user.id}');

      // Initialize FCM and realtime listener when user signs in
      if (event == AuthChangeEvent.signedIn) {
        print('✅ User signed in via deep link');
        FCMService().initialize();
        notificationService.setupRealtimeListener();
      }
    } else {
      print('❌ No session/user');
    }

    if (event == AuthChangeEvent.signedIn) {
      print('✅ User signed in via deep link');
    } else if (event == AuthChangeEvent.tokenRefreshed) {
      print('🔄 Token refreshed');
    } else if (event == AuthChangeEvent.userUpdated) {
      print('👤 User updated');
    }
  });

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Splitbillers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      darkTheme: AppTheme.darkTheme.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
        ),
      ),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // Error boundary untuk menangani exception di widget tree
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Oops! Ada kesalahan',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      details.exception.toString(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        };
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
