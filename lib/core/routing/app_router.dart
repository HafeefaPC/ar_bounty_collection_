import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:face_reflector/features/splash/splash_screen.dart';
import 'package:face_reflector/features/wallet/wallet_connection_screen.dart';
import 'package:face_reflector/features/wallet/wallet_options_screen.dart';
import 'package:face_reflector/features/wallet/boundary_history_screen.dart';
import 'package:face_reflector/features/event_joining/event_join_screen.dart';
import 'package:face_reflector/features/ar_view/ar_view_screen.dart';
import 'package:face_reflector/features/event_creation/event_creation_screen.dart';


final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // Splash Screen
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // Wallet Connection
      GoRoute(
        path: '/wallet/connect',
        name: 'wallet-connect',
        builder: (context, state) => const WalletConnectionScreen(),
      ),
      
      // Wallet Options (Join/Create Event)
      GoRoute(
        path: '/wallet/options',
        name: 'wallet-options',
        builder: (context, state) => const WalletOptionsScreen(),
      ),
      
      // Join Event Flow
      GoRoute(
        path: '/event/join',
        name: 'event-join',
        builder: (context, state) => const EventJoinScreen(),
      ),
      
      // AR View
      GoRoute(
        path: '/ar-view',
        name: 'ar-view',
        builder: (context, state) {
          final eventCode = state.uri.queryParameters['eventCode'];
          return ARViewScreen(eventCode: eventCode ?? '');
        },
      ),
      
      // Create Event Flow
      GoRoute(
        path: '/event/create',
        name: 'event-create',
        builder: (context, state) => const EventCreationScreen(),
      ),
      

      
      // Boundary History
      GoRoute(
        path: '/boundary-history',
        name: 'boundary-history',
        builder: (context, state) => const BoundaryHistoryScreen(),
      ),
    ],
  );
});
