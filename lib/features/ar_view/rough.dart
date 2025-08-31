import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:confetti/confetti.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../../../shared/services/ar_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/services/wallet_service.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/boundary.dart';
import '../../../core/theme/app_theme.dart';

// Professional AR Element class
class ProfessionalARElement {
  final Boundary boundary;
  final double screenX;
  final double screenY;
  final double distance;
  final bool isClaimable;
  final bool isVisible;
  final bool isClaimed;
  final String claimStatus;
  final double progressPercentage;

  ProfessionalARElement({
    required this.boundary,
    required this.screenX,
    required this.screenY,
    required this.distance,
    required this.isClaimable,
    required this.isVisible,
    required this.isClaimed,
    required this.claimStatus,
    required this.progressPercentage,
  });
}

class ProfessionalARViewScreen extends ConsumerStatefulWidget {
  final String eventCode;

  const ProfessionalARViewScreen({super.key, required this.eventCode});

  @override
  ConsumerState<ProfessionalARViewScreen> createState() => _ProfessionalARViewScreenState();
}

class _ProfessionalARViewScreenState extends ConsumerState<ProfessionalARViewScreen> with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  
  late ARService arService;
  late SupabaseService supabaseService;
  late WalletService walletService;

  Event? currentEvent;
  List<Boundary> allBoundaries = [];
  List<Boundary> userClaimedBoundaries = [];
  List<ProfessionalARElement> visibleARElements = [];

  // UI State
  bool isLoading = true;
  bool isCameraInitialized = false;
  String proximityHint = "Initializing AR experience...";
  int userClaimedCount = 0;
  int totalBoundaries = 0;
  int eventClaimedCount = 0;
  Boundary? detectedBoundary;
  
  // Performance optimization
  Timer? _arUpdateTimer;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  
  // Enhanced image cache with memory management
  final Map<String, Widget> _nftImageCache = {};
  final Map<String, DateTime> _imageCacheTimestamp = {};
  static const int _maxCacheSize = 60;
  static const Duration _cacheExpiry = Duration(minutes: 15);

  // AR Positioning and Sensors
  double? _currentLatitude;
  double? _currentLongitude;
  double _deviceAzimuth = 0.0;
  // Note: Pitch and roll sensors available for future AR enhancements
  
  // Configurable settings
  double _visibilityRadius = 2.0; // Default 2 meters  
  final double _notificationDistance = 5.0; // Show notifications within 5 meters
  
  // Professional Animations
  late ConfettiController confettiController;
  late AnimationController rotationController;
  late Animation<double> rotationAnimation;
  late AnimationController glowController;
  late Animation<double> glowAnimation;
  late AnimationController pulseController;
  late Animation<double> pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupProfessionalAnimations();
    _loadEventData();
    _initializeCamera();
    _initializeSensors();
  }

  void _initializeServices() {
    arService = ARService();
    supabaseService = SupabaseService();
    walletService = WalletService();
  }

  void _setupProfessionalAnimations() {
    confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    // Smooth rotation animation for NFT images
    rotationController = AnimationController(
      duration: const Duration(seconds: 8), // Very slow, elegant rotation
      vsync: this,
    );
    rotationAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: rotationController, curve: Curves.linear),
    );
    rotationController.repeat();

    // Subtle glow effect for claimable boundaries
    glowController = AnimationController(
      duration: const Duration(seconds: 4), // Gentle pulsing glow
      vsync: this,
    );
    glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: glowController, curve: Curves.easeInOut),
    );
    glowController.repeat(reverse: true);

    // Pulse animation for detected boundaries
    pulseController = AnimationController(
      duration: const Duration(seconds: 2), // Quick pulse for detection
      vsync: this,
    );
    pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        setState(() {
          isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void _initializeSensors() {
    // Optimized sensor updates with throttling
    _gyroscopeSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      // Future: Use gyroscope data for enhanced AR positioning
      _throttledARUpdate();
    });

    // Optimized compass/magnetometer updates
    _magnetometerSubscription = magnetometerEventStream().listen((MagnetometerEvent event) {
      double azimuth = atan2(event.y, event.x) * 180 / pi;
      if ((azimuth - _deviceAzimuth).abs() > 1.5) { // More sensitive for professional view
        setState(() {
          _deviceAzimuth = azimuth;
        });
        _throttledARUpdate();
      }
    });
  }
  
  void _throttledARUpdate() {
    _arUpdateTimer?.cancel();
    _arUpdateTimer = Timer(const Duration(milliseconds: 80), () { // Faster updates for professional view
      if (mounted) {
        _updateARPositions();
      }
    });
  }

  void _updateARPositions() {
    if (_currentLatitude == null || _currentLongitude == null || allBoundaries.isEmpty) {
      return;
    }

    List<ProfessionalARElement> newElements = [];
    
    for (Boundary boundary in allBoundaries) {
      // Skip if already claimed by this user
      if (userClaimedBoundaries.any((claimed) => claimed.id == boundary.id)) {
        continue;
      }
      
      // Skip if claimed by someone else
      if (boundary.isClaimed) {
        continue;
      }
      
      double distance = boundary.distanceFrom(_currentLatitude!, _currentLongitude!);
      
      // Only show boundaries within visibility radius (default 2 meters)
      if (distance > _visibilityRadius) {
        continue;
      }
      
      // Calculate bearing to boundary
      double bearing = _calculateBearing(_currentLatitude!, _currentLongitude!, 
                                       boundary.latitude, boundary.longitude);
      
      // Calculate relative angle from device heading
      double relativeAngle = bearing - _deviceAzimuth;
      
      // Normalize angle to -180 to 180 degrees
      while (relativeAngle > 180) {
        relativeAngle -= 360;
      }
      while (relativeAngle < -180) {
        relativeAngle += 360;
      }
      
      // Only show if within 90 degrees of device heading (field of view)
      if (relativeAngle.abs() > 90) continue;
      
      // Convert to screen coordinates
      double screenWidth = MediaQuery.of(context).size.width;
      double screenHeight = MediaQuery.of(context).size.height;
      
      // Map angle to screen X position
      double screenX = screenWidth / 2 + (relativeAngle * screenWidth / 180);
      
      // Map distance to screen Y position with depth perception
      double depthFactor = 1.0 - (distance / _visibilityRadius).clamp(0.0, 1.0);
      double screenY = screenHeight * 0.2 + (distance * 15) - (depthFactor * 50);
      
      // Add minimal randomness for natural positioning
      screenX += (Random().nextDouble() - 0.5) * 10;
      screenY += (Random().nextDouble() - 0.5) * 5;
      
      // Clamp to screen bounds
      screenX = screenX.clamp(75.0, screenWidth - 75.0);
      screenY = screenY.clamp(150.0, screenHeight - 250.0);
      
      bool isClaimable = distance <= boundary.radius;
      bool isVisible = distance <= _visibilityRadius;
      bool isClaimed = boundary.isClaimed;
      
      // Determine claim status
      String claimStatus;
      if (isClaimed) {
        claimStatus = "ALREADY CLAIMED";
      } else if (isClaimable) {
        claimStatus = "TAP TO CLAIM";
      } else {
        claimStatus = "GET CLOSER";
      }
      
      // Calculate progress percentage
      double progressPercentage = ((_notificationDistance - distance) / _notificationDistance * 100).clamp(0.0, 100.0);
      
      newElements.add(ProfessionalARElement(
        boundary: boundary,
        screenX: screenX,
        screenY: screenY,
        distance: distance,
        isClaimable: isClaimable,
        isVisible: isVisible,
        isClaimed: isClaimed,
        claimStatus: claimStatus,
        progressPercentage: progressPercentage,
      ));
    }
    
    setState(() {
      visibleARElements = newElements;
    });
  }

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    double dLon = (lon2 - lon1) * pi / 180;
    double lat1Rad = lat1 * pi / 180;
    double lat2Rad = lat2 * pi / 180;
    
    double y = sin(dLon) * cos(lat2Rad);
    double x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLon);
    
    double bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  Future<void> _loadEventData() async {
    try {
      setState(() => isLoading = true);
      
      print('Loading event with code: ${widget.eventCode}');
      
      // Load event from Supabase
      currentEvent = await supabaseService.getEventByCode(widget.eventCode);
      
      if (currentEvent != null) {
        print('Event loaded successfully: ${currentEvent!.name}');
        
        // Get all boundaries for this event ONLY
        allBoundaries = currentEvent!.boundaries;
        totalBoundaries = allBoundaries.length;
        
        // Get user's claimed boundaries for this event ONLY
        final walletAddress = walletService.connectedWalletAddress ?? 'demo_wallet';
        userClaimedBoundaries = await supabaseService.getUserEventClaims(walletAddress, currentEvent!.id);
        userClaimedCount = userClaimedBoundaries.length;
        
        // Get event statistics for this event ONLY
        final eventStats = await supabaseService.getEventStats(currentEvent!.id);
        eventClaimedCount = eventStats['claimed_boundaries'] ?? 0;
        
        // Set visibility radius from event settings
        _visibilityRadius = currentEvent!.visibilityRadius;
        
        // Set up AR service with event-specific data
        arService.setEvent(currentEvent!);
        arService.onBoundaryDetected = _onBoundaryDetected;
        arService.onBoundaryClaimed = _onBoundaryClaimed;
        arService.onProximityUpdate = _onProximityUpdate;
        arService.onProgressUpdate = _onProgressUpdate;
        arService.onVisibleBoundariesUpdate = _onVisibleBoundariesUpdate;
        arService.onClaimedBoundariesUpdate = _onClaimedBoundariesUpdate;
        arService.onPositionUpdate = _onPositionUpdate;
        
        await arService.initializeAR();
        
        setState(() {
          isLoading = false;
          proximityHint = 'Event "${currentEvent!.name}" loaded! Exploring for boundaries...';
        });
      } else {
        print('Event not found for code: ${widget.eventCode}');
        setState(() {
          isLoading = false;
          proximityHint = "Event not found! Check the event code.";
        });
      }
    } catch (e) {
      print('Error loading event: $e');
      setState(() {
        isLoading = false;
        proximityHint = "Error loading event: $e";
      });
    }
  }

  void _onBoundaryDetected(Boundary boundary) {
    setState(() {
      detectedBoundary = boundary;
      proximityHint = "Boundary detected! Tap to claim!";
    });
    pulseController.forward();
  }

  void _onBoundaryClaimed(Boundary boundary) {
    setState(() {
      userClaimedBoundaries.add(boundary);
      userClaimedCount = userClaimedBoundaries.length;
      detectedBoundary = null;
      
      // Mark the boundary as claimed in the main boundaries list
      final index = allBoundaries.indexWhere((b) => b.id == boundary.id);
      if (index != -1) {
        allBoundaries[index] = allBoundaries[index].copyWith(isClaimed: true);
      }
    });
    
    // Show confetti
    confettiController.play();
    
    // Show success dialog
    _showClaimSuccessDialog(boundary);
    
    // Update AR positions to remove claimed boundary
    _updateARPositions();
  }

  void _onProximityUpdate(String hint) {
    setState(() {
      proximityHint = hint;
    });
  }

  void _onProgressUpdate(int claimed, int total) {
    setState(() {
      userClaimedCount = claimed;
      totalBoundaries = total;
    });
  }

  void _onVisibleBoundariesUpdate(List<Boundary> visible) {
    // Not used in professional version
  }

  void _onClaimedBoundariesUpdate(List<Boundary> claimed) {
    setState(() {
      userClaimedBoundaries = claimed;
      userClaimedCount = claimed.length;
    });
  }

  void _onPositionUpdate(Position position) {
    setState(() {
      _currentLatitude = position.latitude;
      _currentLongitude = position.longitude;
    });
    _updateARPositions();
  }

  Future<void> _claimBoundary(ProfessionalARElement element) async {
    if (!element.isClaimable || element.isClaimed) return;
    
    // Apple-style haptic feedback
    HapticFeedback.mediumImpact();
    
    try {
      final walletAddress = walletService.connectedWalletAddress ?? 'demo_wallet';
      final success = await supabaseService.claimBoundaryForUser(
        element.boundary.id,
        walletAddress,
        element.distance,
      );
      
      if (success) {
        HapticFeedback.heavyImpact(); // Success feedback
        _onBoundaryClaimed(element.boundary);
      } else {
        HapticFeedback.lightImpact(); // Error feedback
        _showAppleStyleAlert(
          'Claim Failed',
          'This boundary has already been claimed by another user.',
          isError: true,
        );
      }
    } catch (e) {
      HapticFeedback.lightImpact(); // Error feedback
      _showAppleStyleAlert(
        'Connection Error',
        'Unable to process claim. Please check your connection and try again.',
        isError: true,
      );
    }
  }

  void _showClaimSuccessDialog(Boundary boundary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.celebration, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text('Boundary Claimed! 🎉'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              boundary.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(boundary.description),
            const SizedBox(height: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You\'ve claimed $userClaimedCount of $totalBoundaries boundaries in this event!',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue Exploring'),
          ),
        ],
      ),
    );
  }

  Widget _buildNFTImage(String imageUrl) {
    // Enhanced cache management with expiry and size limits
    if (_nftImageCache.containsKey(imageUrl)) {
      final timestamp = _imageCacheTimestamp[imageUrl];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _nftImageCache[imageUrl]!;
      } else {
        // Remove expired cache entry
        _nftImageCache.remove(imageUrl);
        _imageCacheTimestamp.remove(imageUrl);
      }
    }
    
    // Clean cache if it exceeds max size
    if (_nftImageCache.length >= _maxCacheSize) {
      _cleanImageCache();
    }
    
    Widget imageWidget;
    
    if (imageUrl.startsWith('http')) {
      imageWidget = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        cacheWidth: 320,
        cacheHeight: 320,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            _nftImageCache[imageUrl] = child;
            _imageCacheTimestamp[imageUrl] = DateTime.now();
            return child;
          }
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.08),
                  AppTheme.secondaryColor.withOpacity(0.06),
                  AppTheme.accentColor.withOpacity(0.04),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      strokeCap: StrokeCap.round,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                      color: AppTheme.primaryColor,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loading Premium NFT',
                    style: TextStyle(
                      color: AppTheme.primaryColor.withOpacity(0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          final defaultWidget = _buildDefaultNFTImage();
          _nftImageCache[imageUrl] = defaultWidget;
          _imageCacheTimestamp[imageUrl] = DateTime.now();
          return defaultWidget;
        },
      );
    } else if (imageUrl.startsWith('/')) {
      imageWidget = Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        cacheWidth: 320,
        cacheHeight: 320,
        errorBuilder: (context, error, stackTrace) {
          final defaultWidget = _buildDefaultNFTImage();
          _nftImageCache[imageUrl] = defaultWidget;
          _imageCacheTimestamp[imageUrl] = DateTime.now();
          return defaultWidget;
        },
      );
    } else {
      imageWidget = _buildDefaultNFTImage();
    }
    
    _nftImageCache[imageUrl] = imageWidget;
    _imageCacheTimestamp[imageUrl] = DateTime.now();
    return imageWidget;
  }

  Widget _buildDefaultNFTImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.12),
            AppTheme.secondaryColor.withOpacity(0.10),
            AppTheme.accentColor.withOpacity(0.08),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.05),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.diamond_outlined,
                color: AppTheme.primaryColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                'Premium NFT',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _cleanImageCache() {
    if (_nftImageCache.length <= _maxCacheSize ~/ 2) return;
    
    // Remove oldest entries
    final sortedEntries = _imageCacheTimestamp.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    
    final entriesToRemove = sortedEntries.take(_nftImageCache.length - _maxCacheSize ~/ 2);
    for (final entry in entriesToRemove) {
      _nftImageCache.remove(entry.key);
      _imageCacheTimestamp.remove(entry.key);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Camera View
          if (isCameraInitialized && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          
          // Professional AR Overlay
          _buildProfessionalAROverlay(),
          
          // Top UI Overlay
          _buildTopOverlay(),
          
          // Bottom UI Overlay
          _buildBottomOverlay(),
          
          // Loading Overlay
          if (isLoading) _buildLoadingOverlay(),
          
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalAROverlay() {
    return Stack(
      children: visibleARElements.map((element) {
        if (!element.isVisible) return const SizedBox.shrink();
        
        return Positioned(
          left: element.screenX - 75,
          top: element.screenY - 75,
          child: GestureDetector(
            onTap: () => _claimBoundary(element),
            child: AnimatedBuilder(
              animation: element.isClaimable ? glowAnimation : rotationAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: element.isClaimable ? 1.0 + (glowAnimation.value * 0.1) : 1.0,
                  child: Column(
                    children: [
                      // NFT Image Container with professional 3D effects
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: element.isClaimable ? AppTheme.primaryColor : Colors.orange,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (element.isClaimable ? AppTheme.primaryColor : Colors.orange).withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: element.isClaimable 
                            ? AnimatedBuilder(
                                animation: rotationAnimation,
                                builder: (context, child) {
                                  return Transform.rotate(
                                    angle: rotationAnimation.value,
                                    child: _buildNFTImage(element.boundary.imageUrl),
                                  );
                                },
                              )
                            : _buildNFTImage(element.boundary.imageUrl),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Premium Professional Status Display
                      Container(
                        constraints: const BoxConstraints(maxWidth: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: element.isClaimable 
                                ? [AppTheme.primaryColor, AppTheme.secondaryColor, AppTheme.accentColor]
                                : [Colors.orange.shade400, Colors.orange.shade600, Colors.deepOrange.shade700],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: (element.isClaimable ? AppTheme.primaryColor : Colors.orange).withValues(alpha: 0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              element.claimStatus,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${element.distance.toStringAsFixed(1)}m',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (!element.isClaimable && !element.isClaimed) ...[
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: element.progressPercentage / 100,
                                backgroundColor: Colors.white.withValues(alpha: 0.3),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                minHeight: 2,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Professional Header with working back button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: () {
                      // Stop AR service and navigate back properly
                      arService.dispose();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      currentEvent?.name ?? 'Event',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: _showEventInfo,
                    icon: const Icon(Icons.info, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Professional Proximity Hint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    proximityHint,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (visibleARElements.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${visibleARElements.length} NFT${visibleARElements.length > 1 ? 's' : ''} within ${_visibilityRadius.toStringAsFixed(1)}m',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Professional Progress Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Progress',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$userClaimedCount/$totalBoundaries',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: totalBoundaries > 0 ? userClaimedCount / totalBoundaries : 0,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Event Total: $eventClaimedCount claimed by all users',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // User Claims Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showUserClaims,
                  icon: const Icon(Icons.celebration),
                  label: Text('My Claims ($userClaimedCount)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Event Info Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showEventInfo,
                  icon: const Icon(Icons.info),
                  label: const Text('Event Info'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading AR Experience...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Event Code: ${widget.eventCode}',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserClaims() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.celebration, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'My Claimed Boundaries (${userClaimedBoundaries.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: userClaimedBoundaries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.explore,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No boundaries claimed yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Explore the event area to find and claim boundaries',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: userClaimedBoundaries.length,
                      itemBuilder: (context, index) {
                        final boundary = userClaimedBoundaries[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green,
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(boundary.name),
                            subtitle: Text(boundary.description),
                            trailing: Text(
                              boundary.claimedAt?.toString().substring(0, 16) ?? '',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventInfo() {
    if (currentEvent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event information not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Event Information',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Event Name', currentEvent!.name),
                    _buildInfoRow('Description', currentEvent!.description),
                    _buildInfoRow('Venue', currentEvent!.venueName),
                    _buildInfoRow('Total Boundaries', '${currentEvent!.boundaries.length}'),
                    _buildInfoRow('Your Claims', '$userClaimedCount'),
                    _buildInfoRow('Event Total Claims', '$eventClaimedCount'),
                    _buildInfoRow('Event Code', currentEvent!.eventCode),
                    _buildInfoRow('Visibility Radius', '${_visibilityRadius.toStringAsFixed(1)}m'),
                    if (currentEvent!.startDate != null)
                      _buildInfoRow('Start Date', currentEvent!.startDate.toString().substring(0, 16)),
                    if (currentEvent!.endDate != null)
                      _buildInfoRow('End Date', currentEvent!.endDate.toString().substring(0, 16)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showAppleStyleAlert(String title, String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: isError ? const Color(0xFFFF3B30) : AppTheme.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 16,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(
                color: isError ? const Color(0xFFFF3B30) : AppTheme.primaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    // Cancel performance optimizations
    _arUpdateTimer?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    
    // Dispose controllers
    confettiController.dispose();
    rotationController.dispose();
    glowController.dispose();
    pulseController.dispose();
    _cameraController?.dispose();
    
    // Clear image caches
    _nftImageCache.clear();
    _imageCacheTimestamp.clear();
    
    // Dispose AR service
    arService.dispose();
    super.dispose();
  }
}