import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/splash/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/report/screens/report_screen.dart';
import '../features/report/screens/success_screen.dart';
import '../features/track/screens/track_screen.dart';
import '../features/track/screens/complaint_detail_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/notifications/screens/permission_screen.dart';

CustomTransitionPage buildPageWithDefaultTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Fade + Slide transition
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.05),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

final goRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: const SplashScreen(),
      ),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: const LoginScreen(),
      ),
    ),
    GoRoute(
      path: '/register',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: const RegisterScreen(),
      ),
    ),
    GoRoute(
      path: '/notifications-permission',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: const NotificationPermissionScreen(),
      ),
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: const HomeScreen(),
      ),
    ),
    GoRoute(
      path: '/report',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: const ReportScreen(),
      ),
    ),
    GoRoute(
      path: '/report-success',
      pageBuilder: (context, state) {
        final trackingId = state.extra as String? ?? 'UNKNOWN';
        return buildPageWithDefaultTransition(
          context: context,
          state: state,
          child: SuccessScreen(trackingId: trackingId),
        );
      },
    ),
    GoRoute(
      path: '/track',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: const TrackScreen(),
      ),
    ),
    GoRoute(
      path: '/track/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return buildPageWithDefaultTransition(
          context: context,
          state: state,
          child: ComplaintDetailScreen(complaintId: id),
        );
      },
    ),
    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: const DashboardScreen(),
      ),
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: const ProfileScreen(),
      ),
    ),
  ],
);
