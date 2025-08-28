import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'dart:math';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/boundary.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/services/wallet_service.dart';
import 'package:vector_math/vector_math.dart' as vector_math;
import 'package:geocoding/geocoding.dart';

class EventCreationScreen extends ConsumerStatefulWidget {
  const EventCreationScreen({super.key});

  @override
  ConsumerState<EventCreationScreen> createState() => _EventCreationScreenState();
}

class _EventCreationScreenState extends ConsumerState<EventCreationScreen> {
  // Step management
  int _currentStep = 0;
  final int _totalSteps = 4; // Updated to 4 steps
  
  // Step 1: Event Details
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _nftSupplyController = TextEditingController(text: '50');
  
  // Date and time controllers
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  
  // NFT Image
  String? _nftImagePath;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Step 2: Area Selection
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  LatLng? _selectedAreaCenter;
  double _selectedAreaRadius = 100.0; // meters
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  
  // Step 3: Boundary Configuration
  double _boundaryRadius = 2.0; // Default 2 meters for boundary radius
  
  // Step 4: Boundary Placement
  final List<LatLng> _boundaryLocations = [];
  int _currentBoundaryIndex = 0;
  
  // Map state
  LatLng _center = const LatLng(37.7749, -122.4194); // Default to San Francisco
  double _zoom = 15.0;
  
  // Loading state
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _nftSupplyController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check location permissions first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission is required to get your current location'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied. Please enable them in settings.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled. Please enable GPS.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_center, _zoom));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickNFTImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _nftImagePath = image.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      _mapController = controller;
    });
  }

  void _onMapTap(LatLng position) {
    if (_currentStep == 1) {
      // Step 2: Area Selection
      setState(() {
        _selectedAreaCenter = position;
        _markers.clear();
        _circles.clear();
        
        _markers.add(
          Marker(
            markerId: const MarkerId('area_center'),
            position: position,
            infoWindow: const InfoWindow(title: 'Event Area Center'),
          ),
        );
        
        _circles.add(
          Circle(
            circleId: const CircleId('event_area'),
            center: position,
            radius: _selectedAreaRadius,
            fillColor: AppTheme.primaryColor.withOpacity(0.3),
            strokeColor: AppTheme.primaryColor,
            strokeWidth: 2,
          ),
        );
      });
    } else if (_currentStep == 3) {
      // Step 4: Boundary Placement
      final nftSupplyCount = int.tryParse(_nftSupplyController.text) ?? 50;
      if (_boundaryLocations.length < nftSupplyCount) {
        setState(() {
          _boundaryLocations.add(position);
          _markers.add(
            Marker(
              markerId: MarkerId('boundary_${_boundaryLocations.length}'),
              position: position,
              infoWindow: InfoWindow(
                title: 'Boundary ${_boundaryLocations.length}',
                snippet: 'NFT Location',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ),
          );
        });
      }
    }
  }

  void _searchLocation() async {
    if (_searchController.text.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      List<Location> locations = await locationFromAddress(_searchController.text);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final newPosition = LatLng(location.latitude, location.longitude);
        
        setState(() {
          _center = newPosition;
          _selectedAreaCenter = newPosition;
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newPosition, 15.0),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0: // Event Details
        final canProceed = _nameController.text.isNotEmpty &&
               _descriptionController.text.isNotEmpty &&
               _venueController.text.isNotEmpty &&
               _nftSupplyController.text.isNotEmpty &&
               int.tryParse(_nftSupplyController.text) != null &&
               _nftImagePath != null;
        
        // Debug logging
        if (!canProceed) {
          print('Step 0 validation failed:');
          print('Name: ${_nameController.text.isNotEmpty}');
          print('Description: ${_descriptionController.text.isNotEmpty}');
          print('Venue: ${_venueController.text.isNotEmpty}');
          print('NFT Supply: ${_nftSupplyController.text.isNotEmpty}');
          print('NFT Supply Valid: ${int.tryParse(_nftSupplyController.text) != null}');
          print('NFT Image: ${_nftImagePath != null}');
        }
        return canProceed;
        
      case 1: // Area Selection
        final canProceed = _selectedAreaCenter != null;
        if (!canProceed) {
          print('Step 1 validation failed: No area center selected');
        }
        return canProceed;
        
      case 2: // Boundary Configuration
        return true; // Always can proceed from configuration
        
      case 3: // Boundary Placement
        final nftSupplyCount = int.tryParse(_nftSupplyController.text) ?? 50;
        final canProceed = _boundaryLocations.length >= nftSupplyCount;
        if (!canProceed) {
          print('Step 3 validation failed: Need $nftSupplyCount boundaries, have ${_boundaryLocations.length}');
        }
        return canProceed;
        
      default:
        return false;
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildEventDetailsStep();
      case 1:
        return _buildAreaSelectionStep();
      case 2:
        return _buildBoundaryConfigurationStep();
      case 3:
        return _buildBoundaryPlacementStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEventDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event Details',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            
            // Event Title
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Event Title *',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
              ),
              style: const TextStyle(color: Colors.white),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter event title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Event Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Event Description *',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
              ),
              style: const TextStyle(color: Colors.white),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter event description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Start Date and Time
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Start Date',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _startDate != null
                                ? DateFormat('MMM dd, yyyy').format(_startDate!)
                                : 'Select Date',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(context, true),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Start Time',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _startTime != null
                                ? _startTime!.format(context)
                                : 'Select Time',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // End Date and Time
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'End Date',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _endDate != null
                                ? DateFormat('MMM dd, yyyy').format(_endDate!)
                                : 'Select Date',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(context, false),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'End Time',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _endTime != null
                                ? _endTime!.format(context)
                                : 'Select Time',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Venue
            TextFormField(
              controller: _venueController,
              decoration: InputDecoration(
                labelText: 'Venue/Location *',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
              ),
              style: const TextStyle(color: Colors.white),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter venue';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // NFT Supply Count
            TextFormField(
              controller: _nftSupplyController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'NFT Supply Count *',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                suffixText: 'NFTs',
              ),
              style: const TextStyle(color: Colors.white),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter NFT supply count';
                }
                final count = int.tryParse(value);
                if (count == null || count <= 0) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // NFT Image
            InkWell(
              onTap: _pickNFTImage,
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white30, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withOpacity(0.1),
                ),
                child: _nftImagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_nftImagePath!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.add_photo_alternate,
                            color: Colors.white70,
                            size: 40,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add NFT Image (Required)',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaSelectionStep() {
    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search location...',
                    hintStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _searchLocation(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.my_location, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        
        // Map
        Expanded(
          child: GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: _zoom,
            ),
            onTap: _onMapTap,
            markers: _markers,
            circles: _circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
        ),
        
        // Area Radius Slider
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Event Area Radius: ${_selectedAreaRadius.round()}m',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              Slider(
                value: _selectedAreaRadius,
                min: 50.0,
                max: 500.0,
                divisions: 45,
                activeColor: AppTheme.primaryColor,
                onChanged: (value) {
                  setState(() {
                    _selectedAreaRadius = value;
                    if (_selectedAreaCenter != null) {
                      _circles.clear();
                      _circles.add(
                        Circle(
                          circleId: const CircleId('event_area'),
                          center: _selectedAreaCenter!,
                          radius: _selectedAreaRadius,
                          fillColor: AppTheme.primaryColor.withOpacity(0.3),
                          strokeColor: AppTheme.primaryColor,
                          strokeWidth: 2,
                        ),
                      );
                    }
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBoundaryConfigurationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Boundary Configuration',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          
          // Boundary Radius
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white30),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Boundary Claim Radius: ${_boundaryRadius.round()}m',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                Slider(
                  value: _boundaryRadius,
                  min: 1.0,
                  max: 5.0,
                  divisions: 4,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _boundaryRadius = value;
                    });
                  },
                ),
                const Text(
                  'Users must be within this radius to claim the NFT',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white30),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Event Summary',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildSummaryRow('Event Title', _nameController.text),
                _buildSummaryRow('NFT Supply', '${_nftSupplyController.text} NFTs'),
                _buildSummaryRow('Claim Radius', '${_boundaryRadius.round()}m'),
                _buildSummaryRow('Event Area', '${_selectedAreaRadius.round()}m radius'),
                if (_startDate != null && _startTime != null)
                  _buildSummaryRow('Start', '${DateFormat('MMM dd, yyyy').format(_startDate!)} at ${_startTime!.format(context)}'),
                if (_endDate != null && _endTime != null)
                  _buildSummaryRow('End', '${DateFormat('MMM dd, yyyy').format(_endDate!)} at ${_endTime!.format(context)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoundaryPlacementStep() {
    final nftSupplyCount = int.tryParse(_nftSupplyController.text) ?? 50;
    
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Place $nftSupplyCount Boundary Locations',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap on the map to place boundary locations. Each location will have one NFT.',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _boundaryLocations.length / nftSupplyCount,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
              const SizedBox(height: 8),
              Text(
                '${_boundaryLocations.length}/$nftSupplyCount boundaries placed',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
        
        // Map
        Expanded(
          child: GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: _zoom,
            ),
            onTap: _onMapTap,
            markers: _markers,
            circles: _circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
        ),
        
        // Instructions
        Container(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap on the map to place boundary locations. Each green marker represents one NFT location.',
                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Future<void> _createEvent() async {
    print('Creating event...');
    print('Current step: $_currentStep');
    print('Can proceed: ${_canProceedToNextStep()}');
    
    // Only validate form if we're on step 0 (event details)
    if (_currentStep == 0 && _formKey.currentState != null) {
      if (!_formKey.currentState!.validate()) {
        print('Form validation failed');
        return;
      }
    }
    
    final nftSupplyCount = int.tryParse(_nftSupplyController.text) ?? 50;
    print('NFT Supply Count: $nftSupplyCount');
    print('Boundary Locations: ${_boundaryLocations.length}');
    print('Event Name: ${_nameController.text}');
    print('Event Description: ${_descriptionController.text}');
    print('Venue: ${_venueController.text}');
    print('NFT Image: $_nftImagePath');
    
    // Check if all required data is available
    if (_nameController.text.isEmpty || 
        _descriptionController.text.isEmpty || 
        _venueController.text.isEmpty || 
        _nftImagePath == null) {
      print('Missing required data');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all required fields in step 1'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (_boundaryLocations.length < nftSupplyCount) {
      print('Not enough boundary locations placed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please place all $nftSupplyCount boundary locations'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final walletService = WalletService();
      final walletAddress = walletService.connectedWalletAddress ?? 'demo_wallet';
      
      // Create boundaries from placed locations
      final boundaries = _boundaryLocations.asMap().entries.map((entry) {
        final index = entry.key;
        final location = entry.value;
        
        return Boundary(
          name: 'Boundary ${index + 1}',
          description: 'NFT Boundary ${index + 1}',
          imageUrl: _nftImagePath ?? 'default_nft_image',
          latitude: location.latitude,
          longitude: location.longitude,
          radius: _boundaryRadius,
          eventId: '', // Will be set when event is created
        );
      }).toList();
      
      // Create event
      final event = Event(
        name: _nameController.text,
        description: _descriptionController.text,
        organizerWalletAddress: walletAddress,
        latitude: _selectedAreaCenter?.latitude ?? _center.latitude,
        longitude: _selectedAreaCenter?.longitude ?? _center.longitude,
        venueName: _venueController.text,
        boundaries: boundaries,
        startDate: _startDate != null && _startTime != null
            ? DateTime(
                _startDate!.year,
                _startDate!.month,
                _startDate!.day,
                _startTime!.hour,
                _startTime!.minute,
              )
            : null,
        endDate: _endDate != null && _endTime != null
            ? DateTime(
                _endDate!.year,
                _endDate!.month,
                _endDate!.day,
                _endTime!.hour,
                _endTime!.minute,
              )
            : null,
        nftSupplyCount: nftSupplyCount,
        eventImageUrl: _nftImagePath,
      );
      
      // Save to Supabase
      final supabaseService = SupabaseService();
      final createdEvent = await supabaseService.createEvent(event);
      
      if (mounted) {
        _showEventCreatedDialog(createdEvent);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating event: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showEventCreatedDialog(Event event) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        title: Row(
          children: [
            Icon(Icons.celebration, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text(
              'Event Created Successfully!',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Event Code:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      event.eventCode,
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Copy to clipboard
                      Clipboard.setData(ClipboardData(text: event.eventCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Event code copied to clipboard!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, color: AppTheme.primaryColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Share this code with participants to join your event and start claiming NFTs!',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Participants can use this code to join the event and see NFT boundaries in AR.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/events');
            },
            child: const Text('Go to Events'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to event join screen with the code
              context.go('/event-join?code=${event.eventCode}');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Join Event Now'),
          ),
        ],
      ),
    );
  }

  String _getValidationMessage() {
    switch (_currentStep) {
      case 0: // Event Details
        if (_nameController.text.isEmpty) return 'Enter event title';
        if (_descriptionController.text.isEmpty) return 'Enter description';
        if (_venueController.text.isEmpty) return 'Enter venue';
        if (_nftSupplyController.text.isEmpty) return 'Enter NFT count';
        if (int.tryParse(_nftSupplyController.text) == null) return 'Valid NFT count';
        if (_nftImagePath == null) return 'Add NFT image';
        return 'Complete all fields';
        
      case 1: // Area Selection
        return 'Select event area';
        
      case 2: // Boundary Configuration
        return 'Configure boundaries';
        
      case 3: // Boundary Placement
        final nftSupplyCount = int.tryParse(_nftSupplyController.text) ?? 50;
        return 'Place ${nftSupplyCount - _boundaryLocations.length} more boundaries';
        
      default:
        return 'Complete current step';
    }
  }

  Future<void> _testDatabaseConnection() async {
    try {
      final supabaseService = SupabaseService();
      
      // Test basic connection using the testConnection method
      final isConnected = await supabaseService.testConnection();
      
      if (isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database connection successful!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database connection failed!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Database connection error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  Future<void> _testCreateMinimalEvent() async {
    try {
      final supabaseService = SupabaseService();
      
      // Create a minimal test event
      final testEvent = Event(
        name: 'Test Event',
        description: 'Test Description',
        organizerWalletAddress: 'test_wallet',
        latitude: 37.7749,
        longitude: -122.4194,
        venueName: 'Test Venue',
        boundaries: [],
        nftSupplyCount: 1,
      );
      
      final createdEvent = await supabaseService.createEvent(testEvent);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test event created successfully! Code: ${createdEvent.eventCode}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test event creation failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Create Event (Step ${_currentStep + 1}/$_totalSteps)',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/wallet/options'),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: List.generate(_totalSteps, (index) {
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
                    decoration: BoxDecoration(
                      color: index <= _currentStep 
                          ? AppTheme.primaryColor 
                          : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          
          // Step content
          Expanded(child: _buildStepContent()),
          
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Debug info (only show in development)
                if (true) // Change to false in production
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Step: $_currentStep | Can Proceed: ${_canProceedToNextStep()} | Boundaries: ${_boundaryLocations.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (_currentStep == _totalSteps - 1)
                        Column(
                          children: [
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ElevatedButton(
                                onPressed: () {
                                  print('Test button pressed!');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Test button works!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text(
                                  'Test Button (Should Show Snackbar)',
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ElevatedButton(
                                onPressed: _testCreateMinimalEvent,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text(
                                  'Test Database Connection',
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousStep,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.white30),
                          ),
                          child: const Text(
                            'Previous',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 16),
                                          Expanded(
                      child: ElevatedButton(
                        onPressed: _canProceedToNextStep() 
                            ? (_currentStep == _totalSteps - 1 ? () {
                                print('Create Event button pressed!');
                                print('Current step: $_currentStep');
                                print('Can proceed: ${_canProceedToNextStep()}');
                                _createEvent();
                              } : _nextStep)
                            : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _canProceedToNextStep() 
                                ? AppTheme.primaryColor 
                                : Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _currentStep == _totalSteps - 1 ? 'Create Event' : 'Next',
                                      style: const TextStyle(color: Colors.white, fontSize: 16),
                                    ),
                                    if (!_canProceedToNextStep()) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _getValidationMessage(),
                                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

