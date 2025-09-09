
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:face_reflector/features/splash/splash_screen.dart';
import 'package:face_reflector/features/wallet/wallet_connection_screen.dart';
import 'package:face_reflector/features/wallet/wallet_options_screen.dart';
import 'package:face_reflector/features/event_joining/event_join_screen.dart';

import 'package:face_reflector/features/event_creation/event_creation_screen.dart';
import 'package:face_reflector/features/nft_collection/nft_viewer_screen.dart';
import 'package:face_reflector/features/ar_view/ar_view_screen.dart';
import 'package:face_reflector/features/main/main_screen.dart';


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
      
      // Main Screen
      GoRoute(
        path: '/main',
        name: 'main',
        builder: (context, state) => const MainScreen(),
      ),
      
      // Join Event Flow (without code)
      GoRoute(
        path: '/event/join',
        name: 'event-join',
        builder: (context, state) {
          final eventCode = state.uri.queryParameters['code'];
          print('Router: Navigating to /event/join (query: $eventCode)');
          print('Router: Query parameters: ${state.uri.queryParameters}');
          print('Router: URI: ${state.uri}');
          return EventJoinScreen(initialEventCode: eventCode);
        },
        routes: [
          // Join Event with Code (path parameter)
          GoRoute(
            path: '/:code',
            name: 'event-join-with-code',
            builder: (context, state) {
              final eventCode = state.pathParameters['code'];
              print('Router: Navigating to /event/join/$eventCode');
              print('Router: Path parameters: ${state.pathParameters}');
              print('Router: URI: ${state.uri}');
              return EventJoinScreen(initialEventCode: eventCode);
            },
          ),
        ],
      ),
      
     
      
      // Create Event Flow
      GoRoute(
        path: '/event/create',
        name: 'event-create',
        builder: (context, state) => const EventCreationScreen(),
      ),
      
      // Events Overview (redirects to main for now)
      GoRoute(
        path: '/events',
        name: 'events',
        redirect: (context, state) => '/main',
      ),
      
      
      // NFT Collection Viewer
      GoRoute(
        path: '/nft-collection',
        name: 'nft-collection',
        builder: (context, state) => const NFTViewerScreen(),
      ),
      
      // AR View Screen
      GoRoute(
        path: '/ar-view',
        name: 'ar-view',
        builder: (context, state) {
          final eventCode = state.uri.queryParameters['eventCode'];
          print('Router: Navigating to /ar-view with eventCode: $eventCode');
          return RetroARViewScreen(eventCode: eventCode ?? '');
        },
      ),
      
      // Debug route to catch all unmatched routes
      GoRoute(
        path: '/:path*',
        name: 'debug-catch-all',
        builder: (context, state) {
          final path = state.uri.path;
          print('DEBUG: No route found for: $path');
          print('DEBUG: Full URI: ${state.uri}');
          print('DEBUG: Query parameters: ${state.uri.queryParameters}');
          print('DEBUG: Path parameters: ${state.pathParameters}');
          
          return Scaffold(
            appBar: AppBar(title: Text('Route Not Found')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Route not found: $path'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.go('/main'),
                    child: Text('Go to Main'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );
});
