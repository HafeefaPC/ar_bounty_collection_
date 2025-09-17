import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:face_reflector/core/theme/app_theme.dart';
import 'package:face_reflector/core/providers/providers.dart';
import 'package:face_reflector/shared/widgets/wallet_connection_wrapper.dart';
import 'package:face_reflector/shared/services/global_wallet_service.dart';

class EventJoinScreen extends ConsumerStatefulWidget {
  final String? initialEventCode;

  const EventJoinScreen({super.key, this.initialEventCode});

  @override
  ConsumerState<EventJoinScreen> createState() => _EventJoinScreenState();
}

class _EventJoinScreenState extends ConsumerState<EventJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill event code if provided
    if (widget.initialEventCode != null) {
      _eventCodeController.text = widget.initialEventCode!;
      // Automatically join the event after a short delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _joinEvent();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _eventCodeController.dispose();
    super.dispose();
  }

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
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: AppTheme.modernScaffoldBackground,
          child: SafeArea(
            child: Column(
              children: [
                // Retro Header
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(0), // Pixelated
                          border: Border.all(
                            color: AppTheme.textColor.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: IconButton(
                          onPressed: () => context.go('/main'),
                          icon: Icon(
                            Icons.arrow_back_ios,
                            color: AppTheme.textColor,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.surfaceColor,
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Wallet connection status
                    ],
                  ),
                ),

                // Scrollable Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // Retro Icon
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(0), // Pixelated
                            border: Border.all(
                              color: AppTheme.textColor,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.6),
                                offset: const Offset(6, 6),
                                blurRadius: 0,
                              ),
                              BoxShadow(
                                color: AppTheme.secondaryColor.withOpacity(0.4),
                                offset: const Offset(3, 3),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 50,
                            color: AppTheme.backgroundColor,
                          ),
                        ).animate().scale(
                          duration: 600.ms,
                          curve: Curves.elasticOut,
                        ),

                        const SizedBox(height: 32),

                        // Retro Title
                        Text(
                          'JOIN EVENT',
                          style: AppTheme.modernTitle.copyWith(
                            fontSize: 28,
                            color: AppTheme.textColor,
                            shadows: [
                              Shadow(
                                offset: const Offset(3, 3),
                                blurRadius: 0,
                                color: AppTheme.primaryColor,
                              ),
                              Shadow(
                                offset: const Offset(6, 6),
                                blurRadius: 0,
                                color: AppTheme.secondaryColor,
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),

                        const SizedBox(height: 16),

                        // Retro Description
                        Text(
                          'Enter the event code provided by the organizer to start claiming goodies',
                          textAlign: TextAlign.center,
                          style: AppTheme.modernBodySecondary.copyWith(
                            fontSize: 16,
                            color: AppTheme.textColor.withOpacity(0.8),
                            height: 1.5,
                          ),
                        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),

                        const SizedBox(height: 48),

                        // Auto-join message if initial event code is provided
                        if (widget.initialEventCode != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(0),
                              border: Border.all(
                                color: AppTheme.primaryColor,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'AUTO-JOINING EVENT: ${widget.initialEventCode}',
                                    style: AppTheme.modernButton.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontSize: 14,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3),
                        ],

                        // Retro Form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Retro Event Code Input
                              TextFormField(
                                controller: _eventCodeController,
                                decoration: InputDecoration(
                                  labelText: 'Event Code',
                                  labelStyle: TextStyle(
                                    color: AppTheme.textColor,
                                  ), // default
                                  floatingLabelStyle: TextStyle(
                                    color: AppTheme.textColor, // when focused
                                    fontWeight: FontWeight.bold,
                                  ),
                                  hintText: 'e.g., TECH24',
                                  prefixIcon: Icon(
                                    Icons.qr_code,
                                    color: AppTheme.textColor,
                                  ),
                                  filled: true,
                                  fillColor: Color.fromARGB(255, 122, 185, 203),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: AppTheme.primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                ),
                                textCapitalization:
                                    TextCapitalization.characters,
                                style: AppTheme.modernBodySecondary.copyWith(
                                  color: AppTheme.textColor,
                                  fontSize: 16,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter an event code';
                                  }
                                  if (value.length < 4) {
                                    return 'Event code must be at least 4 characters';
                                  }
                                  return null;
                                },
                              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3),

                              const SizedBox(height: 32),

                              // Retro Join Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _joinEvent,
                                  style: AppTheme.modernPrimaryButton.copyWith(
                                    backgroundColor: MaterialStateProperty.all(
                                      Color.fromARGB(255, 122, 185, 203),
                                    ),
                                    foregroundColor: MaterialStateProperty.all(
                                      AppTheme.backgroundColor,
                                    ),
                                  ),
                                  child: _isLoading
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(AppTheme.backgroundColor),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'JOINING...',
                                              style: AppTheme.modernButton
                                                  .copyWith(
                                                    fontSize: 16,
                                                    color: AppTheme
                                                        .backgroundColor,
                                                  ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.play_arrow_rounded,
                                              color: AppTheme.backgroundColor,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'JOIN EVENT',
                                              style: AppTheme.modernButton
                                                  .copyWith(
                                                    fontSize: 16,
                                                    color: AppTheme
                                                        .backgroundColor,
                                                  ),
                                            ),
                                          ],
                                        ),
                                ),
                              ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.3),

                              
                                    
                                    
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),
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

  Future<void> _joinEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final eventCode = _eventCodeController.text.trim().toUpperCase();
      final event = await ref.read(eventByCodeProvider(eventCode).future);

      if (event == null) {
        throw Exception('Event not found with code: $eventCode');
      }

      ref.read(currentEventProvider.notifier).setEvent(event);

      if (mounted) {
        context.go('/ar-view?eventCode=$eventCode');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event not found: $e'),
            backgroundColor: AppTheme.errorColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ), // Pixelated
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _joinDemoEvent() async {
    _eventCodeController.text = 'TECH24';
    await _joinEvent();
  }
}
