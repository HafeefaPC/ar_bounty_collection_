import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:confetti/confetti.dart';
import 'package:lottie/lottie.dart';
import '../../../shared/services/ar_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/boundary.dart';
import '../../../core/theme/app_theme.dart';

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

  // UI State
  bool isLoading = true;
  bool isCameraInitialized = false;
  String proximityHint = "Initializing camera...";
  int claimedCount = 0;
  int totalBoundaries = 0;
  bool showClaimedBoundaries = false;
  Boundary? detectedBoundary;

  // Animations
  late ConfettiController confettiController;
  late AnimationController pulseController;
  late Animation<double> pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupAnimations();
    _loadEventData();
    _initializeCamera();
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
          print('Boundary $i: ${boundary.name} at ${boundary.latitude}, ${boundary.longitude} (radius: ${boundary.radius}m)');
        }
        
        // Set event in AR service
        arService.setEvent(currentEvent!);
        
        // Set up AR service callbacks
        arService.onBoundaryDetected = _onBoundaryDetected;
        arService.onBoundaryClaimed = _onBoundaryClaimed;
        arService.onProximityUpdate = _onProximityUpdate;
        arService.onProgressUpdate = _onProgressUpdate;
        
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
            Lottie.asset(
              'assets/animations/success.json',
              height: 100,
              repeat: false,
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
          
          // AR Overlay
          if (detectedBoundary != null) _buildAROverlay(),
          
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

  Widget _buildAROverlay() {
    return GestureDetector(
      onTap: () {
        if (detectedBoundary != null) {
          arService.claimBoundary(detectedBoundary!);
        }
      },
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: pulseAnimation.value,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: AppTheme.primaryColor,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'TAP TO CLAIM!',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    shape: const CircleBorder(),
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
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => showClaimedBoundaries = !showClaimedBoundaries),
                  icon: Icon(
                    showClaimedBoundaries ? Icons.explore : Icons.list,
                    color: Colors.white,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    shape: const CircleBorder(),
                  ),
                ),
              ],
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
        padding: const EdgeInsets.all(20),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Proximity Hint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: pulseAnimation.value,
                        child: Icon(
                          Icons.location_on,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      proximityHint,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.my_location,
                  label: 'My Location',
                  onTap: _showMyLocation,
                ),
                _buildActionButton(
                  icon: Icons.list,
                  label: 'Claimed (${claimedBoundaries.length})',
                  onTap: _showClaimedBoundaries,
                ),
                _buildActionButton(
                  icon: Icons.info,
                  label: 'Event Info',
                  onTap: _showEventInfo,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/loading.json',
              height: 100,
            ),
            const SizedBox(height: 20),
            Text(
              'Loading AR Experience...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMyLocation() {
    final position = arService.currentPosition;
    if (position != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('My Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Latitude: ${position.latitude.toStringAsFixed(6)}'),
              Text('Longitude: ${position.longitude.toStringAsFixed(6)}'),
              Text('Accuracy: ${position.accuracy.toStringAsFixed(1)}m'),
              const SizedBox(height: 16),
              if (currentEvent != null) ...[
                const Text('Event Location:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Latitude: ${currentEvent!.latitude.toStringAsFixed(6)}'),
                Text('Longitude: ${currentEvent!.longitude.toStringAsFixed(6)}'),
                const SizedBox(height: 8),
                Text('Distance to event center: ${_calculateDistance(
                  position.latitude, 
                  position.longitude, 
                  currentEvent!.latitude, 
                  currentEvent!.longitude
                ).toStringAsFixed(1)}m'),
              ],
              if (boundaries.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Boundary Distances:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...boundaries.take(3).map((boundary) => Text(
                  '${boundary.name}: ${_calculateDistance(
                    position.latitude, 
                    position.longitude, 
                    boundary.latitude, 
                    boundary.longitude
                  ).toStringAsFixed(1)}m (radius: ${boundary.radius}m)'
                )),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location not available. Please check location permissions.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    double lat1Rad = lat1 * (pi / 180);
    double lat2Rad = lat2 * (pi / 180);
    double deltaLat = (lat2 - lat1) * (pi / 180);
    double deltaLon = (lon2 - lon1) * (pi / 180);

    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
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
                color: AppTheme.primaryColor,
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
                            Icons.explore_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No boundaries claimed yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start exploring to find and claim boundaries!',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
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
                              backgroundColor: AppTheme.primaryColor,
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
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.event, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text(currentEvent!.name)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (currentEvent!.description.isNotEmpty) ...[
                Text(
                  currentEvent!.description,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
              ],
              _buildInfoRow('Venue', currentEvent!.venueName),
              _buildInfoRow('Event Code', currentEvent!.eventCode),
              _buildInfoRow('Total Boundaries', '$totalBoundaries'),
              _buildInfoRow('Claimed', '$claimedCount'),
              _buildInfoRow('Event Center', '${currentEvent!.latitude.toStringAsFixed(6)}, ${currentEvent!.longitude.toStringAsFixed(6)}'),
              if (currentEvent!.startDate != null)
                _buildInfoRow('Start Date', currentEvent!.startDate!.toString().substring(0, 16)),
              if (currentEvent!.endDate != null)
                _buildInfoRow('End Date', currentEvent!.endDate!.toString().substring(0, 16)),
              const SizedBox(height: 16),
              if (boundaries.isNotEmpty) ...[
                const Text('Boundaries:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...boundaries.map((boundary) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${boundary.name} (${boundary.radius}m radius)'),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    confettiController.dispose();
    pulseController.dispose();
    arService.dispose();
    _cameraController?.dispose();
    super.dispose();
  }
}
