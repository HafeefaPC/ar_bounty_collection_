import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:face_reflector/core/theme/app_theme.dart';
import 'package:face_reflector/core/routing/app_router.dart';
import 'package:face_reflector/core/providers/providers.dart';
import 'package:face_reflector/shared/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  try {
    final supabaseService = SupabaseService();
    await supabaseService.initialize();
    print('Supabase initialized successfully in main');
  } catch (e) {
    print('Error initializing Supabase in main: $e');
  }
  
  // Initialize providers
  initializeProviders();
  
  runApp(
    const ProviderScope(
      child: FaceReflectorApp(),
    ),
  );
}

class FaceReflectorApp extends ConsumerWidget {
  const FaceReflectorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    
    return MaterialApp.router(
      title: 'FaceReflector',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
