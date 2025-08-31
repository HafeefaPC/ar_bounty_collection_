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
import '../../../shared/models/event.dart';
import '../../../shared/models/boundary.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/services/wallet_service.dart';
import '../../../shared/services/smart_contract_service.dart';
import '../../../shared/providers/reown_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _initializeWalletService();
  }

  Future<void> _initializeWalletService() async {
    // No need to initialize wallet service here anymore
    // It's handled by the AppProviderWrapper
    debugPrint('Wallet service initialization skipped - handled by provider wrapper');
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
                      style: AppTheme.retroBody.copyWith(color: AppTheme.backgroundColor),
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
                      style: AppTheme.retroBody.copyWith(color: AppTheme.backgroundColor),
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
          decoration: AppTheme.retroPixelBorder(AppTheme.errorColor),
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
                style: AppTheme.retroSubtitle.copyWith(
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
          style: AppTheme.retroBody.copyWith(
            color: AppTheme.textColor,
            fontSize: 12,
          ),
        ),
        actions: [
          Container(
            decoration: AppTheme.retroPixelBorder(AppTheme.textColor.withOpacity(0.3)),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'CANCEL',
                style: AppTheme.retroButton.copyWith(
                  color: AppTheme.textColor.withOpacity(0.8),
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          Container(
            decoration: AppTheme.retroPixelBorder(AppTheme.errorColor),
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
                            style: AppTheme.retroBody.copyWith(color: AppTheme.backgroundColor),
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
                style: AppTheme.retroButton.copyWith(
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
          style: AppTheme.retroSubtitle.copyWith(color: AppTheme.primaryColor),
        ),
        content: Text(
          message,
          style: AppTheme.retroBody.copyWith(color: AppTheme.textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTheme.retroButton.copyWith(color: AppTheme.secondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onAction();
            },
            style: AppTheme.retroPrimaryButton,
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
              decoration: AppTheme.retroPixelBorder(AppTheme.primaryColor),
              child: Text(
                'EVENT DETAILS',
                style: AppTheme.retroTitle.copyWith(
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
              decoration: AppTheme.retroInputDecoration(
                labelText: 'EVENT TITLE *',
                hintText: 'Enter your event title',
              ),
              style: AppTheme.retroBody.copyWith(color: AppTheme.textColor),
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
              decoration: AppTheme.retroInputDecoration(
                labelText: 'EVENT DESCRIPTION *',
                hintText: 'Describe your event',
              ),
              style: AppTheme.retroBody.copyWith(color: AppTheme.textColor),
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
                      decoration: AppTheme.retroPixelBorder(AppTheme.secondaryColor),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'START DATE',
                            style: AppTheme.retroButton.copyWith(
                              color: AppTheme.secondaryColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _startDate != null
                                ? DateFormat('MMM dd, yyyy').format(_startDate!)
                                : 'SELECT DATE',
                            style: AppTheme.retroBody.copyWith(
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
                      decoration: AppTheme.retroPixelBorder(AppTheme.accentColor),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'START TIME',
                            style: AppTheme.retroButton.copyWith(
                              color: AppTheme.accentColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _startTime != null
                                ? _startTime!.format(context)
                                : 'SELECT TIME',
                            style: AppTheme.retroBody.copyWith(
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
                      decoration: AppTheme.retroPixelBorder(AppTheme.secondaryColor),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'END DATE',
                            style: AppTheme.retroButton.copyWith(
                              color: AppTheme.secondaryColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _endDate != null
                                ? DateFormat('MMM dd, yyyy').format(_endDate!)
                                : 'SELECT DATE',
                            style: AppTheme.retroBody.copyWith(
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
                      decoration: AppTheme.retroPixelBorder(AppTheme.accentColor),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'END TIME',
                            style: AppTheme.retroButton.copyWith(
                              color: AppTheme.accentColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _endTime != null
                                ? _endTime!.format(context)
                                : 'SELECT TIME',
                            style: AppTheme.retroBody.copyWith(
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
              decoration: AppTheme.retroInputDecoration(
                labelText: 'VENUE/LOCATION *',
                hintText: 'Enter event venue',
              ),
              style: AppTheme.retroBody.copyWith(color: AppTheme.textColor),
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
              decoration: AppTheme.retroInputDecoration(
                labelText: 'NFT SUPPLY COUNT *',
                hintText: 'Enter number of NFTs',
              ).copyWith(
                suffixText: 'NFTs',
                suffixStyle: TextStyle(color: AppTheme.primaryColor),
              ),
              style: AppTheme.retroBody.copyWith(color: AppTheme.textColor),
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
                decoration: AppTheme.retroPixelBorder(AppTheme.primaryColor),
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
                            style: AppTheme.retroButton.copyWith(
                              color: AppTheme.primaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
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
            decoration: AppTheme.retroPixelBorder(AppTheme.primaryColor),
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
                  style: AppTheme.retroTitle.copyWith(
                    fontSize: 20,
                    color: AppTheme.primaryColor,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap on the map to set the center of your event area',
                  style: AppTheme.retroBody.copyWith(
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
            decoration: AppTheme.retroPixelBorder(AppTheme.secondaryColor),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: AppTheme.retroInputDecoration(
                      labelText: 'SEARCH LOCATION',
                      hintText: 'Enter location name...',
                    ).copyWith(
                      prefixIcon: Icon(Icons.search, color: AppTheme.secondaryColor),
                    ),
                    style: AppTheme.retroBody.copyWith(color: AppTheme.textColor),
                    onSubmitted: (_) => _searchLocation(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: AppTheme.retroPixelBorder(AppTheme.primaryColor),
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
            decoration: AppTheme.retroPixelBorder(AppTheme.accentColor),
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
            decoration: AppTheme.retroPixelBorder(AppTheme.primaryColor),
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
                      style: AppTheme.retroSubtitle.copyWith(
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
                  decoration: AppTheme.retroPixelBorder(AppTheme.secondaryColor),
                  child: Text(
                    '${_selectedAreaRadius.round()} METERS',
                    style: AppTheme.retroTitle.copyWith(
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
                  style: AppTheme.retroBody.copyWith(
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
            decoration: AppTheme.retroPixelBorder(AppTheme.secondaryColor),
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
                  style: AppTheme.retroTitle.copyWith(
                    fontSize: 20,
                    color: AppTheme.secondaryColor,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure how users will claim your NFTs',
                  style: AppTheme.retroBody.copyWith(
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
            decoration: AppTheme.retroPixelBorder(AppTheme.primaryColor),
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
                      style: AppTheme.retroSubtitle.copyWith(
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
                  decoration: AppTheme.retroPixelBorder(AppTheme.accentColor),
                  child: Text(
                    '${_boundaryRadius.round()} METERS',
                    style: AppTheme.retroTitle.copyWith(
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
                  decoration: AppTheme.retroPixelBorder(AppTheme.textColor.withOpacity(0.3)),
                  child: Text(
                    'Users must be within this radius to claim the NFT',
                    style: AppTheme.retroBody.copyWith(
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
            decoration: AppTheme.retroPixelBorder(AppTheme.accentColor),
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
                      style: AppTheme.retroSubtitle.copyWith(
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
            decoration: AppTheme.retroPixelBorder(AppTheme.accentColor),
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
                  style: AppTheme.retroTitle.copyWith(
                    fontSize: 20,
                    color: AppTheme.accentColor,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap on the map or use current location to place $nftSupplyCount NFT locations',
                  style: AppTheme.retroBody.copyWith(
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
            decoration: AppTheme.retroPixelBorder(AppTheme.primaryColor),
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
                      style: AppTheme.retroSubtitle.copyWith(
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
                  decoration: AppTheme.retroPixelBorder(AppTheme.secondaryColor),
                  child: Text(
                    '${_boundaryLocations.length} / $nftSupplyCount',
                    style: AppTheme.retroTitle.copyWith(
                      fontSize: 32,
                      color: AppTheme.secondaryColor,
                      letterSpacing: 2.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: AppTheme.retroPixelBorder(AppTheme.textColor.withOpacity(0.3)),
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
                  style: AppTheme.retroButton.copyWith(
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
            decoration: AppTheme.retroPixelBorder(AppTheme.primaryColor),
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
                      style: AppTheme.retroSubtitle.copyWith(
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
                        decoration: AppTheme.retroPixelBorder(AppTheme.secondaryColor),
                        child: ElevatedButton.icon(
                          onPressed: _addNFTAtCurrentLocation,
                          icon: Icon(Icons.my_location, color: AppTheme.backgroundColor),
                          label: Text(
                            'ADD AT CURRENT LOCATION',
                            textAlign: TextAlign.start,
                            style: AppTheme.retroButton.copyWith(
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
                      decoration: AppTheme.retroPixelBorder(AppTheme.accentColor),
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
                    decoration: AppTheme.retroPixelBorder(AppTheme.errorColor.withOpacity(0.3)),
                    child: ElevatedButton.icon(
                      onPressed: _clearAllBoundaries,
                      icon: Icon(Icons.clear_all, color: AppTheme.primaryColor),
                      label: Text(
                        'CLEAR ALL BOUNDARIES',
                        style: AppTheme.retroButton.copyWith(
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
                  style: AppTheme.retroBody.copyWith(
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
            decoration: AppTheme.retroPixelBorder(AppTheme.primaryColor),
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
            decoration: AppTheme.retroPixelBorder(AppTheme.primaryColor),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: AppTheme.retroPixelBorder(AppTheme.accentColor),
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
                        style: AppTheme.retroButton.copyWith(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap on the map or use the "ADD AT CURRENT LOCATION" button to place boundary locations. Each green marker represents one NFT location.',
                        style: AppTheme.retroBody.copyWith(
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

  Widget _buildRetroSummaryRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.retroPixelBorder(AppTheme.textColor.withOpacity(0.2)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTheme.retroButton.copyWith(
              color: AppTheme.textColor.withOpacity(0.8),
              fontSize: 12,
              letterSpacing: 1.0,
            ),
          ),
          Text(
            value,
            style: AppTheme.retroBody.copyWith(
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
    print('Creating event...');
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
    
    setState(() => _isLoading = true);
    
    try {
      // Get the wallet connection state from the provider
      final walletState = ref.read(walletConnectionProvider);
      final walletNotifier = ref.read(walletConnectionProvider.notifier);
      final appKitModal = ref.read(reownAppKitProvider);
      
      print('Wallet connection state:');
      print('- isConnected: ${walletState.isConnected}');
      print('- walletAddress: ${walletState.walletAddress}');
      print('- chainId: ${walletState.chainId}');
      print('- isWalletReady: ${walletNotifier.isWalletReady()}');
      print('- appKitModal: ${appKitModal != null ? 'exists' : 'null'}');
      
      // Check if wallet is properly connected and ready
      if (!walletNotifier.isWalletReady()) {
        _showRetroError('Wallet not properly connected. Please reconnect your wallet to create events on the blockchain.');
        setState(() => _isLoading = false);
        return;
      }
      
      final walletAddress = walletState.walletAddress ?? 'demo_wallet';
      
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
      
      // Step 1: Create event on blockchain
      print('Creating event on blockchain...');
      final smartContractService = SmartContractService();
      
      // Set the app kit modal in the smart contract service
      if (appKitModal != null) {
        smartContractService.setAppKitModal(appKitModal);
        print('AppKit modal set successfully');
        
        // Verify wallet is ready for transactions
        if (!smartContractService.isWalletReady()) {
          final status = smartContractService.getWalletStatus();
          print('Smart contract service wallet status: $status');
          _showRetroError('Wallet not ready for transactions. Please reconnect your wallet.');
          setState(() => _isLoading = false);
          return;
        }
      } else {
        print('AppKit modal is null - wallet may not be properly connected');
        _showRetroError('Wallet connection issue. Please reconnect your wallet.');
        setState(() => _isLoading = false);
        return;
      }
      
      final blockchainResult = await smartContractService.createEventOnBlockchain(
        name: event.name,
        description: event.description,
        venue: event.venueName,
        startTime: event.startDate ?? DateTime.now(),
        endTime: event.endDate ?? DateTime.now().add(const Duration(days: 1)),
        totalNFTs: event.nftSupplyCount,
        metadataURI: event.eventImageUrl ?? '',
        eventCode: event.eventCode,
        latitude: event.latitude,
        longitude: event.longitude,
        radius: _selectedAreaRadius,
      );
      
      if (!blockchainResult['success']) {
        throw Exception('Blockchain transaction failed: ${blockchainResult['error']}');
      }
      
      print('Event created on blockchain: ${blockchainResult['transactionHash']}');
      
      // Step 2: Save to Supabase with blockchain transaction hash
      final supabaseService = SupabaseService();
      final createdEvent = await supabaseService.createEvent(event);
      
      // Step 3: Mint boundary NFTs on blockchain
      print('Minting boundary NFTs on blockchain...');
      final mintResult = await smartContractService.mintBoundaryNFTs(
        eventId: int.parse(createdEvent.id), // Assuming ID is numeric
        boundaries: boundaries.map((b) => {
          'name': b.name,
          'description': b.description,
          'imageUrl': b.imageUrl,
          'latitude': b.latitude,
          'longitude': b.longitude,
          'radius': b.radius,
        }).toList(),
      );
      
      if (mintResult['success']) {
        print('Boundary NFTs minted: ${mintResult['successfulMints']}/${mintResult['totalBoundaries']}');
      } else {
        print('Warning: Some boundary NFTs failed to mint: ${mintResult['error']}');
      }
      
      if (mounted) {
        _showEventCreatedDialog(createdEvent, blockchainResult['transactionHash']);
      }
    } catch (e) {
      print('Error creating event: $e');
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
                style: AppTheme.retroBody.copyWith(color: AppTheme.backgroundColor),
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

  void _showEventCreatedDialog(Event event, [String? transactionHash]) {
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
                style: AppTheme.retroTitle.copyWith(
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
                style: AppTheme.retroButton.copyWith(
                  color: AppTheme.secondaryColor,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              
              // Event Code Display
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.retroPixelBorder(AppTheme.primaryColor),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.eventCode,
                      style: AppTheme.retroTitle.copyWith(
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
                    style: AppTheme.retroButton.copyWith(
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



  Future<void> _testCreateMinimalEvent() async {
    try {
      final supabaseService = SupabaseService();
      
      // Test the minimal event creation method
      final success = await supabaseService.testMinimalEventCreation();
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test event creation successful! Database connection working.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        // Show a more detailed error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed. Check console for details.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Show Details',
              textColor: Colors.white,
              onPressed: () {
                _showDebugInfo();
              },
            ),
          ),
        );
      }
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

  void _showDebugInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Debug Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Error: Test event creation failed'),
            SizedBox(height: 8),
            Text('Please check:'),
            Text('1. Console output for detailed logs'),
            Text('2. Supabase project configuration'),
            Text('3. RLS policies and permissions'),
            Text('4. API keys and project URL'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAuthErrorDetails({String? error}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Anonymous Authentication Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null) ...[
              Text('Error Details:', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding: EdgeInsets.all(8),
                margin: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(error, style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
              ),
              SizedBox(height: 8),
            ],
            Text('Common Solutions:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('1. Enable Anonymous Signups in Supabase:'),
            Text('   • Go to Supabase Dashboard'),
            Text('   • Authentication > Settings'),
            Text('   • Turn ON "Enable anonymous signups"'),
            SizedBox(height: 8),
            Text('2. Check API Keys:'),
            Text('   • Verify URL and anon key in main.dart'),
            Text('   • Ensure project is active'),
            SizedBox(height: 8),
            Text('3. Check Project Status:'),
            Text('   • Ensure project is not paused'),
            Text('   • Check if there are any restrictions'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
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
          style: AppTheme.retroSubtitle.copyWith(
            fontSize: 18,
            color: AppTheme.primaryColor,
            shadows: [
              Shadow(
                offset: const Offset(2, 2),
                blurRadius: 0,
                color: AppTheme.primaryColor.withOpacity(0.5),
              ),
            ],
          ),
        ),
                leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: AppTheme.retroPixelBorder(AppTheme.primaryColor),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: AppTheme.primaryColor),
            onPressed: () => context.go('/wallet/options'),
          ),
        ),
      ),
      body: Column(
        children: [
          // Retro Progress indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(0), // Pixelated
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5), width: 1),
            ),
            child: Column(
              children: [
                Text(
                  'PROGRESS',
                  style: AppTheme.retroButton.copyWith(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(_totalSteps, (index) {
                    return Expanded(
                      child: Container(
                        height: 8,
                        margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
                        decoration: BoxDecoration(
                          color: index <= _currentStep 
                              ? AppTheme.primaryColor 
                              : AppTheme.surfaceColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(0), // Pixelated
                          border: Border.all(
                            color: index <= _currentStep 
                                ? AppTheme.primaryColor 
                                : AppTheme.primaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: index <= _currentStep ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.6),
                              offset: const Offset(2, 2),
                              blurRadius: 0,
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

                           
                            
                          ],
                        ),
                    ],
                  ),
                Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: Container(
                          decoration: AppTheme.retroPixelBorder(AppTheme.secondaryColor),
                          child: OutlinedButton(
                            onPressed: _previousStep,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide.none,
                              backgroundColor: AppTheme.surfaceColor.withOpacity(0.3),
                            ),
                            child: Text(
                              'PREVIOUS',
                              style: AppTheme.retroButton.copyWith(
                                color: AppTheme.secondaryColor,
                                fontSize: 14,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: _canProceedToNextStep() 
                            ? AppTheme.retroAnimatedContainer(
                                color: AppTheme.primaryColor,
                                isGlowing: true,
                              )
                            : AppTheme.retroPixelBorder(Colors.grey),
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
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0), // Pixelated
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.backgroundColor),
                                  ),
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _currentStep == _totalSteps - 1 ? 'CREATE EVENT' : 'NEXT',
                                      style: AppTheme.retroButton.copyWith(
                                        color: AppTheme.backgroundColor,
                                        fontSize: 14,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    if (!_canProceedToNextStep()) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _getValidationMessage(),
                                        style: TextStyle(
                                          color: AppTheme.backgroundColor.withOpacity(0.7),
                                          fontSize: 10,
                                          fontFamily: 'Courier',
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                    )
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

