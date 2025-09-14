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
import '../../../shared/services/somnia_web3_service.dart';
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
  
  // Transaction state management
  bool _isTransactionInProgress = false;
  
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


  Future<void> _createEvent() async {
    print('🚀 Creating event with smart contract integration...');
    print('Current step: $_currentStep');
    print('Can proceed: ${_canProceedToNextStep()}');
    
    // Prevent concurrent transactions
    if (_isTransactionInProgress) {
      print('⚠️ Transaction already in progress, ignoring duplicate request');
      return;
    }
    
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
    print('🔍 Chain ID Analysis:');
    print('  - Raw chain ID: ${updatedWalletState.chainId}');
    print('  - Parsed chain ID: $currentChainId');
    print('  - Expected: 50312');
    print('  - Match: ${currentChainId == '50312'}');
    
    if (currentChainId != '50312') {
      print('⚠️ Wrong chain detected. Current: ${updatedWalletState.chainId} (parsed: $currentChainId), Expected: 50312');
      
      // Try to automatically switch
      print('🔄 Attempting to switch to Somnia Testnet...');
      final switched = await walletNotifier.switchToSomniaTestnet();
      
      if (!switched) {
        print('❌ Automatic switch failed, showing manual instructions');
        _showRetroError('Please manually switch to Somnia Testnet network in your wallet settings.');
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
      if (finalChainId != '50312') {
        print('❌ Chain switch still failed after automatic attempt');
        _showRetroError('Chain switch failed. Please manually switch to Somnia Testnet in your wallet settings.');
        return;
      }
      
      print('✅ Successfully switched to Somnia Testnet!');
    } else {
      print('✅ Already on Somnia Testnet (Chain ID: ${updatedWalletState.chainId} -> $currentChainId)');
    }
    
    setState(() {
      _isLoading = true;
      _isTransactionInProgress = true;
    });
    
    try {
      // Get services - use Somnia-specific service
      final web3Service = SomniaWeb3Service();
      web3Service.initialize(); // Initialize with Somnia Testnet
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
      
      // Step 5: Create event on blockchain using Somnia-specific approach
      print('⛓️ Creating event on blockchain (Somnia-specific)...');
      final reownAppKit = ref.read(reownAppKitProvider);
      if (reownAppKit == null) {
        throw Exception('Wallet not connected');
      }
      
      // Generate unique event code (simplified like Avalanche)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = (timestamp % 10000).toString().padLeft(4, '0');
      final eventCode = 'EVT_${timestamp}_$random';
      
      print('🎯 Generated Event Code: $eventCode');
      print('🎯 Timestamp: $timestamp');
      print('🎯 Random suffix: $random');
      
      // Check if event code already exists (optional - for debugging)
      try {
        final codeExists = await web3Service.eventCodeExists(eventCode);
        if (codeExists) {
          print('⚠️ Event code already exists, generating new one...');
          final newTimestamp = DateTime.now().millisecondsSinceEpoch;
          final newRandom = (newTimestamp % 10000).toString().padLeft(4, '0');
          final newEventCode = 'EVT_${newTimestamp}_$newRandom';
          print('🎯 New Event Code: $newEventCode');
        } else {
          print('✅ Event code is unique');
        }
      } catch (e) {
        print('⚠️ Could not check event code uniqueness: $e');
        // Continue anyway - the contract will handle duplicates
      }
      
      // Calculate timestamps - ensure start time is in the future
      final now = DateTime.now();
      final startDateTime = _startDate != null && _startTime != null
          ? DateTime(_startDate!.year, _startDate!.month, _startDate!.day, _startTime!.hour, _startTime!.minute)
          : now.add(Duration(minutes: 5)); // Default to 5 minutes from now
      final endDateTime = _endDate != null && _endTime != null
          ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day, _endTime!.hour, _endTime!.minute)
          : startDateTime.add(Duration(hours: 24)); // Default to 24 hours after start
      
      // Validate timestamps with better error messages
      if (startDateTime.isBefore(now)) {
        final timeDiff = now.difference(startDateTime);
        throw Exception('Start time must be in the future. Selected time is ${timeDiff.inMinutes} minutes in the past. Please select a future date and time.');
      }
      if (endDateTime.isBefore(startDateTime)) {
        final timeDiff = startDateTime.difference(endDateTime);
        throw Exception('End time must be after start time. End time is ${timeDiff.inMinutes} minutes before start time.');
      }
      
      // Additional validation for reasonable time ranges
      final eventDuration = endDateTime.difference(startDateTime);
      if (eventDuration.inDays > 365) {
        throw Exception('Event duration cannot exceed 365 days. Please select a shorter event period.');
      }
      if (eventDuration.inMinutes < 5) {
        throw Exception('Event duration must be at least 5 minutes. Please select a longer event period.');
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
      
      // Step 5: Create event using Avalanche-style approach
      print('🚀 Creating event on blockchain (Avalanche-style approach)...');
      print('📝 Using EventFactory address: ${web3Service.eventFactoryAddress}');
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
            // Use the updated wallet state from the beginning of the method
            final transactionChainId = updatedWalletState.chainId?.replaceAll('eip155:', '') ?? '';
            
            print('🔐 Signing transaction (Somnia-specific EIP-1559)...');
            print('To: $to');
            print('Data: ${data[0]}');
            print('Data length: ${data[0].toString().length}');
            print('From: ${walletState.walletAddress}');
            print('Chain ID: $transactionChainId');
            
            // Re-validate wallet state before transaction
            final currentWalletState = ref.read(walletConnectionProvider);
            if (!currentWalletState.isConnected || currentWalletState.walletAddress == null) {
              throw Exception('Wallet disconnected during transaction. Please reconnect.');
            }
            print('🔍 Transaction Chain ID Analysis:');
            print('  - Raw chain ID: ${updatedWalletState.chainId}');
            print('  - Parsed chain ID: $transactionChainId');
            print('  - Expected: 50312');
            print('  - Match: ${transactionChainId == '50312'}');
            
            if (transactionChainId != '50312') {
              throw Exception('Wrong network. Please switch to Somnia Testnet (Chain ID: 50312). Current: $transactionChainId');
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
            
            // Create transaction parameters using LEGACY GAS for Somnia Testnet
            // This avoids EIP-1559 issues that cause "User rejected" errors
            final gasLimit = 2000000; // 2M gas limit
            final gasPrice = 2000000000; // 2 gwei - legacy gas price
            final value = 0; // No STT being sent
            
            final transactionParams = {
              'to': to.toLowerCase(),
              'data': transactionData,
              'from': updatedWalletState.walletAddress!.toLowerCase(),
              'gas': '0x${gasLimit.toRadixString(16)}',
              'gasPrice': '0x${gasPrice.toRadixString(16)}', // Legacy gas price
              'value': '0x${value.toRadixString(16)}',
              // No 'type' field - this makes it a legacy transaction
            };
            
            print('🔧 Transaction Parameter Analysis (Legacy Gas):');
            print('  - To Address: ${transactionParams['to']}');
            print('  - From Address: ${transactionParams['from']}');
            print('  - Gas Limit: ${gasLimit} (0x${gasLimit.toRadixString(16)})');
            print('  - Gas Price: ${gasPrice} wei (${gasPrice / 1000000000} gwei)');
            print('  - Value: ${value} STT');
            print('  - Transaction Type: Legacy (no type field)');
            print('  - Data Length: ${transactionData.length} characters');
            print('  - Data Preview: ${transactionData.substring(0, 20)}...');
            
            print('📋 Transaction params: $transactionParams');
            print('📡 Sending to chain: eip155:$transactionChainId');
            print('📞 Session topic: ${updatedWalletState.sessionTopic}');
            
            // Pre-transaction validation
            print('🔍 Pre-transaction Validation (Legacy Gas):');
            print('  - Contract address valid: ${to.isNotEmpty && to.startsWith('0x') && to.length == 42}');
            print('  - Transaction data valid: ${transactionData.isNotEmpty && transactionData.startsWith('0x')}');
            print('  - Gas limit reasonable: ${gasLimit > 100000 && gasLimit < 10000000}');
            print('  - Gas price reasonable: ${gasPrice > 1000000000 && gasPrice < 10000000000}');
            print('  - Value is zero: ${value == 0}');
            print('  - Chain ID correct: $transactionChainId');
            print('  - Transaction type: Legacy (no type field)');
            
            // Calculate estimated gas cost
            final estimatedGasCost = (gasLimit * gasPrice) / 1000000000000000000; // Convert to STT
            print('  - Estimated gas cost: ${estimatedGasCost.toStringAsFixed(6)} STT');
            print('  - Gas cost in gwei: ${(gasLimit * gasPrice / 1000000000).toStringAsFixed(0)} gwei');
            
            // Show wallet dialog message to user
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: AppTheme.backgroundColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'MetaMask Transaction Ready',
                              style: AppTheme.modernBodySecondary.copyWith(
                                color: AppTheme.backgroundColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please check MetaMask and click "Confirm" to create your event. Do NOT click "Reject".',
                        style: AppTheme.modernBodySecondary.copyWith(
                          color: AppTheme.backgroundColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppTheme.accentColor,
                  duration: const Duration(seconds: 15),
                ),
              );
            }
            
            try {
              print('🚀 Sending transaction to wallet (Somnia Testnet - Legacy Gas)...');
              print('📋 Transaction params: $transactionParams');
              print('📡 Chain ID: eip155:$transactionChainId');
              print('📞 Session topic: ${updatedWalletState.sessionTopic}');
              
              // Validate session before making request
              if (updatedWalletState.sessionTopic == null) {
                throw Exception('Wallet session not available. Please reconnect your wallet.');
              }
              
              // Show user that transaction is being sent to wallet
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
                            'Sending legacy gas transaction... Please check MetaMask.',
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
              
              final result = await reownAppKit.request(
                topic: updatedWalletState.sessionTopic!,
                chainId: 'eip155:$transactionChainId',
                request: SessionRequestParams(
                  method: 'eth_sendTransaction',
                  params: [transactionParams],
                ),
              ).timeout(
                const Duration(seconds: 180), // 3 minutes timeout
                onTimeout: () {
                  print('⏰ Transaction request timed out after 3 minutes');
                  throw Exception('Transaction request timed out. The transaction may still be processing in your wallet.');
                },
              );
              
              print('📝 Raw transaction result: $result');
              print('📝 Result type: ${result.runtimeType}');
              print('📝 Result is null: ${result == null}');
              
              // Enhanced result handling with better debugging
              String? transactionHash;
              
              if (result == null) {
                print('❌ Result is null - this might indicate user rejection or network issue');
                throw Exception('No response from wallet - transaction may have been cancelled');
              }
              
              if (result is String) {
                print('📝 Result is String: $result');
                print('📝 String length: ${result.length}');
                print('📝 Starts with 0x: ${result.startsWith('0x')}');
                
                if (result.startsWith('0x') && result.length == 66) {
                  transactionHash = result;
                  print('✅ Valid transaction hash found in string result');
                } else if (result.toLowerCase().contains('user rejected') || 
                          result.toLowerCase().contains('cancelled') ||
                          result.toLowerCase().contains('rejected')) {
                  print('❌ User rejection detected in string result');
                  throw Exception('Transaction cancelled by user');
                } else {
                  print('❌ Invalid string result format: $result');
                  throw Exception('Invalid response from wallet: $result');
                }
              } else if (result is Map) {
                print('📝 Result is Map with keys: ${result.keys.toList()}');
                print('📝 Full map result: $result');
                
                // Check for user rejection FIRST (before looking for hash)
                if (result.containsKey('code') && result.containsKey('message')) {
                  final code = result['code'];
                  final message = result['message'];
                  print('📝 Error code: $code, message: $message');
                  
                  // Common rejection codes
                  if (code == 5000 || code == 4001 || code == -32000) {
                    final messageStr = message.toString().toLowerCase();
                    if (messageStr.contains('user rejected') ||
                        messageStr.contains('cancelled') ||
                        messageStr.contains('rejected') ||
                        messageStr.contains('denied')) {
                      print('❌ User rejection confirmed by error code and message');
                      throw Exception('Transaction cancelled by user');
                    }
                  }
                }
                
                // Check for transaction hash in various possible keys
                final possibleHashKeys = ['hash', 'transactionHash', 'txHash', 'transaction_id'];
                for (final key in possibleHashKeys) {
                  if (result.containsKey(key)) {
                    final hash = result[key];
                    print('📝 Found potential hash in key "$key": $hash');
                    if (hash is String && hash.startsWith('0x') && hash.length == 66) {
                      transactionHash = hash;
                      print('✅ Valid transaction hash found in key "$key"');
                      break;
                    }
                  }
                }
                
                // If no hash found, check if it's a pending/processing state
                if (transactionHash == null) {
                  if (result.containsKey('status') || result.containsKey('pending')) {
                    print('📝 Transaction appears to be pending/processing');
                    // Don't throw error for pending transactions - wait for completion
                    throw Exception('Transaction is still processing. Please wait for confirmation.');
                  }
                  
                  print('❌ No valid transaction hash found in map result');
                  print('❌ Available keys: ${result.keys.toList()}');
                  throw Exception('Transaction failed - no valid hash in response: $result');
                }
              } else if (result is List && result.isNotEmpty) {
                print('📝 Result is List with ${result.length} items');
                print('📝 First item: ${result.first}');
                print('📝 First item type: ${result.first.runtimeType}');
                
                final firstItem = result.first;
                if (firstItem is String && firstItem.startsWith('0x') && firstItem.length == 66) {
                  transactionHash = firstItem;
                  print('✅ Valid transaction hash found in list result');
                } else {
                  print('❌ Invalid first item in list result: $firstItem');
                  throw Exception('Invalid response format from wallet');
                }
              } else {
                print('❌ Unexpected result type: ${result.runtimeType}');
                print('❌ Result value: $result');
                throw Exception('Unexpected response type from wallet: ${result.runtimeType}');
              }
              
              if (transactionHash != null) { // ignore: unnecessary_null_comparison
                print('✅ Transaction hash successfully extracted: $transactionHash');
                return transactionHash;
              }
              
              print('❌ Could not extract transaction hash from result: $result');
              throw Exception('Transaction failed - could not extract transaction hash');
              
            } catch (e) {
              print('❌ Transaction signing failed: $e');
              print('❌ Error type: ${e.runtimeType}');
              print('❌ Full error details: ${e.toString()}');
              
              // Enhanced error handling with Somnia Testnet specific debugging
              final errorString = e.toString().toLowerCase();
              print('❌ Error string analysis: $errorString');
              print('❌ Full error details: ${e.toString()}');
              print('❌ Error type: ${e.runtimeType}');
              
              // Check for Somnia Testnet specific issues first
              if (errorString.contains('gas price') || errorString.contains('gasprice')) {
                print('❌ Gas price error detected');
                throw Exception('Gas price error. Please check your wallet gas settings for Somnia Testnet. Try increasing gas price to 3-5 gwei.');
              } else if (errorString.contains('chain id') || errorString.contains('chainid')) {
                print('❌ Chain ID error detected');
                throw Exception('Chain ID error. Please ensure you are connected to Somnia Testnet (Chain ID: 50312).');
              } else if (errorString.contains('user rejected') || 
                         errorString.contains('cancelled') ||
                         errorString.contains('rejected by user') ||
                         errorString.contains('user denied') ||
                         errorString.contains('user cancelled')) {
                print('❌ Confirmed user rejection');
                throw Exception('Transaction cancelled by user. Please try again and make sure to click "Confirm" in MetaMask.');
              } else if (errorString.contains('still processing') || 
                         errorString.contains('processing') ||
                         errorString.contains('pending')) {
                print('❌ Transaction is still processing');
                throw Exception('Transaction is still being processed in your wallet. Please wait for confirmation or check your wallet history.');
              } else if (errorString.contains('insufficient funds') || 
                         errorString.contains('insufficient balance') ||
                         errorString.contains('not enough')) {
                print('❌ Insufficient funds error');
                throw Exception('Insufficient STT for gas fees. Please add more STT to your wallet from the faucet: https://testnet.somnia.network/');
              } else if (errorString.contains('timeout') || 
                         errorString.contains('timed out')) {
                print('❌ Timeout error');
                throw Exception('Transaction timed out. Please try again.');
              } else if (errorString.contains('network') || 
                         errorString.contains('connection') ||
                         errorString.contains('unreachable')) {
                print('❌ Network error');
                throw Exception('Network error. Please check your connection to Somnia Testnet and try again.');
              } else if (errorString.contains('no response')) {
                print('❌ No response from wallet');
                throw Exception('No response from wallet. Please check your wallet connection and try again.');
              } else if (errorString.contains('invalid response') || 
                         errorString.contains('unexpected')) {
                print('❌ Invalid response error');
                throw Exception('Invalid response from wallet. Please try again.');
              } else if (errorString.contains('revert') || errorString.contains('execution reverted')) {
                print('❌ Transaction reverted');
                throw Exception('Transaction reverted on Somnia Testnet. This may be due to invalid parameters or contract issues. Please check the transaction on the explorer.');
              } else {
                print('❌ Generic error - providing detailed message');
                throw Exception('Transaction failed on Somnia Testnet (Legacy Gas): ${e.toString()}');
              }
            }
          },
        );
      
      print('✅ Event creation transaction sent: $txHash');
      
      // Validate transaction hash format
      if (txHash.length != 66 || !txHash.startsWith('0x')) {
        throw Exception('Invalid transaction hash received from wallet');
      }
      
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
      print('📝 Transaction Hash: $txHash');
      print('🔗 Check on Somnia Explorer: https://shannon-explorer.somnia.network/tx/$txHash');
      
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
                    'Transaction sent! Waiting for blockchain confirmation...',
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
        print('🔗 View on Somnia Explorer: https://shannon-explorer.somnia.network/tx/${receipt.transactionHash}');
      } else {
        print('  - Receipt is null - transaction may not be mined yet');
        print('⚠️ Transaction confirmation timed out, but transaction may still be pending');
        print('🔗 Check on Somnia Explorer: https://shannon-explorer.somnia.network/tx/$txHash');
      }
      
      // If we have a receipt and it's successful, proceed normally
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
      } else if (receipt == null) {
        // Transaction confirmation timed out, but transaction was sent
        print('⚠️ Transaction confirmation timed out, but proceeding with local event creation');
        print('⚠️ User can check transaction status manually on the explorer');
        
        // Create local event record even without blockchain confirmation
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
          _showEventCreatedDialog(createdEvent, txHash: txHash, isPending: true);
        }
      } else {
        // Transaction was reverted - provide detailed error information
        print('❌ Transaction REVERTED on blockchain');
        String revertReason = 'Unknown reason';
        String userMessage = 'Transaction Failed - Reverted on Blockchain';
        String debugInfo = '';
        
        if (receipt != null) { // ignore: unnecessary_null_comparison
          debugInfo = '''
📋 Transaction Details:
  - Hash: ${receipt.transactionHash}
  - Block: ${receipt.blockNumber}
  - Gas Used: ${receipt.gasUsed}
  - Status: REVERTED
  
🔗 View on Somnia Explorer: https://shannon-explorer.somnia.network/tx/${receipt.transactionHash}
          ''';
          
          print('❌ Detailed revert information:');
          print('  - Transaction Hash: ${receipt.transactionHash}');
          print('  - Block Number: ${receipt.blockNumber}');
          print('  - Gas Used: ${receipt.gasUsed}');
          print('  - Revert analysis: Check Somnia Explorer for revert reason');
          
          // Common reasons for transaction revert in event creation:
          revertReason = '''
🚨 TRANSACTION REVERTED - Most Likely Causes:

1. Event Code Already Exists
   • Code "$eventCode" may already be used
   • Try creating with a different name

2. Invalid Parameters
   • Start time must be in the future
   • End time must be after start time
   • Invalid coordinates or venue data

3. Contract Issues
   • Contract may be paused
   • Insufficient gas for execution
   • Network congestion

4. Gas Issues
   • Gas limit too low for execution
   • Gas price too low for network

🔍 Check the transaction on Somnia Explorer for detailed error logs.
          ''';
          
          userMessage = '''
❌ Event Creation Failed - Transaction Reverted

Your transaction was confirmed but failed during execution.

Transaction Hash: ${receipt.transactionHash.toString().substring(0, 20)}...

$revertReason

🔗 View Details: https://shannon-explorer.somnia.network/tx/${receipt.transactionHash}
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
        String userMessage = 'Failed to create event';
        
        // Parse error for user-friendly messages
        final errorString = e.toString().toLowerCase();
        
        if (errorString.contains('cancelled by user') || 
            errorString.contains('rejected by user') ||
            errorString.contains('transaction cancelled')) {
          userMessage = '''🚫 Transaction was cancelled in MetaMask

Troubleshooting:
• Make sure you click "Confirm" not "Reject" in MetaMask
• Check that you have enough STT for gas fees
• Ensure you're on Somnia Testnet network
• Try increasing gas limit if MetaMask shows warning
• Check MetaMask for any error messages''';
        } else if (errorString.contains('still being processed') || 
                   errorString.contains('processing') ||
                   errorString.contains('pending')) {
          userMessage = '⏳ Transaction is still processing in your wallet. Please check MetaMask and wait for confirmation.';
        } else if (errorString.contains('insufficient funds') || 
                   errorString.contains('insufficient balance')) {
          userMessage = '💰 Insufficient funds for transaction fees. Please add more STT to your wallet.';
        } else if (errorString.contains('network') || 
                   errorString.contains('connection')) {
          userMessage = '🌐 Network connection error. Please check your internet and try again';
        } else if (errorString.contains('timeout')) {
          userMessage = '⏰ Transaction timed out. The transaction may still be processing in your wallet.';
        } else if (errorString.contains('gas')) {
          userMessage = '⛽ Transaction failed due to gas issues. Please try again with higher gas limit.';
        } else if (errorString.contains('no response')) {
          userMessage = '📱 No response from wallet. Please check your wallet connection and try again.';
        } else {
          userMessage = 'Event creation failed. Please check your wallet and try again. Error: ${e.toString()}';
        }
        
        _showRetroError(userMessage);
      }
    } finally {
      setState(() {
        _isLoading = false;
        _isTransactionInProgress = false;
      });
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


  // ORGANIZER_ROLE dialog removed - anyone can create events now!

  // All role-related dialogs removed - anyone can create events now!

  void _showEventCreatedDialog(models.Event event, {String? txHash, bool isPending = false}) {
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
                isPending ? 'EVENT CREATED (PENDING)' : 'EVENT CREATED!',
                style: AppTheme.modernTitle.copyWith(
                  fontSize: 20,
                  color: isPending ? AppTheme.accentColor : AppTheme.primaryColor,
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
              
              // Pending Notice (if applicable)
              if (isPending) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: AppTheme.accentColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Transaction is pending confirmation. Check the explorer link above for status.',
                          style: AppTheme.modernBodySecondary.copyWith(
                            color: AppTheme.accentColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
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
                        isPending 
                            ? 'Event created locally! Transaction is pending confirmation on blockchain.'
                            : txHash != null 
                                ? 'Event created on blockchain successfully!'
                                : 'Event created successfully!',
                        style: AppTheme.modernBodySecondary.copyWith(
                          color: isPending ? AppTheme.accentColor : AppTheme.successColor,
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
                ],
              ),
            ),
        ],
      ),
      ),
    );
  }
}

