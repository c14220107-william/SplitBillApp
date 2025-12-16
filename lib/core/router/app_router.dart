import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/bills/pages/create_bill_page.dart';
import '../../features/bills/pages/select_participants_page.dart';
import '../../features/bills/pages/add_items_page.dart';
import '../../features/bills/pages/bill_detail_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/notifications/pages/notifications_page.dart';
import '../../features/auth/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: globalNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      // Cek apakah masih loading
      if (authState.isLoading) {
        return null; // Tunggu sampai selesai loading
      }

      final isLoggedIn = authState.value != null;
      final currentPath = state.matchedLocation;

      final isAuthPage = currentPath == '/login' || 
                         currentPath.startsWith('/login?') ||
                         currentPath == '/register';

      // Jika belum login dan bukan di halaman login/register, redirect ke login
      if (!isLoggedIn && !isAuthPage) {
        return '/login';
      }

      // Jika sudah login dan di halaman auth, redirect ke home
      if (isLoggedIn && isAuthPage) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/create-bill',
        builder: (context, state) => const CreateBillPage(),
      ),
      GoRoute(
        path: '/select-participants',
        builder: (context, state) => const SelectParticipantsPage(),
      ),
      GoRoute(
        path: '/add-items',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return AddItemsPage(
            billTitle: extra['billTitle'] as String,
            billDate: extra['billDate'] as DateTime,
            taxPercent: extra['taxPercent'] as double,
            servicePercent: extra['servicePercent'] as double,
            participantIds: extra['participantIds'] as List<String>,
          );
        },
      ),
      GoRoute(
        path: '/bill/:billId',
        builder: (context, state) {
          final billId = state.pathParameters['billId']!;
          return BillDetailPage(billId: billId);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
    ],
  );
});
