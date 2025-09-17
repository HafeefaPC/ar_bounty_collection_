import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/wallet_connection_wrapper.dart';
import '../../shared/services/global_wallet_service.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  Widget build(BuildContext context) {
    // Restore wallet state when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(globalWalletServiceProvider).restoreWalletState();
    });

    return WalletConnectionWrapper(
      requireWallet: true,
      redirectRoute: '/wallet/connect',
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: AppTheme.modernContainerDecoration.copyWith(
                          color: AppTheme.cardColor,
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: IconButton(
                          onPressed: () => context.go('/wallet/connect'),
                          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textColor),
                        ),
                      ),
                      const Spacer(),
                     
                    
                    ],
                  ),
                ),
              
                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        
                        // Header Section
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                    offset: const Offset(0, 4),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.home_rounded,
                                color: AppTheme.textColor,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AR Boundary Collection',
                                    style: AppTheme.modernTitle.copyWith(
                                      fontSize: 28,
                                      color: AppTheme.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Create and join AR events to collect NFTs',
                                    style: AppTheme.modernBodySecondary.copyWith(
                                      fontSize: 16,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Quick Actions
                        Text(
                          'Quick Actions',
                          style: AppTheme.modernSubtitle.copyWith(
                            color: AppTheme.textColor,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Action Cards
                        _buildQuickActionCard(
                          title: 'Join Event',
                          description: 'Enter event code to join',
                          icon: Icons.event_available_rounded,
                          onTap: () => context.go('/event/join'),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        _buildQuickActionCard(
                          title: 'Create Event',
                          description: 'Create a new AR event',
                          icon: Icons.add_circle_rounded,
                          onTap: () => context.go('/event/create'),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        _buildQuickActionCard(
                          title: 'View NFTs',
                          description: 'See your collected NFTs',
                          icon: Icons.collections_rounded,
                          onTap: () => context.go('/nft-collection'),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: AppTheme.modernContainerDecoration.copyWith(
        color: AppTheme.cardColor,
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.1),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.textColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.modernBody.copyWith(
                        color: AppTheme.textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTheme.modernCaption.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppTheme.textSecondary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
