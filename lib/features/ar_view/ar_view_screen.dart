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
import '../../../shared/models/event.dart';
import '../../../shared/models/boundary.dart';
import '../../../core/theme/app_theme.dart';

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

class ARViewScreen extends ConsumerStatefulWidget {
  final String eventCode;

  const ARViewScreen({super.key, required this.eventCode});

  @override
  ConsumerState<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends ConsumerState<ARViewScreen> with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  
  late ARService arService;
  late SupabaseService supabaseService;

  Event? currentEvent;
  List<Boundary> boundaries = [];
  List<Boundary> claimedBoundaries = [];
  List<Boundary> visibleBoundaries = [];

  // UI State
  bool isLoading = true;
  bool isCameraInitialized = false;
  String proximityHint = "Initializing camera...";
  int claimedCount = 0;
  int totalBoundaries = 0;
  bool showClaimedBoundaries = false;
  Boundary? detectedBoundary;

  // AR Positioning and Sensors
  double? _currentLatitude;
  double? _currentLongitude;
  double _deviceAzimuth = 0.0; // Device heading in degrees
  double _devicePitch = 0.0;   // Device pitch in degrees
  double _deviceRoll = 0.0;    // Device roll in degrees
  
  // AR Elements positioning
  List<ARElement> arElements = [];
  
  // Animations
  late ConfettiController confettiController;
  late AnimationController pulseController;
  late Animation<double> pulseAnimation;
  late AnimationController bounceController;
  late Animation<double> bounceAnimation;

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
  }

  void _setupAnimations() {
    confettiController = ConfettiController(duration: const Duration(seconds: 3));
    pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
    );
    pulseController.repeat(reverse: true);

    bounceController = AnimationController(
      duration: const Duration(seconds: 2), // Slower animation
      vsync: this,
    );
    bounceAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: bounceController, curve: Curves.easeInOut),
    );
    bounceController.repeat(reverse: true); // Make it repeat
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
    // Listen to device orientation changes
    gyroscopeEvents.listen((GyroscopeEvent event) {
      setState(() {
        _devicePitch += event.y * 0.1; // Convert to degrees
        _deviceRoll += event.x * 0.1;
      });
      _updateARPositions();
    });

    // Listen to compass/magnetometer for heading
    magnetometerEvents.listen((MagnetometerEvent event) {
      // Calculate azimuth from magnetometer data
      double azimuth = atan2(event.y, event.x) * 180 / pi;
      setState(() {
        _deviceAzimuth = azimuth;
      });
      _updateARPositions();
    });
  }

  void _updateARPositions() {
    if (_currentLatitude == null || _currentLongitude == null || boundaries.isEmpty) {
      return;
    }

    List<ARElement> newElements = [];
    
    for (Boundary boundary in boundaries) {
      if (boundary.isClaimed) continue;
      
      double distance = boundary.distanceFrom(_currentLatitude!, _currentLongitude!);
      
      // Only show boundaries within 5 meters
      if (distance > 5.0) continue;
      
      // Calculate bearing to boundary
      double bearing = _calculateBearing(_currentLatitude!, _currentLongitude!, 
                                       boundary.latitude, boundary.longitude);
      
      // Calculate relative angle from device heading
      double relativeAngle = bearing - _deviceAzimuth;
      
      // Normalize angle to -180 to 180 degrees
      while (relativeAngle > 180) relativeAngle -= 360;
      while (relativeAngle < -180) relativeAngle += 360;
      
      // Only show if within 90 degrees of device heading (field of view)
      if (relativeAngle.abs() > 90) continue;
      
      // Convert to screen coordinates (improved 3D projection)
      double screenWidth = MediaQuery.of(context).size.width;
      double screenHeight = MediaQuery.of(context).size.height;
      
      // Map angle to screen X position (center is 0 degrees)
      double screenX = screenWidth / 2 + (relativeAngle * screenWidth / 180);
      
      // Map distance to screen Y position (closer = higher on screen)
      double screenY = screenHeight * 0.3 + (distance * 20); // Closer objects appear higher
      
      // Add some randomness for natural positioning
      screenX += (Random().nextDouble() - 0.5) * 20;
      screenY += (Random().nextDouble() - 0.5) * 10;
      
      // Clamp to screen bounds
      screenX = screenX.clamp(75.0, screenWidth - 75.0);
      screenY = screenY.clamp(150.0, screenHeight - 250.0);
      
      bool isClaimable = distance <= boundary.radius;
      bool isVisible = distance <= 5.0;
      
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
        print('Event has ${currentEvent!.boundaries.length} boundaries');
        
        boundaries = currentEvent!.boundaries;
        totalBoundaries = boundaries.length;
        
        // Log boundary details for debugging
        for (int i = 0; i < boundaries.length; i++) {
          final boundary = boundaries[i];
          print('Boundary $i: ${boundary.name} at ${boundary.latitude}, ${boundary.longitude} (radius: ${boundary.radius}m, claimed: ${boundary.isClaimed})');
        }
        
        // Set event in AR service
        arService.setEvent(currentEvent!);
        
        // Set up AR service callbacks
        arService.onBoundaryDetected = _onBoundaryDetected;
        arService.onBoundaryClaimed = _onBoundaryClaimed;
        arService.onProximityUpdate = _onProximityUpdate;
        arService.onProgressUpdate = _onProgressUpdate;
        arService.onVisibleBoundariesUpdate = _onVisibleBoundariesUpdate;
        arService.onClaimedBoundariesUpdate = _onClaimedBoundariesUpdate;
        arService.onPositionUpdate = _onPositionUpdate;
        
        // Initialize AR service
        await arService.initializeAR();
        
        setState(() {
          isLoading = false;
          proximityHint = 'Event loaded! Exploring for boundaries...';
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
      claimedBoundaries.add(boundary);
      claimedCount = claimedBoundaries.length;
      detectedBoundary = null;
    });
    
    // Show confetti
    confettiController.play();
    
    // Show success dialog
    _showClaimSuccessDialog(boundary);
  }

  void _onProximityUpdate(String hint) {
    setState(() {
      proximityHint = hint;
    });
  }

  void _onProgressUpdate(int claimed, int total) {
    setState(() {
      claimedCount = claimed;
      totalBoundaries = total;
    });
  }

  void _onVisibleBoundariesUpdate(List<Boundary> visible) {
    setState(() {
      visibleBoundaries = visible;
    });
  }

  void _onClaimedBoundariesUpdate(List<Boundary> claimed) {
    setState(() {
      claimedBoundaries = claimed;
      claimedCount = claimed.length;
    });
  }

  void _onPositionUpdate(Position position) {
    setState(() {
      _currentLatitude = position.latitude;
      _currentLongitude = position.longitude;
    });
    _updateARPositions();
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
            const Text('Boundary Claimed!'),
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
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
                size: 40,
              ),
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
    // Handle different image URL types
    if (imageUrl.startsWith('http')) {
      // Network image
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[300],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
                color: AppTheme.primaryColor,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultNFTImage();
        },
      );
    } else if (imageUrl.startsWith('/')) {
      // File path
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultNFTImage();
        },
      );
    } else {
      // Asset or default
      return _buildDefaultNFTImage();
    }
  }

  Widget _buildDefaultNFTImage() {
    return Container(
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image,
              color: AppTheme.primaryColor,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              'NFT',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 16,
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
          
          // AR Overlay for Positioned NFT Elements
          _buildPositionedAROverlay(),
          
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

  Widget _buildPositionedAROverlay() {
    return Stack(
      children: arElements.map((element) {
        if (!element.isVisible) return const SizedBox.shrink();
        
        return Positioned(
          left: element.screenX - 75, // Center the element
          top: element.screenY - 75,
          child: GestureDetector(
            onTap: () {
              if (element.isClaimable) {
                arService.claimBoundary(element.boundary);
              }
            },
            child: AnimatedBuilder(
              animation: element.isClaimable ? pulseAnimation : bounceAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: element.isClaimable ? pulseAnimation.value : bounceAnimation.value,
                  child: Column(
                    children: [
                      // NFT Image Container
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
                              color: (element.isClaimable ? AppTheme.primaryColor : Colors.orange).withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _buildNFTImage(element.boundary.imageUrl),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Distance and Status Text
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: element.isClaimable ? AppTheme.primaryColor : Colors.orange,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: (element.isClaimable ? AppTheme.primaryColor : Colors.orange).withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              element.isClaimable ? 'CLAIM' : 'GET CLOSER',
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
            // Header
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
                      // Stop AR service and go back
                      arService.dispose();
                      context.go('/wallet/options');
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
            
            // Proximity Hint
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
                  if (arElements.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${arElements.length} NFT${arElements.length > 1 ? 's' : ''} nearby',
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
            
            // Progress Bar
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
                        'Progress',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$claimedCount/$totalBoundaries',
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
                    value: totalBoundaries > 0 ? claimedCount / totalBoundaries : 0,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    borderRadius: BorderRadius.circular(10),
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
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Claimed Boundaries Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showClaimedBoundaries,
                  icon: const Icon(Icons.celebration),
                  label: Text('Claimed ($claimedCount)'),
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
              'Loading Event...',
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

  void _showClaimedBoundaries() {
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
                    'Claimed Boundaries (${claimedBoundaries.length})',
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
              child: claimedBoundaries.isEmpty
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
                      itemCount: claimedBoundaries.length,
                      itemBuilder: (context, index) {
                        final boundary = claimedBoundaries[index];
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
                    _buildInfoRow('Claimed Boundaries', '$claimedCount'),
                    _buildInfoRow('Event Code', currentEvent!.eventCode),
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

  @override
  void dispose() {
    confettiController.dispose();
    pulseController.dispose();
    bounceController.dispose();
    _cameraController?.dispose();
    arService.dispose();
    super.dispose();
  }
}

