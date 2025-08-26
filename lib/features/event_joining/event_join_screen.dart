import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:face_reflector/core/theme/app_theme.dart';
import 'package:face_reflector/core/providers/providers.dart';

class EventJoinScreen extends ConsumerStatefulWidget {
  const EventJoinScreen({super.key});

  @override
  ConsumerState<EventJoinScreen> createState() => _EventJoinScreenState();
}

class _EventJoinScreenState extends ConsumerState<EventJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _eventCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withOpacity(0.1),
              AppTheme.secondaryColor.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/wallet/options'),
                      icon: const Icon(Icons.arrow_back_ios),
                      color: Colors.grey[600],
                    ),
                    const Spacer(),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Main Content
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 50,
                          color: Colors.white,
                        ),
                      ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                      
                      const SizedBox(height: 32),
                      
                      // Title
                      Text(
                        'Join Event',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                          color: Colors.grey[800],
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
                      
                      const SizedBox(height: 16),
                      
                      // Description
                      Text(
                        'Enter the event code provided by the organizer to start claiming goodies',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontFamily: 'Inter',
                          height: 1.5,
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),
                      
                      const SizedBox(height: 48),
                      
                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Event Code Input
                            TextFormField(
                              controller: _eventCodeController,
                              decoration: InputDecoration(
                                labelText: 'Event Code',
                                hintText: 'e.g., TECH24',
                                prefixIcon: const Icon(Icons.qr_code),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              textCapitalization: TextCapitalization.characters,
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
                            
                            // Join Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _joinEvent,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Joining...',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.play_arrow_rounded),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Join Event',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.3),
                            
                            const SizedBox(height: 24),
                            
                            // Demo Event Button
                            TextButton(
                              onPressed: () => _joinDemoEvent(),
                              child: Text(
                                'Try Demo Event (TECH24)',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ).animate().fadeIn(delay: 1000.ms),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Footer
                Text(
                  'Make sure you\'re at the event venue to claim goodies',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontFamily: 'Inter',
                  ),
                ).animate().fadeIn(delay: 1200.ms),
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
      if (event != null) {
        ref.read(currentEventProvider.notifier).setEvent(event);
      }
      
      if (mounted) {
        context.go('/ar-view?eventCode=$eventCode');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event not found: $e'),
            backgroundColor: AppTheme.errorColor,
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
