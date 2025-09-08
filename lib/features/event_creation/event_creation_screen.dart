import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/event.dart' as models;
import '../../../shared/models/boundary.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/wallet_connection_wrapper.dart';
import '../../../shared/services/global_wallet_service.dart';
import '../../../shared/providers/web3_provider.dart';
import '../../../shared/providers/reown_provider.dart';
import '../../../shared/services/test_web3_integration.dart';
import 'package:reown_appkit/reown_appkit.dart';

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
  
  // Step 3: Boundary Configuration
  double _boundaryRadius = 2.0; // Default 2 meters for boundary radius
  
  // Step 4: Boundary Placement
  final List<LatLng> _boundaryLocations = [];
  
  // Map state
  LatLng _center = const LatLng(37.7749, -122.4194); // Default to San Francisco
  final double _zoom = 15.0;
  
  // Loading state
  bool _isLoading = false;
  
  // Role checking removed - anyone can create events now!

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

  Future<void> _addNFTAtCurrentLocation() async {
    try {
      // Check location permissions first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showLocationPermissionDialog(
              'Location Permission Required',
              'This app needs location access to add NFT locations. Please grant location permission.',
              'Grant Permission',
              () => _addNFTAtCurrentLocation(),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showLocationPermissionDialog(
            'Location Permission Denied',
            'Location permissions are permanently denied. Please enable them in your device settings to use this feature.',
            'Open Settings',
            () => _openAppSettings(),
          );
        }
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showLocationPermissionDialog(
            'Location Services Disabled',
            'GPS/Location services are disabled on your device. Please enable them to use this feature.',
            'Enable GPS',
            () => _openLocationSettings(),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      final currentLocation = LatLng(position.latitude, position.longitude);
      final nftSupplyCount = int.tryParse(_nftSupplyController.text) ?? 50;
      
      if (_boundaryLocations.length < nftSupplyCount) {
        setState(() {
          _boundaryLocations.add(currentLocation);
          _markers.add(
            Marker(
              markerId: MarkerId('boundary_${_boundaryLocations.length}'),
              position: currentLocation,
              infoWindow: InfoWindow(
                title: 'Boundary ${_boundaryLocations.length}',
                snippet: 'NFT Location (Current Location)',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ),
          );
        });
        
        // Center map on the new location
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(currentLocation, 18.0),
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.backgroundColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'NFT location added at current position!',
                      style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.backgroundColor),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.backgroundColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All NFT locations have been placed!',
                      style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.backgroundColor),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showRetroError('Error getting current location: $e');
      }
    }
  }

  void _clearAllBoundaries() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        title: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning,
                color: AppTheme.errorColor,
                size: 12,
              ),
              const SizedBox(width: 8),
              Text(
                'CLEAR ALL BOUNDARIES',
                style: AppTheme.modernSubtitle.copyWith(
                  color: AppTheme.errorColor,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        content: Text(
          'Are you sure you want to remove all ${_boundaryLocations.length} placed NFT locations? This action cannot be undone.',
          style: AppTheme.modernBodySecondary.copyWith(
            color: AppTheme.textColor,
            fontSize: 12,
          ),
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'CANCEL',
                style: AppTheme.modernButton.copyWith(
                  color: AppTheme.textColor.withOpacity(0.8),
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _boundaryLocations.clear();
                  _markers.removeWhere((marker) => 
                    marker.markerId.value.startsWith('boundary_')
                  );
                });

                Navigator.of(context).pop();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'All boundaries cleared! You can now place new locations.',
                            style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.backgroundColor),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppTheme.successColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
              ),
              child: Text(
                'CLEAR ALL',
                style: AppTheme.modernButton.copyWith(
                  color: AppTheme.errorColor,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check location permissions first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showLocationPermissionDialog(
              'Location Permission Required',
              'This app needs location access to help you create events at specific locations. Please grant location permission.',
              'Grant Permission',
              () => _getCurrentLocation(),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showLocationPermissionDialog(
            'Location Permission Denied',
            'Location permissions are permanently denied. Please enable them in your device settings to use this feature.',
            'Open Settings',
            () => _openAppSettings(),
          );
        }
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showLocationPermissionDialog(
            'Location Services Disabled',
            'GPS/Location services are disabled on your device. Please enable them to use this feature.',
            'Enable GPS',
            () => _openLocationSettings(),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_center, _zoom));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location updated: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'),
            backgroundColor: AppTheme.successColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Pixelated
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showLocationPermissionDialog(
          'Location Error',
          'Failed to get your current location. Please check your GPS settings and try again.',
          'Retry',
          () => _getCurrentLocation(),
        );
      }
    }
  }

  void _showLocationPermissionDialog(String title, String message, String actionText, VoidCallback onAction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(
          title,
          style: AppTheme.modernSubtitle.copyWith(color: AppTheme.primaryColor),
        ),
        content: Text(
          message,
          style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTheme.modernButton.copyWith(color: AppTheme.secondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onAction();
            },
            style: AppTheme.modernPrimaryButton,
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  Future<void> _openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
    }
  }

  Future<void> _openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('Error opening location settings: $e');
    }
  }

  Future<void> _pickNFTImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512, // Reduced for better AR performance
        maxHeight: 512, // Reduced for better AR performance
        imageQuality: 90, // Increased quality for better AR display
      );

      if (image != null) {
        setState(() {
          _nftImagePath = image.path;
        });
        
        // Show image size info
        if (mounted) {
          final file = File(image.path);
          final sizeInBytes = await file.length();
          final sizeInKB = (sizeInBytes / 1024).round();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.backgroundColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'NFT image selected! Size: ${sizeInKB}KB (Optimized for AR)',
                      style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.backgroundColor),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
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
            fillColor: AppTheme.primaryColor.withValues(alpha: 0.3),
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
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40), // Add bottom padding
        child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'EVENT DETAILS',
                style: AppTheme.modernTitle.copyWith(
                  fontSize: 24,
                  color: AppTheme.primaryColor,
                  letterSpacing: 2.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            
            // Retro Event Title
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'EVENT TITLE *',
                hintText: 'Enter your event title',
                filled: true,
                fillColor: AppTheme.cardColor,
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
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.textColor),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter event title';
                }
                if (value.length < 3) {
                  return 'Title must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Retro Event Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'EVENT DESCRIPTION *',
                hintText: 'Describe your event',
                filled: true,
                fillColor: AppTheme.cardColor,
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
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.textColor),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter event description';
                }
                if (value.length < 10) {
                  return 'Description must be at least 10 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Retro Start Date and Time
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'START DATE',
                            style: AppTheme.modernButton.copyWith(
                              color: AppTheme.secondaryColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _startDate != null
                                ? DateFormat('MMM dd, yyyy').format(_startDate!)
                                : 'SELECT DATE',
                            style: AppTheme.modernBodySecondary.copyWith(
                              color: AppTheme.textColor,
                              fontSize: 16,
                            ),
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
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'START TIME',
                            style: AppTheme.modernButton.copyWith(
                              color: AppTheme.accentColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _startTime != null
                                ? _startTime!.format(context)
                                : 'SELECT TIME',
                            style: AppTheme.modernBodySecondary.copyWith(
                              color: AppTheme.textColor,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Retro End Date and Time
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'END DATE',
                            style: AppTheme.modernButton.copyWith(
                              color: AppTheme.secondaryColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _endDate != null
                                ? DateFormat('MMM dd, yyyy').format(_endDate!)
                                : 'SELECT DATE',
                            style: AppTheme.modernBodySecondary.copyWith(
                              color: AppTheme.textColor,
                              fontSize: 16,
                            ),
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
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'END TIME',
                            style: AppTheme.modernButton.copyWith(
                              color: AppTheme.accentColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _endTime != null
                                ? _endTime!.format(context)
                                : 'SELECT TIME',
                            style: AppTheme.modernBodySecondary.copyWith(
                              color: AppTheme.textColor,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Retro Venue
            TextFormField(
              controller: _venueController,
              decoration: InputDecoration(
                labelText: 'VENUE/LOCATION *',
                hintText: 'Enter event venue',
                filled: true,
                fillColor: AppTheme.cardColor,
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
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.textColor),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter venue';
                }
                if (value.length < 3) {
                  return 'Venue must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Retro NFT Supply Count
            TextFormField(
              controller: _nftSupplyController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'NFT SUPPLY COUNT *',
                hintText: 'Enter number of NFTs',
                filled: true,
                fillColor: AppTheme.cardColor,
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
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ).copyWith(
                suffixText: 'NFTs',
                suffixStyle: TextStyle(color: AppTheme.primaryColor),
              ),
              style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.textColor),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter NFT supply count';
                }
                final count = int.tryParse(value);
                if (count == null || count <= 0) {
                  return 'Please enter a valid number';
                }
                if (count > 1000) {
                  return 'NFT count cannot exceed 1000';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Retro NFT Image
            InkWell(
              onTap: _pickNFTImage,
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
                child: _nftImagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(0), // Pixelated
                        child: Image.file(
                          File(_nftImagePath!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            color: AppTheme.primaryColor,
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ADD NFT IMAGE (REQUIRED)',
                            style: AppTheme.modernButton.copyWith(
                              color: AppTheme.primaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            
            // Image Requirements Info
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.accentColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AR-OPTIMIZED IMAGE REQUIREMENTS',
                        style: AppTheme.modernButton.copyWith(
                          color: AppTheme.accentColor,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Size: 512x512 pixels (optimal for AR display)\n• Format: JPG/PNG\n• Quality: High (90%)\n• Max file size: ~200KB for best performance',
                    style: AppTheme.modernBodySecondary.copyWith(
                      color: AppTheme.textColor.withOpacity(0.8),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildAreaSelectionStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40), // Add bottom padding
        child: Column(
        children: [
          // Retro Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
            child: Column(
              children: [
                Icon(
                  Icons.map,
                  color: AppTheme.primaryColor,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'SELECT EVENT AREA',
                  style: AppTheme.modernTitle.copyWith(
                    fontSize: 20,
                    color: AppTheme.primaryColor,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap on the map to set the center of your event area',
                  style: AppTheme.modernBodySecondary.copyWith(
                    color: AppTheme.textColor.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Retro Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'SEARCH LOCATION',
                      hintText: 'Enter location name...',
                      filled: true,
                      fillColor: AppTheme.cardColor,
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
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ).copyWith(
                      prefixIcon: Icon(Icons.search, color: AppTheme.secondaryColor),
                    ),
                    style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.textColor),
                    onSubmitted: (_) => _searchLocation(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
                  child: IconButton(
                    onPressed: _getCurrentLocation,
                    icon: Icon(Icons.my_location, color: AppTheme.primaryColor),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.backgroundColor,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Map with retro styling
          Container(
            height: 300, // Fixed height to prevent overflow
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
            child: ClipRect(
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
          ),
          
          // Retro Area Radius Slider
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.radio_button_checked,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'EVENT AREA RADIUS',
                      style: AppTheme.modernSubtitle.copyWith(
                        color: AppTheme.primaryColor,
                        fontSize: 18,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
                  child: Text(
                    '${_selectedAreaRadius.round()} METERS',
                    style: AppTheme.modernTitle.copyWith(
                      fontSize: 24,
                      color: AppTheme.secondaryColor,
                      letterSpacing: 2.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _selectedAreaRadius,
                  min: 50.0,
                  max: 500.0,
                  divisions: 45,
                  activeColor: AppTheme.primaryColor,
                  inactiveColor: AppTheme.surfaceColor.withOpacity(0.5),
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
                            fillColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                            strokeColor: AppTheme.primaryColor,
                            strokeWidth: 2,
                          ),
                        );
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Drag to adjust the radius of your event area',
                  style: AppTheme.modernBodySecondary.copyWith(
                    color: AppTheme.textColor.withOpacity(0.7),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildBoundaryConfigurationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40), // Add bottom padding
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Retro Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
            child: Column(
              children: [
                Icon(
                  Icons.settings,
                  color: AppTheme.secondaryColor,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'BOUNDARY CONFIGURATION',
                  style: AppTheme.modernTitle.copyWith(
                    fontSize: 20,
                    color: AppTheme.secondaryColor,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure how users will claim your NFTs',
                  style: AppTheme.modernBodySecondary.copyWith(
                    color: AppTheme.textColor.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Boundary Radius Configuration
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.radio_button_checked,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CLAIM RADIUS',
                      style: AppTheme.modernSubtitle.copyWith(
                        color: AppTheme.primaryColor,
                        fontSize: 18,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
                  child: Text(
                    '${_boundaryRadius.round()} METERS',
                    style: AppTheme.modernTitle.copyWith(
                      fontSize: 28,
                      color: AppTheme.accentColor,
                      letterSpacing: 2.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _boundaryRadius,
                  min: 1.0,
                  max: 5.0,
                  divisions: 4,
                  activeColor: AppTheme.primaryColor,
                  inactiveColor: AppTheme.surfaceColor.withOpacity(0.5),
                  onChanged: (value) {
                    setState(() {
                      _boundaryRadius = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
                  child: Text(
                    'Users must be within this radius to claim the NFT',
                    style: AppTheme.modernBodySecondary.copyWith(
                      color: AppTheme.textColor.withOpacity(0.9),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          
          // Event Summary Preview
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.summarize,
                      color: AppTheme.accentColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'EVENT SUMMARY',
                      style: AppTheme.modernSubtitle.copyWith(
                        color: AppTheme.accentColor,
                        fontSize: 18,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRetroSummaryRow('Event Title', _nameController.text),
                _buildRetroSummaryRow('NFT Supply', '${_nftSupplyController.text} NFTs'),
                _buildRetroSummaryRow('Claim Radius', '${_boundaryRadius.round()}m'),
                _buildRetroSummaryRow('Event Area', '${_selectedAreaRadius.round()}m radius'),
                if (_startDate != null && _startTime != null)
                  _buildRetroSummaryRow('Start', '${DateFormat('MMM dd, yyyy').format(_startDate!)} at ${_startTime!.format(context)}'),
                if (_endDate != null && _endTime != null)
                  _buildRetroSummaryRow('End', '${DateFormat('MMM dd, yyyy').format(_endDate!)} at ${_endTime!.format(context)}'),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildBoundaryPlacementStep() {
    final nftSupplyCount = int.tryParse(_nftSupplyController.text) ?? 50;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40), // Add bottom padding
        child: Column(
        children: [
          // Retro Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
            child: Column(
              children: [
                Icon(
                  Icons.location_on,
                  color: AppTheme.accentColor,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'PLACE BOUNDARY LOCATIONS',
                  style: AppTheme.modernTitle.copyWith(
                    fontSize: 20,
                    color: AppTheme.accentColor,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap on the map or use current location to place $nftSupplyCount NFT locations',
                  style: AppTheme.modernBodySecondary.copyWith(
                    color: AppTheme.textColor.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Progress Section
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.track_changes,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PLACEMENT PROGRESS',
                      style: AppTheme.modernSubtitle.copyWith(
                        color: AppTheme.primaryColor,
                        fontSize: 16,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
                  child: Text(
                    '${_boundaryLocations.length} / $nftSupplyCount',
                    style: AppTheme.modernTitle.copyWith(
                      fontSize: 32,
                      color: AppTheme.secondaryColor,
                      letterSpacing: 2.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
                  child: ClipRect(
                    child: LinearProgressIndicator(
                      value: _boundaryLocations.length / nftSupplyCount,
                      backgroundColor: AppTheme.surfaceColor.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'BOUNDARIES PLACED',
                  style: AppTheme.modernButton.copyWith(
                    color: AppTheme.textColor.withOpacity(0.7),
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          
          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_location,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PLACEMENT TOOLS',
                      style: AppTheme.modernSubtitle.copyWith(
                        color: AppTheme.primaryColor,
                        fontSize: 16,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
                        child: ElevatedButton.icon(
                          onPressed: _addNFTAtCurrentLocation,
                          icon: Icon(Icons.my_location, color: AppTheme.backgroundColor),
                          label: Text(
                            'ADD AT CURRENT LOCATION',
                            textAlign: TextAlign.start,
                            style: AppTheme.modernButton.copyWith(
                              color: AppTheme.primaryColor,

                              fontSize: 12,
                              letterSpacing: 1.0,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
                      child: IconButton(
                        onPressed: _getCurrentLocation,
                        icon: Icon(Icons.refresh, color: AppTheme.accentColor),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.backgroundColor,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_boundaryLocations.isNotEmpty)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
                    child: ElevatedButton.icon(
                      onPressed: _clearAllBoundaries,
                      icon: Icon(Icons.clear_all, color: AppTheme.primaryColor),
                      label: Text(
                        'CLEAR ALL BOUNDARIES',
                        style: AppTheme.modernButton.copyWith(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Use current location or tap on map to place boundaries',
                  style: AppTheme.modernBodySecondary.copyWith(
                    color: AppTheme.textColor.withOpacity(0.7),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Map
          Container(
            height: 300, // Fixed height to prevent overflow
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
            child: ClipRect(
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
                myLocationButtonEnabled: true, // Enable my location button for better UX
                zoomControlsEnabled: true, // Enable zoom controls
                mapToolbarEnabled: true, // Enable map toolbar for better interaction
                zoomGesturesEnabled: true, // Enable pinch to zoom
                scrollGesturesEnabled: true, // Enable scroll gestures
                rotateGesturesEnabled: true, // Enable rotate gestures
                tiltGesturesEnabled: true, // Enable tilt gestures
              ),
            ),
          ),
          
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
                  child: Icon(
                    Icons.info_outline,
                    color: AppTheme.accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PLACEMENT INSTRUCTIONS',
                        style: AppTheme.modernButton.copyWith(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap on the map or use the "ADD AT CURRENT LOCATION" button to place boundary locations. Each green marker represents one NFT location.',
                        style: AppTheme.modernBodySecondary.copyWith(
                          color: AppTheme.textColor.withOpacity(0.9),
                          fontSize: 12,
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


  Widget _buildRetroSummaryRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTheme.modernButton.copyWith(
              color: AppTheme.textColor.withOpacity(0.8),
              fontSize: 12,
              letterSpacing: 1.0,
            ),
          ),
          Text(
            value,
            style: AppTheme.modernBodySecondary.copyWith(
              color: AppTheme.textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Test method to verify wallet transaction dialog
  Future<void> _testWalletTransaction() async {
    print('🧪 Testing wallet transaction dialog...');
    
    final walletState = ref.read(walletConnectionProvider);
    if (!walletState.isConnected || walletState.walletAddress == null) {
      _showRetroError('Please connect your wallet first');
      return;
    }
    
    final reownAppKit = ref.read(reownAppKitProvider);
    if (reownAppKit == null) {
      _showRetroError('Wallet not connected');
      return;
    }

    try {
      print('🔍 Wallet state check:');
      print('  - Connected: ${walletState.isConnected}');
      print('  - Address: ${walletState.walletAddress}');
      print('  - Chain ID: ${walletState.chainId}');
      print('  - Session Topic: ${walletState.sessionTopic}');
      
      // Use a simple ETH transfer instead of contract interaction to avoid revert
      // Send 0 ETH to the user's own address - this should always succeed
      final transactionParams = {
        'to': walletState.walletAddress!.toLowerCase(), // Send to self
        'data': '0x', // Empty data - simple transfer
        'from': walletState.walletAddress!.toLowerCase(),
        'gas': '0x${(21000).toRadixString(16)}', // Standard gas limit for ETH transfer
        'gasPrice': '0x${(1000000000).toRadixString(16)}', // 1 gwei
        'value': '0x0', // No ETH being sent - just test the flow
      };
      
      print('🧪 Test transaction parameters:');
      print('  - To: ${transactionParams['to']}');
      print('  - From: ${transactionParams['from']}');
      print('  - Gas: ${transactionParams['gas']}');
      print('  - Gas Price: ${transactionParams['gasPrice']}');
      print('  - Value: ${transactionParams['value']}');
      print('  - Data: ${transactionParams['data']}');
      
      print('🔗 Sending request to wallet...');
      final result = await reownAppKit.request(
        topic: walletState.sessionTopic!,
        chainId: 'eip155:421614',
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [transactionParams],
        ),
      ).timeout(
        const Duration(seconds: 120), // 2 minute timeout for user interaction
        onTimeout: () {
          print('⏰ Test transaction timed out - user may not have approved');
          throw Exception('Transaction request timed out. Please check your wallet and try again.');
        },
      );
      
      print('📨 Raw result received from wallet:');
      print('  - Type: ${result.runtimeType}');
      print('  - Value: $result');
      
      // Enhanced result parsing
      String? transactionHash;
      
      if (result is String) {
        print('📝 Result is String: $result');
        if (result.startsWith('0x') && result.length == 66) {
          transactionHash = result;
          print('✅ Found valid transaction hash: $transactionHash');
        } else {
          print('⚠️ String result is not a valid transaction hash');
        }
      } else if (result is Map) {
        print('📝 Result is Map with keys: ${result.keys.toList()}');
        
        // Check if this is an error response first
        if (result.containsKey('code') && result.containsKey('message')) {
          final errorCode = result['code'];
          final errorMessage = result['message'];
          print('📝 Error response detected - Code: $errorCode, Message: $errorMessage');
          
          if (errorCode == 5000 || errorMessage.toString().toLowerCase().contains('user rejected')) {
            print('📝 User rejection detected in JSON response');
            throw Exception('User rejected the transaction in wallet');
          } else {
            print('📝 Other error in JSON response');
            throw Exception('Wallet error: $errorMessage (Code: $errorCode)');
          }
        }
        
        // Try multiple possible keys for the transaction hash
        final possibleKeys = ['hash', 'transactionHash', 'txHash', 'tx_hash'];
        for (final key in possibleKeys) {
          if (result.containsKey(key)) {
            final hash = result[key];
            print('📝 Found key "$key" with value: $hash (${hash.runtimeType})');
            if (hash is String && hash.startsWith('0x') && hash.length == 66) {
              transactionHash = hash;
              print('✅ Found valid transaction hash from key "$key": $transactionHash');
              break;
            }
          }
        }
      } else if (result is List && result.isNotEmpty) {
        print('📝 Result is List with ${result.length} items');
        final firstItem = result.first;
        print('📝 First item: $firstItem (${firstItem.runtimeType})');
        if (firstItem is String && firstItem.startsWith('0x') && firstItem.length == 66) {
          transactionHash = firstItem;
          print('✅ Found valid transaction hash from list: $transactionHash');
        }
      } else {
        print('📝 Result is of unexpected type: ${result.runtimeType}');
      }
      
      if (transactionHash != null) {
        print('🎉 Test transaction SUCCESS!');
        print('📝 Transaction Hash: $transactionHash');
        _showRetroSuccess('Test Wallet Connection Successful!\n\nTransaction Hash: ${transactionHash.substring(0, 10)}...${transactionHash.substring(transactionHash.length - 8)}\n\nYour wallet is properly connected and ready for transactions.');
      } else {
        print('⚠️ Transaction may have succeeded but received unexpected result format');
        _showRetroError('Test Transaction Completed but Unexpected Result\n\nCode: 5000\nMessage: Unexpected response format\n\nReceived: $result\n\nYour wallet connection may still be working, but please check the transaction in your wallet.');
      }
      
    } catch (e) {
      print('❌ Test transaction FAILED with error: $e');
      
      // Enhanced error parsing
      String errorMessage = e.toString().toLowerCase();
      String userFriendlyMessage;
      
      if (errorMessage.contains('user rejected') || errorMessage.contains('user denied')) {
        userFriendlyMessage = 'Test Transaction Cancelled\n\nYou cancelled the transaction in your wallet. This is normal if you chose not to proceed.';
      } else if (errorMessage.contains('insufficient funds')) {
        userFriendlyMessage = 'Test Transaction Failed\n\nInsufficient ETH for gas fees. You need a small amount of ETH on Arbitrum Sepolia to pay for transaction fees.';
      } else if (errorMessage.contains('timeout')) {
        userFriendlyMessage = 'Test Transaction Timed Out\n\nThe transaction request timed out. Please check your wallet and try again.';
      } else if (errorMessage.contains('wrong network') || errorMessage.contains('chain')) {
        userFriendlyMessage = 'Test Transaction Failed\n\nPlease ensure you are on the Arbitrum Sepolia network in your wallet.';
      } else {
        userFriendlyMessage = 'Test Transaction Failed\n\nError: $e\n\nPlease check your wallet connection and try again.';
      }
      
      _showRetroError(userFriendlyMessage);
    }
  }

  Future<void> _createEvent() async {
    print('🚀 Creating event with smart contract integration...');
    print('Current step: $_currentStep');
    print('Can proceed: ${_canProceedToNextStep()}');
    
    // Only validate form if we're on step 0 (event details)
    if (_currentStep == 0 && _formKey.currentState != null) {
      if (!_formKey.currentState!.validate()) {
        print('Form validation failed');
        _showRetroError('Please complete all required fields correctly');
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
      _showRetroError('Please complete all required fields in step 1');
      return;
    }
    
    if (_boundaryLocations.length < nftSupplyCount) {
      print('Not enough boundary locations placed');
      _showRetroError('Please place all $nftSupplyCount boundary locations');
      return;
    }
    
    // Get wallet connection state
    final walletState = ref.read(walletConnectionProvider);
    final reownAppKit = ref.read(reownAppKitProvider);
    
    print('🔍 Wallet State Check:');
    print('Connected: ${walletState.isConnected}');
    print('Address: ${walletState.walletAddress}');
    print('Chain ID: ${walletState.chainId}');
    print('Session Topic: ${walletState.sessionTopic}');
    print('ReownAppKit Available: ${reownAppKit != null}');
    
    if (!walletState.isConnected || walletState.walletAddress == null) {
      _showRetroError('Please connect your wallet to create an event');
      return;
    }
    
    if (reownAppKit == null) {
      _showRetroError('Wallet service not ready. Please reconnect your wallet.');
      return;
    }
    
    // Critical: Check if we're on the correct chain
    // First, refresh the wallet state to get the latest chain ID
    final walletNotifier = ref.read(walletConnectionProvider.notifier);
    walletNotifier.refreshConnectionState();
    
    // Wait a moment for the state to update
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Get the updated wallet state
    final updatedWalletState = ref.read(walletConnectionProvider);
    print('🔍 Updated Wallet State Check:');
    print('Connected: ${updatedWalletState.isConnected}');
    print('Address: ${updatedWalletState.walletAddress}');
    print('Chain ID: ${updatedWalletState.chainId}');
    print('Session Topic: ${updatedWalletState.sessionTopic}');
    
    // Extract chain ID without eip155: prefix for comparison
    final currentChainId = updatedWalletState.chainId?.replaceAll('eip155:', '') ?? '';
    if (currentChainId != '421614') {
      print('⚠️ Wrong chain detected. Current: ${updatedWalletState.chainId} (parsed: $currentChainId), Expected: 421614');
      
      // Try to automatically switch
      print('🔄 Attempting to switch to Arbitrum Sepolia...');
      final switched = await walletNotifier.switchToArbitrumSepolia();
      
      if (!switched) {
        print('❌ Automatic switch failed, showing manual instructions');
        _showRetroError('Please manually switch to Arbitrum Sepolia network in your wallet settings.');
        return;
      }
      
      // Wait for chain switch to complete and refresh state again
      print('⏳ Waiting for chain switch to complete...');
      await Future.delayed(const Duration(seconds: 3));
      
      // Refresh state one more time
      walletNotifier.refreshConnectionState();
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Final check
      final finalWalletState = ref.read(walletConnectionProvider);
      print('🔍 Final Wallet State Check:');
      print('Chain ID: ${finalWalletState.chainId}');
      
      final finalChainId = finalWalletState.chainId?.replaceAll('eip155:', '') ?? '';
      if (finalChainId != '421614') {
        print('❌ Chain switch still failed after automatic attempt');
        _showRetroError('Chain switch failed. Please manually switch to Arbitrum Sepolia in your wallet settings.');
        return;
      }
      
      print('✅ Successfully switched to Arbitrum Sepolia!');
    } else {
      print('✅ Already on Arbitrum Sepolia (Chain ID: ${updatedWalletState.chainId} -> $currentChainId)');
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Get services
      final web3Service = ref.read(web3ServiceProvider);
      final ipfsService = ref.read(ipfsServiceProvider);
      final supabaseService = SupabaseService();
      
      // Step 1: Upload NFT image to IPFS
      String ipfsImageUrl = 'default_nft_image';
      if (_nftImagePath != null) {
        try {
          print('📤 Uploading NFT image to IPFS...');
          ipfsImageUrl = await ipfsService.uploadFile(_nftImagePath!);
          print('✅ Image uploaded to IPFS: $ipfsImageUrl');
        } catch (e) {
          print('❌ Error uploading image to IPFS: $e');
          // Fallback to Supabase if IPFS fails
          print('📤 Falling back to Supabase storage...');
          final fileName = 'nft_${DateTime.now().millisecondsSinceEpoch}.jpg';
          ipfsImageUrl = await supabaseService.uploadImage(_nftImagePath!, fileName);
          print('✅ Image uploaded to Supabase: $ipfsImageUrl');
        }
      }
      
      // Step 2: Create boundaries metadata
      final boundaries = _boundaryLocations.asMap().entries.map((entry) {
        final index = entry.key;
        final location = entry.value;
        
        return {
          'name': 'Boundary ${index + 1}',
          'description': 'NFT Boundary ${index + 1}',
          'latitude': location.latitude,
          'longitude': location.longitude,
          'radius': _boundaryRadius,
          'image': ipfsImageUrl,
        };
      }).toList();
      
      // Step 3: Create event metadata for IPFS
      final eventMetadata = ipfsService.createEventMetadata(
        name: _nameController.text,
        description: _descriptionController.text,
        organizer: updatedWalletState.walletAddress!,
        latitude: _selectedAreaCenter?.latitude ?? _center.latitude,
        longitude: _selectedAreaCenter?.longitude ?? _center.longitude,
        venue: _venueController.text,
        nftSupplyCount: nftSupplyCount,
        imageUrl: ipfsImageUrl,
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
      );
      
      // Step 4: Upload event metadata to IPFS
      String ipfsMetadataUrl;
      try {
        print('📤 Uploading event metadata to IPFS...');
        ipfsMetadataUrl = await ipfsService.uploadMetadata(eventMetadata);
        print('✅ Metadata uploaded to IPFS: $ipfsMetadataUrl');
      } catch (e) {
        print('❌ Error uploading metadata to IPFS: $e');
        // Use a fallback URL or create a local reference
        ipfsMetadataUrl = 'metadata_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      // Step 5: Create event on blockchain
      print('⛓️ Creating event on blockchain...');
      final reownAppKit = ref.read(reownAppKitProvider);
      if (reownAppKit == null) {
        throw Exception('Wallet not connected');
      }
      
      // Generate unique event code with retry mechanism
      String eventCode;
      int attempts = 0;
      const maxAttempts = 3;
      
      do {
        attempts++;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final random = (timestamp % 10000).toString().padLeft(4, '0');
        eventCode = 'EVT_${timestamp}_$random';
        
        print('🎯 Generated Event Code (attempt $attempts): $eventCode');
        print('🎯 Timestamp: $timestamp');
        print('🎯 Random suffix: $random');
        
        // Check if event code already exists
        print('🔍 Checking if event code already exists...');
        final codeExists = await web3Service.eventCodeExists(eventCode);
        if (!codeExists) {
          print('✅ Event code is unique and available');
          break;
        } else {
          print('⚠️ Event code already exists, generating new one...');
          if (attempts >= maxAttempts) {
            throw Exception('Unable to generate unique event code after $maxAttempts attempts. Please try again.');
          }
          // Wait a bit before trying again
          await Future.delayed(Duration(milliseconds: 100));
        }
      } while (attempts < maxAttempts);
      
      // Calculate timestamps - ensure start time is in the future
      final now = DateTime.now();
      final startDateTime = _startDate != null && _startTime != null
          ? DateTime(_startDate!.year, _startDate!.month, _startDate!.day, _startTime!.hour, _startTime!.minute)
          : now.add(Duration(minutes: 5)); // Default to 5 minutes from now
      final endDateTime = _endDate != null && _endTime != null
          ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day, _endTime!.hour, _endTime!.minute)
          : startDateTime.add(Duration(hours: 24)); // Default to 24 hours after start
      
      // Validate timestamps
      if (startDateTime.isBefore(now)) {
        throw Exception('Start time must be in the future. Please select a future date and time.');
      }
      if (endDateTime.isBefore(startDateTime)) {
        throw Exception('End time must be after start time.');
      }
      
      print('🎯 Timestamp Validation:');
      print('  - Current time: $now');
      print('  - Start time: $startDateTime');
      print('  - End time: $endDateTime');
      print('  - Start time is future: ${startDateTime.isAfter(now)}');
      print('  - End time is after start: ${endDateTime.isAfter(startDateTime)}');
          
      // Show progress to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.backgroundColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Creating event on blockchain... Please wait.',
                    style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.backgroundColor),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
      // Step 5: Create event directly - no role restrictions anymore!
      print('🚀 Creating event on blockchain with new contract (no role restrictions)...');
      print('📝 Using EventFactory address: 0x465865E0bFA28d7794fC103b57fd089656872907');
      final txHash = await web3Service.createEvent(
          eventName: _nameController.text,
          eventDescription: _descriptionController.text,
          organizerWallet: updatedWalletState.walletAddress!,
          latitude: ((_selectedAreaCenter?.latitude ?? _center.latitude) * 1000000).round(), // Convert to integer
          longitude: ((_selectedAreaCenter?.longitude ?? _center.longitude) * 1000000).round(), // Convert to integer
          venueName: _venueController.text,
          nftSupplyCount: nftSupplyCount,
          eventImageUrl: ipfsMetadataUrl,
          eventCode: eventCode,
          startTime: (startDateTime.millisecondsSinceEpoch ~/ 1000), // Convert to seconds
          endTime: (endDateTime.millisecondsSinceEpoch ~/ 1000), // Convert to seconds
          radius: 100, // Default 100 meters radius
          signTransaction: (to, data) async {
            print('🔐 Signing transaction...');
            print('To: $to');
            print('Data: ${data[0]}');
            print('Data length: ${data[0].toString().length}');
            print('From: ${walletState.walletAddress}');
            
            // Re-validate wallet state before transaction
            final currentWalletState = ref.read(walletConnectionProvider);
            if (!currentWalletState.isConnected || currentWalletState.walletAddress == null) {
              throw Exception('Wallet disconnected during transaction. Please reconnect.');
            }
            
            // Use the updated wallet state from the beginning of the method
            final transactionChainId = updatedWalletState.chainId?.replaceAll('eip155:', '') ?? '';
            if (transactionChainId != '421614') {
              throw Exception('Wrong network. Please switch to Arbitrum Sepolia (Chain ID: 421614)');
            }
            
            // Validate transaction data
            if (data.isEmpty || data[0] == null || data[0].toString().isEmpty) {
              throw Exception('Invalid transaction data - data is empty or null');
            }
            
            if (to.isEmpty) {
              throw Exception('Invalid transaction target - to address is empty');
            }
            
            // Ensure transaction data is properly formatted as hex string
            String transactionData = data[0].toString();
            if (!transactionData.startsWith('0x')) {
              // If it doesn't start with 0x, add it
              transactionData = '0x$transactionData';
            }
            
            // Create transaction parameters with proper formatting for WalletConnect CAIP-2
            final transactionParams = {
              'to': to.toLowerCase(), // Ensure lowercase address
              'data': transactionData, // Properly formatted hex data
              'from': updatedWalletState.walletAddress!.toLowerCase(), // Use updated wallet state
              'gas': '0x${(1500000).toRadixString(16)}', // Significantly increased gas limit for event creation
              'gasPrice': '0x${(3000000000).toRadixString(16)}', // Increased to 3 gwei for better inclusion
              'value': '0x0', // No ETH being sent
            };
            
            print('📋 Transaction params: $transactionParams');
            print('📡 Sending to chain: eip155:$transactionChainId');
            print('📞 Session topic: ${updatedWalletState.sessionTopic}');
            
            // Show wallet dialog message to user
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: AppTheme.backgroundColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Check your wallet app to approve the transaction',
                          style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.backgroundColor),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppTheme.accentColor,
                  duration: const Duration(seconds: 10),
                ),
              );
            }
            
            try {
              print('🚀 Sending transaction to wallet...');
              print('📋 Transaction params: $transactionParams');
              print('📡 Chain ID: eip155:$transactionChainId');
              print('📞 Session topic: ${updatedWalletState.sessionTopic}');
              
              // Use ReownAppKit to sign and send the transaction
              final result = await reownAppKit.request(
                topic: updatedWalletState.sessionTopic!,
                chainId: 'eip155:$transactionChainId', // Use clean chain ID (421614)
                request: SessionRequestParams(
                  method: 'eth_sendTransaction',
                  params: [transactionParams],
                ),
              ).timeout(
                const Duration(seconds: 180), // Increased timeout to 3 minutes
                onTimeout: () {
                  print('⏰ Transaction request timed out after 3 minutes');
                  throw Exception('Transaction request timed out. The transaction may still be processing in your wallet.');
                },
              );
              
              print('📝 Raw transaction result: $result');
              print('📝 Result type: ${result.runtimeType}');
              
              // Handle different response formats
              String? transactionHash;
              
              if (result is String) {
                print('📝 Result is String: $result');
                if (result.startsWith('0x') && result.length == 66) {
                  transactionHash = result;
                } else {
                  print('⚠️ String result doesn\'t look like a transaction hash');
                }
              } else if (result is Map) {
                print('📝 Result is Map: $result');
                if (result.containsKey('hash')) {
                  final hash = result['hash'];
                  if (hash is String && hash.startsWith('0x') && hash.length == 66) {
                    transactionHash = hash;
                  }
                } else if (result.containsKey('transactionHash')) {
                  final hash = result['transactionHash'];
                  if (hash is String && hash.startsWith('0x') && hash.length == 66) {
                    transactionHash = hash;
                  }
                } else if (result.containsKey('txHash')) {
                  final hash = result['txHash'];
                  if (hash is String && hash.startsWith('0x') && hash.length == 66) {
                    transactionHash = hash;
                  }
                }
              } else if (result is List && result.isNotEmpty) {
                print('📝 Result is List: $result');
                final firstItem = result.first;
                if (firstItem is String && firstItem.startsWith('0x') && firstItem.length == 66) {
                  transactionHash = firstItem;
                }
              }
              
              if (transactionHash != null) {
                print('✅ Transaction hash extracted: $transactionHash');
                return transactionHash;
              } else {
                print('❌ Could not extract transaction hash from result: $result');
                // Check if the result indicates the transaction was sent but response was lost
                if (result != null && result.toString().isNotEmpty) {
                  print('⚠️ Transaction may have been sent but response format is unexpected');
                  throw Exception('Transaction was sent but response format is unexpected. Please check your wallet for the transaction status.');
                } else {
                  throw Exception('Transaction failed - no response received from wallet.');
                }
              }
              
            } catch (e) {
              print('❌ Transaction signing failed: $e');
              print('❌ Error type: ${e.runtimeType}');
              print('❌ Error details: ${e.toString()}');
              
              // Parse common errors
              final errorString = e.toString().toLowerCase();
              
              if (errorString.contains('user rejected') || 
                  errorString.contains('user cancelled') ||
                  errorString.contains('user canceled') ||
                  errorString.contains('rejected by user') ||
                  errorString.contains('cancelled by user') ||
                  errorString.contains('canceled by user')) {
                throw Exception('Transaction cancelled by user');
              } else if (errorString.contains('insufficient funds') || 
                         errorString.contains('insufficient balance')) {
                throw Exception('Insufficient ETH for gas fees');
              } else if (errorString.contains('nonce')) {
                throw Exception('Transaction nonce error. Please try again.');
              } else if (errorString.contains('timeout') || 
                         errorString.contains('timed out')) {
                throw Exception('Transaction timed out. Please check your wallet and try again.');
              } else if (errorString.contains('network') || 
                         errorString.contains('connection')) {
                throw Exception('Network error. Please check your connection and try again.');
              } else if (errorString.contains('gas')) {
                throw Exception('Gas estimation failed. Please try again.');
              } else {
                // For unknown errors, provide a more helpful message
                throw Exception('Transaction failed: ${e.toString()}');
              }
            }
          },
        );
      
      print('✅ Event creation transaction sent: $txHash');
      
      // Show transaction pending status
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.backgroundColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Transaction sent! Hash: ${txHash.substring(0, 10)}...',
                    style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.backgroundColor),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.accentColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
      // Step 6: Wait for transaction confirmation with improved polling
      print('⏳ Waiting for transaction confirmation...');
      
      // Show confirmation progress
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.backgroundColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Waiting for blockchain confirmation... This may take a few minutes.',
                    style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.backgroundColor),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 10),
          ),
        );
      }
      
      final receipt = await web3Service.waitForTransactionConfirmation(txHash);
      
      print('📋 Transaction Receipt Analysis:');
      if (receipt != null) {
        print('  - Transaction Hash: ${receipt.transactionHash}');
        print('  - Block Number: ${receipt.blockNumber}');
        print('  - Gas Used: ${receipt.gasUsed}');
        print('  - Status: ${receipt.status} (${receipt.status == true ? "SUCCESS" : "REVERTED"})');
        print('  - From: ${receipt.from}');
        print('  - To: ${receipt.to}');
        print('  - Contract Address: ${receipt.contractAddress}');
        print('  - Logs Count: ${receipt.logs.length}');
        print('🔗 View on Arbiscan: https://sepolia.arbiscan.io/tx/${receipt.transactionHash}');
      } else {
        print('  - Receipt is null - transaction may not be mined yet');
      }
      
      if (receipt != null && receipt.status == true) {
        print('✅ Event created successfully on blockchain!');
        
        // Step 7: Create local event record for Supabase
        final localEvent = models.Event(
          name: _nameController.text,
          description: _descriptionController.text,
          organizerWalletAddress: updatedWalletState.walletAddress!,
          latitude: _selectedAreaCenter?.latitude ?? _center.latitude,
          longitude: _selectedAreaCenter?.longitude ?? _center.longitude,
          venueName: _venueController.text,
          boundaries: _boundaryLocations.asMap().entries.map((entry) {
            final index = entry.key;
            final location = entry.value;
            
            return Boundary(
              name: 'Boundary ${index + 1}',
              description: 'NFT Boundary ${index + 1}',
              imageUrl: ipfsImageUrl,
              latitude: location.latitude,
              longitude: location.longitude,
              radius: _boundaryRadius,
              eventId: '', // Will be set when event is created
            );
          }).toList(),
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
          eventImageUrl: ipfsImageUrl,
        );
        
        // Save to Supabase for local reference
        final createdEvent = await supabaseService.createEvent(localEvent);
        print('✅ Local event record created with ID: ${createdEvent.id}');
        
        if (mounted) {
          _showEventCreatedDialog(createdEvent, txHash: txHash);
        }
      } else {
        // Transaction was reverted - provide detailed error information
        print('❌ Transaction REVERTED on blockchain');
        String revertReason = 'Unknown reason';
        String userMessage = 'Transaction Failed - Reverted on Blockchain';
        String debugInfo = '';
        
        if (receipt != null) {
          debugInfo = '''
📋 Transaction Details:
  - Hash: ${receipt.transactionHash}
  - Block: ${receipt.blockNumber}
  - Gas Used: ${receipt.gasUsed}
  - Status: REVERTED
  
🔗 View on Arbiscan: https://sepolia.arbiscan.io/tx/${receipt.transactionHash}
          ''';
          
          print('❌ Detailed revert information:');
          print('  - Transaction Hash: ${receipt.transactionHash}');
          print('  - Block Number: ${receipt.blockNumber}');
          print('  - Gas Used: ${receipt.gasUsed}');
          print('  - Revert analysis: Check Arbiscan for revert reason');
          
          // Common reasons for transaction revert in event creation:
          revertReason = '''
🚨 MOST LIKELY CAUSE: Invalid Parameters or Contract Logic

Possible causes:
• Event code "$eventCode" already exists
• Invalid timestamps or parameters
• Contract paused or restricted
• Network congestion
• Insufficient gas limit
          ''';
          
          userMessage = '''
Event Creation Failed - Transaction Reverted

Your transaction was confirmed on the blockchain but reverted due to a smart contract requirement.

Transaction Hash: 0x${receipt.transactionHash.map((e) => e.toRadixString(16).padLeft(2, '0')).join().substring(0, 20)}...

$revertReason

Please check the transaction on Arbiscan for detailed error information.
          ''';
        } else {
          revertReason = 'Transaction receipt is null - may not be mined';
          userMessage = '''
Event Creation Failed - No Transaction Receipt

The transaction may not have been mined or confirmed yet.

Please wait a few minutes and check your wallet history.
          ''';
        }
        
        print('❌ User will see: $userMessage');
        print(debugInfo);
        
        throw Exception(userMessage);
      }
    } catch (e) {
      print('❌ Error creating event: $e');
      
      // No more ORGANIZER_ROLE checking - anyone can create events now!
      print('❌ Event creation failed, but no role restrictions apply');
      
      if (mounted) {
        _showRetroError('Error creating event: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showRetroError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: AppTheme.backgroundColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.backgroundColor),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Pixelated
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showRetroSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppTheme.backgroundColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.backgroundColor),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Pixelated
        duration: const Duration(seconds: 8), // Longer duration for success messages
      ),
    );
  }

  // ORGANIZER_ROLE dialog removed - anyone can create events now!

  // All role-related dialogs removed - anyone can create events now!

  void _showEventCreatedDialog(models.Event event, {String? txHash}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Icon(
                Icons.celebration,
                color: AppTheme.accentColor,
                size: 32,
              ),
              const SizedBox(height: 16),
              Text(
                'EVENT CREATED!',
                style: AppTheme.modernTitle.copyWith(
                  fontSize: 20,
                  color: AppTheme.primaryColor,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Event Code
              Text(
                'YOUR EVENT CODE',
                style: AppTheme.modernButton.copyWith(
                  color: AppTheme.secondaryColor,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              
              // Event Code Display
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.eventCode,
                      style: AppTheme.modernTitle.copyWith(
                        fontSize: 16,
                        color: AppTheme.primaryColor,
                        letterSpacing: 2.0,
                        fontFamily: 'Courier',
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: event.eventCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Event code copied to clipboard!'),
                            backgroundColor: AppTheme.successColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                          ),
                        );
                      },
                      icon: Icon(Icons.copy, color: AppTheme.accentColor, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.backgroundColor,
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(40, 40),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Transaction Hash (if available)
              if (txHash != null) ...[
                const SizedBox(height: 16),
                Text(
                  'BLOCKCHAIN TRANSACTION',
                  style: AppTheme.modernButton.copyWith(
                    color: AppTheme.secondaryColor,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          txHash,
                          style: AppTheme.modernBodySecondary.copyWith(
                            color: AppTheme.textColor,
                            fontSize: 10,
                            fontFamily: 'Courier',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: txHash));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Transaction hash copied!'),
                              backgroundColor: AppTheme.successColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                            ),
                          );
                        },
                        icon: Icon(Icons.copy, color: AppTheme.accentColor, size: 16),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.backgroundColor,
                          padding: const EdgeInsets.all(4),
                          minimumSize: const Size(32, 32),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Success Notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.successColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        txHash != null 
                            ? 'Event created on blockchain successfully!'
                            : 'Event created successfully!',
                        style: AppTheme.modernBodySecondary.copyWith(
                          color: AppTheme.successColor,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/wallet/options');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.backgroundColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                  ),
                  child: Text(
                    'JOIN EVENT',
                    style: AppTheme.modernButton.copyWith(
                      color: AppTheme.backgroundColor,
                      fontSize: 14,
                      letterSpacing: 1.0,
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

  Future<void> _testWeb3Connection() async {
    try {
      print('🧪 Testing Web3 connection...');
      
      // Run comprehensive Web3 integration tests
      await TestWeb3Integration.runTests(ref);
      TestWeb3Integration.printTestResults();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppTheme.backgroundColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Web3 integration test completed successfully! Check console for details.',
                    style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.backgroundColor),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('❌ Web3 connection test failed: $e');
      if (mounted) {
        _showRetroError('Web3 connection test failed: $e');
      }
    }
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
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Create Event (Step ${_currentStep + 1}/$_totalSteps)',
                  style: AppTheme.modernSubtitle.copyWith(
                    fontSize: 15,
                    color: AppTheme.textColor,
                  ),
                ),
              ),
              // Wallet connection status
              WalletConnectionStatus(
                showAddress: true,
                showDisconnectButton: false,
              ),
            ],
          ),
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: AppTheme.modernContainerDecoration,
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: AppTheme.primaryColor),
              onPressed: () => context.go('/wallet/options'),
            ),
          ),
        ),
      body: Column(
        children: [
          // Modern Progress indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: AppTheme.modernContainerDecoration,
            child: Column(
              children: [
                Text(
                  'Progress',
                  style: AppTheme.modernButton.copyWith(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(_totalSteps, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
                        decoration: BoxDecoration(
                          color: index <= _currentStep 
                              ? AppTheme.primaryColor 
                              : AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: index <= _currentStep ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ] : null,
                        ),
                      ),
                    );
                  }),
                ),
              ],
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
                            // Test Web3 Connection Button
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ElevatedButton(
                                onPressed: _testWeb3Connection,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentColor,
                                  foregroundColor: AppTheme.backgroundColor,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: Text(
                                  'Test Web3 Connection',
                                  style: AppTheme.modernButton.copyWith(
                                    color: AppTheme.backgroundColor,
                                    fontSize: 12,
                                  ),
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
                          style: AppTheme.modernOutlinedButton,
                          child: Text(
                            'Previous',
                            style: AppTheme.modernButton.copyWith(
                              fontSize: 14,
                            ),
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
                        style: AppTheme.modernPrimaryButton.copyWith(
                          backgroundColor: MaterialStateProperty.all(
                            _canProceedToNextStep() ? AppTheme.primaryColor : AppTheme.cardColor,
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textColor),
                                ),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _currentStep == _totalSteps - 1 ? 'Create Event' : 'Next',
                                    style: AppTheme.modernButton.copyWith(
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (!_canProceedToNextStep()) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _getValidationMessage(),
                                      style: AppTheme.modernCaption.copyWith(
                                        fontSize: 10,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
                // Test button for wallet transaction dialog (only on final step)
                if (_currentStep == _totalSteps - 1) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _testWalletTransaction,
                      style: AppTheme.modernOutlinedButton.copyWith(
                        side: MaterialStateProperty.all(
                          BorderSide(color: AppTheme.accentColor.withOpacity(0.5)),
                        ),
                      ),
                      child: Text(
                        'Test Wallet Transaction',
                        style: AppTheme.modernButton.copyWith(
                          fontSize: 12,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ),
                  ),
                ],
                ],
              ),
            ),
        ],
      ),
      ),
    );
  }
}

