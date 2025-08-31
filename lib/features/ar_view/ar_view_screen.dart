import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:confetti/confetti.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/ar_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/services/wallet_service.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/boundary.dart';
import '../../../core/theme/retro_theme.dart';

// AR Element class for positioning NFT images in 3D space
class ARElement {
  final Boundary boundary;
  final double screenX;
  final double screenY;
  final double distance;
  final bool isClaimable;
  final bool isVisible;

  ARElement({
    required this.boundary,
    required this.screenX,
    required this.screenY,
    required this.distance,
    required this.isClaimable,
    required this.isVisible,
  });
}

class RetroARViewScreen extends ConsumerStatefulWidget {
  final String eventCode;

  const RetroARViewScreen({super.key, required this.eventCode});

  @override
  ConsumerState<RetroARViewScreen> createState() => _RetroARViewScreenState();
}

class _RetroARViewScreenState extends ConsumerState<RetroARViewScreen> 
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  
  late ARService arService;
  late SupabaseService supabaseService;
  late WalletService walletService;

  Event? currentEvent;
  List<Boundary> boundaries = [];
  List<Boundary> claimedBoundaries = [];
  List<Boundary> visibleBoundaries = [];

  // UI State
  bool isLoading = true;
  bool isCameraInitialized = false;
  String proximityHint = "▸ INITIALIZING AR SYSTEM...";
  int claimedCount = 0;
  int totalBoundaries = 0;
  Boundary? detectedBoundary;
  
  // Performance optimization
  Timer? _arUpdateTimer;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  
  // Enhanced NFT image cache
  final Map<String, Widget> _nftImageCache = {};
  final Map<String, DateTime> _imageCacheTimestamp = {};
  static const int _maxCacheSize = 50;
  static const Duration _cacheExpiry = Duration(minutes: 10);

  // AR Positioning and Sensors
  double? _currentLatitude;
  double? _currentLongitude;
  double _deviceAzimuth = 0.0;
  
  // AR Elements positioning
  List<ARElement> arElements = [];
  
  // Animations
  late ConfettiController confettiController;
  late AnimationController pulseController;
  late Animation<double> pulseAnimation;
  late AnimationController scanlineController;
  late Animation<double> scanlineAnimation;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupAnimations();
    _loadEventData();
    _initializeCamera();
    _initializeSensors();
  }

  void _initializeServices() {
    arService = ARService();
    supabaseService = SupabaseService();
    walletService = WalletService();
  }

  void _setupAnimations() {
    confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    // Retro scanning pulse animation
    pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
    );
    pulseController.repeat(reverse: true);

    // Scanline animation for retro effect
    scanlineController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    scanlineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: scanlineController, curve: Curves.linear),
    );
    scanlineController.repeat();
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
          proximityHint = "▸ AR CAMERA ONLINE - SCANNING...";
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
      setState(() {
        proximityHint = "▸ ERROR: CAMERA INIT FAILED";
      });
    }
  }

  void _initializeSensors() {
    _gyroscopeSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      _throttledARUpdate();
    });

    _magnetometerSubscription = magnetometerEventStream().listen((MagnetometerEvent event) {
      double azimuth = atan2(event.y, event.x) * 180 / pi;
      if ((azimuth - _deviceAzimuth).abs() > 2.0) {
        setState(() {
          _deviceAzimuth = azimuth;
        });
        _throttledARUpdate();
      }
    });
  }
  
  void _throttledARUpdate() {
    _arUpdateTimer?.cancel();
    _arUpdateTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        _updateARPositions();
      }
    });
  }

  void _updateARPositions() {
    if (_currentLatitude == null || _currentLongitude == null || boundaries.isEmpty) {
      return;
    }

    List<ARElement> newElements = [];
    
    for (Boundary boundary in boundaries) {
      // Skip if already claimed by anyone
      if (boundary.isClaimed) continue;
      
      double distance = boundary.distanceFrom(_currentLatitude!, _currentLongitude!);
      
      // Only show boundaries within detection range
      if (distance > 10.0) continue;
      
      // Calculate bearing and relative angle
      double bearing = _calculateBearing(
        _currentLatitude!, _currentLongitude!, 
        boundary.latitude, boundary.longitude
      );
      double relativeAngle = bearing - _deviceAzimuth;
      
      // Normalize angle
      while (relativeAngle > 180) relativeAngle -= 360;
      while (relativeAngle < -180) relativeAngle += 360;
      
      // Only show if within field of view
      if (relativeAngle.abs() > 90) continue;
      
      // Calculate screen coordinates
      double screenWidth = MediaQuery.of(context).size.width;
      double screenHeight = MediaQuery.of(context).size.height;
      
      double screenX = screenWidth / 2 + (relativeAngle * screenWidth / 180);
      double screenY = screenHeight * 0.4 + (distance * 15);
      
      // Add some variation for natural positioning
      screenX += (Random().nextDouble() - 0.5) * 30;
      screenY += (Random().nextDouble() - 0.5) * 20;
      
      // Clamp to screen bounds
      screenX = screenX.clamp(80.0, screenWidth - 80.0);
      screenY = screenY.clamp(180.0, screenHeight - 280.0);
      
      bool isClaimable = distance <= (boundary.radius ?? 2.0);
      bool isVisible = distance <= 15.0;
      
      newElements.add(ARElement(
        boundary: boundary,
        screenX: screenX,
        screenY: screenY,
        distance: distance,
        isClaimable: isClaimable,
        isVisible: isVisible,
      ));
    }
    
    setState(() {
      arElements = newElements;
      if (arElements.isNotEmpty) {
        final closest = arElements.reduce((a, b) => a.distance < b.distance ? a : b);
        if (closest.isClaimable) {
          proximityHint = "▸ TARGET ACQUIRED - TAP TO CLAIM!";
          detectedBoundary = closest.boundary;
        } else {
          proximityHint = "▸ SCANNING... ${closest.distance.toStringAsFixed(1)}M TO TARGET";
        }
      } else {
        proximityHint = "▸ NO TARGETS IN RANGE - KEEP EXPLORING";
      }
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
      print('=== AR SCREEN: LOADING EVENT DATA ===');
      print('Received event code: "${widget.eventCode}"');
      print('Event code length: ${widget.eventCode.length}');
      print('Event code is empty: ${widget.eventCode.isEmpty}');
      
      setState(() {
        isLoading = true;
        proximityHint = "▸ LOADING EVENT DATA...";
      });
      
      if (widget.eventCode.isEmpty) {
        print('ERROR: Event code is empty!');
        setState(() {
          isLoading = false;
          proximityHint = "▸ ERROR: NO EVENT CODE PROVIDED";
        });
        return;
      }
      
      // First, let's see what event codes are available in the database
      print('=== CHECKING AVAILABLE EVENT CODES ===');
      final availableEventCodes = await supabaseService.getAllEventCodes();
      print('Available event codes: $availableEventCodes');
      
      // Test if the event code exists before trying to load it
      print('Testing if event code exists: ${widget.eventCode}');
      final eventExists = await supabaseService.testEventCodeExists(widget.eventCode);
      
      if (!eventExists) {
        print('ERROR: Event code ${widget.eventCode} does not exist in database');
        print('Available event codes: $availableEventCodes');
        setState(() {
          isLoading = false;
          proximityHint = "▸ ERROR: EVENT CODE NOT FOUND";
        });
        return;
      }
      
      print('Event code exists, proceeding to load event data...');
      print('Calling getEventByCode with: ${widget.eventCode}');
      
      currentEvent = await supabaseService.getEventByCode(widget.eventCode);
      
      print('getEventByCode result: ${currentEvent != null ? "SUCCESS" : "FAILED"}');
      if (currentEvent != null) {
        print('Event loaded successfully:');
        print('  - Name: ${currentEvent!.name}');
        print('  - ID: ${currentEvent!.id}');
        print('  - Event Code: ${currentEvent!.eventCode}');
        print('  - Boundaries count: ${currentEvent!.boundaries.length}');
        
        boundaries = currentEvent!.boundaries;
        totalBoundaries = boundaries.length;
        
        // Load claimed boundaries for this event
        await _loadClaimedBoundaries();
        
        await arService.setEvent(currentEvent!);
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
          proximityHint = "▸ EVENT LOADED - AR ACTIVE";
        });
      } else {
        print('ERROR: getEventByCode returned null even though event exists');
        print('This suggests an issue in the data processing or conversion');
        setState(() {
          isLoading = false;
          proximityHint = "▸ ERROR: EVENT CODE INVALID";
        });
      }
    } catch (e) {
      print('Error loading event: $e');
      print('Error type: ${e.runtimeType}');
      print('Full error details: ${e.toString()}');
      setState(() {
        isLoading = false;
        proximityHint = "▸ ERROR: FAILED TO LOAD EVENT";
      });
    }
  }

  Future<void> _loadClaimedBoundaries() async {
    try {
      final claimed = await supabaseService.getClaimedBoundariesForEvent(currentEvent!.id);
      setState(() {
        claimedBoundaries = claimed;
        claimedCount = claimed.length;
        
        // Update boundaries list to reflect claimed status
        for (int i = 0; i < boundaries.length; i++) {
          final claimedBoundary = claimed.firstWhere(
            (c) => c.id == boundaries[i].id,
            orElse: () => boundaries[i],
          );
          if (claimedBoundary.isClaimed) {
            boundaries[i] = claimedBoundary;
          }
        }
      });
    } catch (e) {
      print('Error loading claimed boundaries: $e');
    }
  }

  void _onBoundaryDetected(Boundary boundary) {
    if (!mounted) return;
    setState(() {
      detectedBoundary = boundary;
      proximityHint = "▸ BOUNDARY DETECTED - READY TO CLAIM!";
    });
  }

  void _onBoundaryClaimed(Boundary boundary) {
    if (!mounted) return;
    setState(() {
      claimedBoundaries.add(boundary);
      claimedCount = claimedBoundaries.length;
      detectedBoundary = null;
      proximityHint = "▸ CLAIM SUCCESSFUL - KEEP EXPLORING!";
      
      final index = boundaries.indexWhere((b) => b.id == boundary.id);
      if (index != -1) {
        boundaries[index] = boundaries[index].copyWith(isClaimed: true);
      }
    });
    
    confettiController.play();
    _showRetroClaimSuccessDialog(boundary);
    _updateARPositions();
  }

  void _onProximityUpdate(String hint) {
    if (!mounted) return;
    setState(() {
      proximityHint = "▸ $hint";
    });
  }

  void _onProgressUpdate(int claimed, int total) {
    if (!mounted) return;
    setState(() {
      claimedCount = claimed;
      totalBoundaries = total;
    });
  }

  void _onVisibleBoundariesUpdate(List<Boundary> visible) {
    if (!mounted) return;
    setState(() {
      visibleBoundaries = visible;
    });
  }

  void _onClaimedBoundariesUpdate(List<Boundary> claimed) {
    if (!mounted) return;
    setState(() {
      claimedBoundaries = claimed;
      claimedCount = claimed.length;
    });
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    setState(() {
      _currentLatitude = position.latitude;
      _currentLongitude = position.longitude;
    });
    _updateARPositions();
  }

  Future<void> _claimBoundary(ARElement element) async {
    try {
      setState(() {
        proximityHint = "▸ CLAIMING BOUNDARY...";
      });

      final walletAddress = walletService.connectedWalletAddress ?? 'demo_wallet_${DateTime.now().millisecondsSinceEpoch}';
      
      // Enhanced claim with all necessary database updates
      final success = await supabaseService.claimBoundaryWithFullUpdate(
        boundaryId: element.boundary.id,
        claimedBy: walletAddress,
        distance: element.distance,
        claimTxHash: 'tx_${DateTime.now().millisecondsSinceEpoch}', // Would be real tx hash
        nftMetadata: {
          'name': element.boundary.name,
          'description': element.boundary.description,
          'image': element.boundary.imageUrl,
          'claimed_at': DateTime.now().toIso8601String(),
          'location': {
            'lat': element.boundary.latitude,
            'lng': element.boundary.longitude,
          },
          'event': currentEvent?.name,
        },
      );
      
      if (success) {
        // Update local state
        final updatedBoundary = element.boundary.copyWith(
          isClaimed: true,
          claimedBy: walletAddress,
          claimedAt: DateTime.now(),
        );
        
        arService.claimBoundary(updatedBoundary);
        
        setState(() {
          final index = boundaries.indexWhere((b) => b.id == element.boundary.id);
          if (index != -1) {
            boundaries[index] = updatedBoundary;
          }
          claimedBoundaries.add(updatedBoundary);
          claimedCount = claimedBoundaries.length;
        });
        
        _updateARPositions();
      } else {
        setState(() {
          proximityHint = "▸ CLAIM FAILED - ALREADY CLAIMED";
        });
        
        // Reload event data to sync with server
        await _loadEventData();
      }
    } catch (e) {
      print('Error claiming boundary: $e');
      setState(() {
        proximityHint = "▸ ERROR: CLAIM FAILED";
      });
    }
  }

  void _showRetroClaimSuccessDialog(Boundary boundary) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: RetroTheme.primaryGreen,
            border: Border.all(color: RetroTheme.brightGreen, width: 3),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: RetroTheme.darkGreen,
              border: Border.all(color: RetroTheme.primaryGreen, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Retro success header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: RetroTheme.brightGreen,
                    border: Border.all(color: RetroTheme.lightGreen, width: 2),
                  ),
                  child: Text(
                    '>>> CLAIM SUCCESSFUL <<<',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      color: RetroTheme.darkGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // NFT display
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: RetroTheme.brightGreen, width: 3),
                    color: RetroTheme.primaryGreen,
                  ),
                  child: _buildPixelatedNFTImage(boundary.imageUrl),
                ),
                const SizedBox(height: 16),
                
                // Boundary info
                Text(
                  boundary.name.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Courier',
                    color: RetroTheme.brightGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                Text(
                  boundary.description.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Courier',
                    color: RetroTheme.lightGreen,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                
                // Retro continue button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                    decoration: BoxDecoration(
                      color: RetroTheme.primaryGreen,
                      border: Border.all(color: RetroTheme.brightGreen, width: 2),
                    ),
                    child: Text(
                      '[ CONTINUE ]',
                      style: TextStyle(
                        fontFamily: 'Courier',
                        color: RetroTheme.brightGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildPixelatedNFTImage(String imageUrl) {
    if (_nftImageCache.containsKey(imageUrl)) {
      final timestamp = _imageCacheTimestamp[imageUrl];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _nftImageCache[imageUrl]!;
      }
    }
    
    Widget imageWidget;
    
    if (imageUrl.startsWith('http')) {
      imageWidget = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.none, // Pixelated effect
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            _nftImageCache[imageUrl] = child;
            _imageCacheTimestamp[imageUrl] = DateTime.now();
            return child;
          }
          return Container(
            color: RetroTheme.primaryGreen,
            child: Center(
              child: Text(
                'LOADING...',
                style: TextStyle(
                  fontFamily: 'Courier',
                  color: RetroTheme.brightGreen,
                  fontSize: 10,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultPixelatedNFT();
        },
      );
    } else {
      imageWidget = _buildDefaultPixelatedNFT();
    }
    
    return imageWidget;
  }

  Widget _buildDefaultPixelatedNFT() {
    return Container(
      color: RetroTheme.primaryGreen,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: RetroTheme.brightGreen,
                border: Border.all(color: RetroTheme.lightGreen, width: 1),
              ),
              child: Center(
                child: Container(
                  width: 16,
                  height: 16,
                  color: RetroTheme.lightGreen,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'NFT',
              style: TextStyle(
                fontFamily: 'Courier',
                color: RetroTheme.brightGreen,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera View with retro overlay
          if (isCameraInitialized && _cameraController != null)
            Stack(
              children: [
                ClipRect(child: CameraPreview(_cameraController!)),
                // Retro scanline effect
                AnimatedBuilder(
                  animation: scanlineAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: MediaQuery.of(context).size.height * scanlineAnimation.value,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              RetroTheme.brightGreen.withOpacity(0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            )
          else
            _buildRetroLoadingScreen(),
          
          // AR Overlay
          _buildRetroAROverlay(),
          
          // Top UI
          _buildRetroTopOverlay(),
          
          // Bottom UI
          _buildRetroBottomOverlay(),
          
          // Loading overlay
          if (isLoading) _buildRetroLoadingOverlay(),
          
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
              colors: [RetroTheme.brightGreen, RetroTheme.primaryGreen, RetroTheme.lightGreen],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetroLoadingScreen() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: RetroTheme.darkGreen,
                border: Border.all(color: RetroTheme.primaryGreen, width: 3),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: RetroTheme.brightGreen, width: 2),
                    ),
                    child: Center(
                      child: AnimatedBuilder(
                        animation: scanlineController,
                        builder: (context, child) {
                          return Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: RetroTheme.primaryGreen.withOpacity(scanlineAnimation.value),
                              border: Border.all(color: RetroTheme.brightGreen, width: 1),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'INITIALIZING AR CAMERA',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      color: RetroTheme.brightGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'LOADING SYSTEM MODULES...',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      color: RetroTheme.lightGreen,
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

  Widget _buildRetroAROverlay() {
    return Stack(
      children: arElements.map((element) {
        if (!element.isVisible) return const SizedBox.shrink();
        
        return Positioned(
          left: element.screenX - 60,
          top: element.screenY - 60,
          child: GestureDetector(
            onTap: () async {
              if (element.isClaimable) {
                await _claimBoundary(element);
              }
            },
            child: AnimatedBuilder(
              animation: element.isClaimable ? pulseAnimation : scanlineAnimation,
              builder: (context, child) {
                return Container(
                  width: 120,
                  height: 140,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: element.isClaimable 
                          ? RetroTheme.brightGreen 
                          : RetroTheme.primaryGreen,
                      width: element.isClaimable 
                          ? 3 + (pulseAnimation.value * 2) 
                          : 2,
                    ),
                    color: element.isClaimable
                        ? RetroTheme.darkGreen.withOpacity(0.8 + pulseAnimation.value * 0.2)
                        : RetroTheme.darkGreen.withOpacity(0.6),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        color: element.isClaimable 
                            ? RetroTheme.brightGreen 
                            : RetroTheme.primaryGreen,
                        child: Text(
                          element.isClaimable ? 'TARGET' : 'DETECTED',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            color: RetroTheme.darkGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      // NFT Image
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: element.isClaimable 
                                  ? RetroTheme.brightGreen 
                                  : RetroTheme.primaryGreen,
                              width: 1,
                            ),
                          ),
                          child: _buildPixelatedNFTImage(element.boundary.imageUrl),
                        ),
                      ),
                      
                      // Action indicator
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        color: element.isClaimable 
                            ? RetroTheme.brightGreen 
                            : RetroTheme.primaryGreen,
                        child: Text(
                          element.isClaimable 
                              ? 'TAP TO CLAIM' 
                              : '${element.distance.toStringAsFixed(1)}M',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            color: RetroTheme.darkGreen,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
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

  Widget _buildRetroTopOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: RetroTheme.darkGreen,
                border: Border.all(color: RetroTheme.primaryGreen, width: 2),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      arService.dispose();
                      context.go('/wallet/options');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: RetroTheme.primaryGreen,
                        border: Border.all(color: RetroTheme.brightGreen, width: 1),
                      ),
                      child: Text(
                        '<<',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          color: RetroTheme.brightGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (currentEvent?.name ?? 'EVENT').toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Courier',
                        color: RetroTheme.brightGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showRetroEventInfo,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: RetroTheme.primaryGreen,
                        border: Border.all(color: RetroTheme.brightGreen, width: 1),
                      ),
                      child: Text(
                        'INFO',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          color: RetroTheme.brightGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _testDatabaseConnection,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: RetroTheme.primaryGreen,
                        border: Border.all(color: RetroTheme.brightGreen, width: 1),
                      ),
                      child: Text(
                        'TEST',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          color: RetroTheme.brightGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Proximity hint with retro styling
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RetroTheme.darkGreen,
                border: Border.all(color: RetroTheme.primaryGreen, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: scanlineAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: RetroTheme.brightGreen.withOpacity(scanlineAnimation.value),
                              border: Border.all(color: RetroTheme.brightGreen, width: 1),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          proximityHint,
                          style: TextStyle(
                            fontFamily: 'Courier',
                            color: RetroTheme.brightGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (arElements.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: RetroTheme.primaryGreen,
                        border: Border.all(color: RetroTheme.lightGreen, width: 1),
                      ),
                      child: Text(
                        'TARGETS IN VIEW: ${arElements.length}',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          color: RetroTheme.darkGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Progress display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RetroTheme.darkGreen,
                border: Border.all(color: RetroTheme.primaryGreen, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PROGRESS',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          color: RetroTheme.brightGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${claimedCount.clamp(0, totalBoundaries)}/$totalBoundaries',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          color: RetroTheme.lightGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Retro progress bar
                  Container(
                    height: 16,
                    decoration: BoxDecoration(
                      border: Border.all(color: RetroTheme.primaryGreen, width: 1),
                    ),
                    child: Stack(
                      children: [
                        Container(color: RetroTheme.darkGreen),
                        FractionallySizedBox(
                          widthFactor: totalBoundaries > 0 
                              ? (claimedCount / totalBoundaries).clamp(0.0, 1.0) 
                              : 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: RetroTheme.brightGreen,
                              border: Border.all(color: RetroTheme.lightGreen, width: 1),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildRetroBottomOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showRetroClaimedBoundaries,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: RetroTheme.darkGreen,
                      border: Border.all(color: RetroTheme.brightGreen, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        'CLAIMED ($claimedCount)',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          color: RetroTheme.brightGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _showRetroEventInfo,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: RetroTheme.darkGreen,
                      border: Border.all(color: RetroTheme.primaryGreen, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        'EVENT INFO',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          color: RetroTheme.primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Widget _buildRetroLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: RetroTheme.darkGreen,
            border: Border.all(color: RetroTheme.primaryGreen, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: scanlineAnimation,
                builder: (context, child) {
                  return Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: RetroTheme.brightGreen, width: 2),
                      color: RetroTheme.primaryGreen.withOpacity(scanlineAnimation.value * 0.5),
                    ),
                    child: Center(
                      child: Text(
                        'AR',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          color: RetroTheme.brightGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'LOADING EVENT DATA...',
                style: TextStyle(
                  fontFamily: 'Courier',
                  color: RetroTheme.brightGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'CODE: ${widget.eventCode}',
                style: TextStyle(
                  fontFamily: 'Courier',
                  color: RetroTheme.lightGreen,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRetroClaimedBoundaries() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: RetroTheme.primaryGreen,
            border: Border.all(color: RetroTheme.brightGreen, width: 3),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: RetroTheme.darkGreen,
              border: Border.all(color: RetroTheme.primaryGreen, width: 2),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: RetroTheme.brightGreen,
                    border: Border(
                      bottom: BorderSide(color: RetroTheme.primaryGreen, width: 2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '>>> CLAIMED NFTS <<<',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          color: RetroTheme.darkGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '($claimedCount)',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          color: RetroTheme.darkGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: claimedBoundaries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  border: Border.all(color: RetroTheme.primaryGreen, width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    '?',
                                    style: TextStyle(
                                      fontFamily: 'Courier',
                                      color: RetroTheme.primaryGreen,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'NO NFTS CLAIMED YET',
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  color: RetroTheme.primaryGreen,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'EXPLORE THE AREA TO FIND TARGETS',
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  color: RetroTheme.lightGreen,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: claimedBoundaries.length,
                          itemBuilder: (context, index) {
                            final boundary = claimedBoundaries[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: RetroTheme.primaryGreen,
                                border: Border.all(color: RetroTheme.brightGreen, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: RetroTheme.brightGreen, width: 1),
                                    ),
                                    child: _buildPixelatedNFTImage(boundary.imageUrl),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          boundary.name.toUpperCase(),
                                          style: TextStyle(
                                            fontFamily: 'Courier',
                                            color: RetroTheme.darkGreen,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          boundary.description.toUpperCase(),
                                          style: TextStyle(
                                            fontFamily: 'Courier',
                                            color: RetroTheme.darkGreen,
                                            fontSize: 8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: RetroTheme.brightGreen,
                                      border: Border.all(color: RetroTheme.lightGreen, width: 1),
                                    ),
                                    child: Text(
                                      'CLAIMED',
                                      style: TextStyle(
                                        fontFamily: 'Courier',
                                        color: RetroTheme.darkGreen,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: RetroTheme.primaryGreen,
                        border: Border.all(color: RetroTheme.brightGreen, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '[ CLOSE ]',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            color: RetroTheme.brightGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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

  void _testDatabaseConnection() async {
    try {
      print('=== TESTING DATABASE CONNECTION ===');
      
      // Test basic connection
      final connectionTest = await supabaseService.testDatabaseConnection();
      print('Database connection test: ${connectionTest ? "SUCCESS" : "FAILED"}');
      
      // Get all event codes
      final eventCodes = await supabaseService.getAllEventCodes();
      print('Available event codes: $eventCodes');
      
      // Test specific event code
      if (widget.eventCode.isNotEmpty) {
        final eventExists = await supabaseService.testEventCodeExists(widget.eventCode);
        print('Event code ${widget.eventCode} exists: $eventExists');
      }
      
      // Show results in UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: RetroTheme.darkGreen,
                border: Border.all(color: RetroTheme.primaryGreen, width: 1),
              ),
              child: Text(
                'DB TEST: ${connectionTest ? "OK" : "FAILED"} | EVENTS: ${eventCodes.length}',
                style: TextStyle(
                  fontFamily: 'Courier',
                  color: RetroTheme.brightGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
          ),
        );
      }
    } catch (e) {
      print('Error testing database connection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: RetroTheme.darkGreen,
                border: Border.all(color: RetroTheme.primaryGreen, width: 1),
              ),
              child: Text(
                'DB TEST ERROR: $e',
                style: TextStyle(
                  fontFamily: 'Courier',
                  color: RetroTheme.brightGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
          ),
        );
      }
    }
  }

  void _showRetroEventInfo() {
    if (currentEvent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: RetroTheme.darkGreen,
              border: Border.all(color: RetroTheme.primaryGreen, width: 1),
            ),
            child: Text(
              'EVENT DATA NOT AVAILABLE',
              style: TextStyle(
                fontFamily: 'Courier',
                color: RetroTheme.brightGreen,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: RetroTheme.primaryGreen,
            border: Border.all(color: RetroTheme.brightGreen, width: 3),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: RetroTheme.darkGreen,
              border: Border.all(color: RetroTheme.primaryGreen, width: 2),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: RetroTheme.brightGreen,
                    border: Border(
                      bottom: BorderSide(color: RetroTheme.primaryGreen, width: 2),
                    ),
                  ),
                  child: Text(
                    '>>> EVENT DATA <<<',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      color: RetroTheme.darkGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRetroInfoRow('NAME', currentEvent!.name.toUpperCase()),
                        _buildRetroInfoRow('DESCRIPTION', currentEvent!.description.toUpperCase()),
                        _buildRetroInfoRow('VENUE', currentEvent!.venueName.toUpperCase()),
                        _buildRetroInfoRow('TOTAL NFTS', '${currentEvent!.boundaries.length}'),
                        _buildRetroInfoRow('CLAIMED', '$claimedCount'),
                        _buildRetroInfoRow('EVENT CODE', currentEvent!.eventCode.toUpperCase()),
                        if (currentEvent!.startDate != null)
                          _buildRetroInfoRow('START', currentEvent!.startDate.toString().substring(0, 16).toUpperCase()),
                        if (currentEvent!.endDate != null)
                          _buildRetroInfoRow('END', currentEvent!.endDate.toString().substring(0, 16).toUpperCase()),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: RetroTheme.primaryGreen,
                        border: Border.all(color: RetroTheme.brightGreen, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '[ CLOSE ]',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            color: RetroTheme.brightGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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

  Widget _buildRetroInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 10,
              color: RetroTheme.lightGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: RetroTheme.primaryGreen,
              border: Border.all(color: RetroTheme.brightGreen, width: 1),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
                color: RetroTheme.darkGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    arService.onBoundaryDetected = null;
    arService.onBoundaryClaimed = null;
    arService.onProximityUpdate = null;
    arService.onProgressUpdate = null;
    arService.onVisibleBoundariesUpdate = null;
    arService.onClaimedBoundariesUpdate = null;
    arService.onPositionUpdate = null;
    
    _arUpdateTimer?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    
    confettiController.dispose();
    pulseController.dispose();
    scanlineController.dispose();
    _cameraController?.dispose();
    
    _nftImageCache.clear();
    _imageCacheTimestamp.clear();
    
    arService.dispose();
    super.dispose();
  }
}