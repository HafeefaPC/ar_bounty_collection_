import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:face_reflector/core/theme/app_theme.dart';
import 'package:face_reflector/core/routing/app_router.dart';
import 'package:face_reflector/core/providers/providers.dart';
import 'package:face_reflector/shared/providers/reown_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase at app level
  try {
    await Supabase.initialize(
      url: 'https://kkzgqrjgjcusmdivvbmj.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtremdxcmpnamN1c21kaXZ2Ym1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYxMjg1NzEsImV4cCI6MjA3MTcwNDU3MX0.g82dcf0a2dS0aFEMigp_cpPZlDwRbmOKtuGoXuf0dEA',
    );
    print('Supabase initialized successfully in main');
    
    // Test the connection immediately
    final client = Supabase.instance.client;
    print('Supabase client created: ${client != null}');
    
    // Try to make a simple test query
    try {
      final response = await client.from('events').select('id').limit(1);
      print('Initial connection test successful: ${response.length} records');
    } catch (e) {
      print('Initial connection test failed: $e');
    }
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

class FaceReflectorApp extends ConsumerStatefulWidget {
  const FaceReflectorApp({super.key});

  @override
  ConsumerState<FaceReflectorApp> createState() => _FaceReflectorAppState();
}

class _FaceReflectorAppState extends ConsumerState<FaceReflectorApp> {
  @override
  void initState() {
    super.initState();
    _initializeReownAppKit();
  }

  Future<void> _initializeReownAppKit() async {
    try {
      await ref.read(reownAppKitProvider.notifier).initialize(context);
      print('ReownAppKit initialized successfully in main app');
    } catch (e) {
      print('Error initializing ReownAppKit in main app: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    
    return MaterialApp.router(
      title: 'FaceReflector',
      debugShowCheckedModeBanner: false,
      // theme: AppTheme.lightTheme,
      // darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
