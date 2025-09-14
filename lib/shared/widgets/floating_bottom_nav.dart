import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class FloatingBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const FloatingBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<FloatingBottomNav> createState() => _FloatingBottomNavState();
}

class _FloatingBottomNavState extends State<FloatingBottomNav> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          _buildNavItem(
            index: 0,
            icon: Icons.event_available_rounded,
            label: 'Join',
            isActive: widget.currentIndex == 0,
          ),
          _buildNavItem(
            index: 1,
            icon: Icons.add_circle_rounded,
            label: 'Create',
            isActive: widget.currentIndex == 1,
          ),
          _buildNavItem(
            index: 2,
            icon: Icons.collections_rounded,
            label: 'NFTs',
            isActive: widget.currentIndex == 2,
          ),
          _buildNavItem(
            index: 3,
            icon: Icons.account_balance_wallet_rounded,
            label: 'Wallet',
            isActive: widget.currentIndex == 3,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => widget.onTap(index),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTheme.modernCaption.copyWith(
                  color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FloatingNavLayout extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final Function(int) onNavTap;

  const FloatingNavLayout({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onNavTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: child,
      bottomNavigationBar: FloatingBottomNav(
        currentIndex: currentIndex,
        onTap: onNavTap,
      ),
    );
  }
}
