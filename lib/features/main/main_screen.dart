import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/wallet_connection_wrapper.dart';
import '../../shared/services/global_wallet_service.dart';
import '../../shared/widgets/floating_bottom_nav.dart';
import '../event_joining/event_join_screen.dart';
import '../event_creation/event_creation_screen.dart';
import '../nft_collection/nft_viewer_screen.dart';
import '../wallet/wallet_connection_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0; // Default to Join Event

  @override
  Widget build(BuildContext context) {
    // Restore wallet state when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(globalWalletServiceProvider).restoreWalletState();
    });

    return WalletConnectionWrapper(
      requireWallet: true,
      redirectRoute: '/wallet/connect',
      child: FloatingNavLayout(
        currentIndex: _currentIndex,
        onNavTap: _onNavTap,
        child: _buildCurrentScreen(),
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return const EventJoinScreen();
      case 1:
        return const EventCreationScreen();
      case 2:
        return const NFTViewerScreen();
      case 3:
        return const WalletConnectionScreen();
      default:
        return const EventJoinScreen();
    }
  }

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
}