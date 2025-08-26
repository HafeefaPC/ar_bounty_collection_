import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

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
  final int _totalSteps = 3;
  
  // Step 1: Event Details
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  
  // Step 2: Area Selection
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  LatLng? _selectedAreaCenter;
  double _selectedAreaRadius = 100.0; // meters
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  
  // Step 3: Boundary Creation
  final List<Boundary> _boundaries = [];
  final ImagePicker _imagePicker = ImagePicker();
  double _boundaryRadius = 2.0; // Default 2 meters for boundary radius
  
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
      if (_mapController != null) {
        _mapController.animateCamera(CameraUpdate.newLatLngZoom(_center, _zoom));
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text('Create Event - Step ${_currentStep + 1}/$_totalSteps'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _testSupabaseConnection,
            icon: const Icon(Icons.wifi),
            tooltip: 'Test Supabase Connection',
          ),
        ],
      ),
      body: Column(
            children: [
          // Progress indicator
          _buildProgressIndicator(),
              
          // Step content
              Expanded(
            child: _buildCurrentStep(),
              ),
              
          // Navigation buttons
          _buildNavigationButtons(),
            ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Event Details', style: TextStyle(
                fontWeight: _currentStep >= 0 ? FontWeight.bold : FontWeight.normal,
                color: _currentStep >= 0 ? AppTheme.primaryColor : Colors.grey,
              )),
              Text('Select Area', style: TextStyle(
                fontWeight: _currentStep >= 1 ? FontWeight.bold : FontWeight.normal,
                color: _currentStep >= 1 ? AppTheme.primaryColor : Colors.grey,
              )),
              Text('Add Boundaries', style: TextStyle(
                fontWeight: _currentStep >= 2 ? FontWeight.bold : FontWeight.normal,
                color: _currentStep >= 2 ? AppTheme.primaryColor : Colors.grey,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildEventDetailsStep();
      case 1:
        return _buildAreaSelectionStep();
      case 2:
        return _buildBoundaryCreationStep();
      default:
        return const Center(child: Text('Unknown step'));
    }
  }

  Widget _buildEventDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event Information',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
              ),
            const SizedBox(height: 24),
            
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Event Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter event name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Event Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _venueController,
              decoration: const InputDecoration(
                labelText: 'Venue Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter venue name';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
              Text(
                          'Event Details',
                style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Enter the basic information about your event\n'
                      '• This will be visible to participants\n'
                      '• You can add boundaries in the next steps',
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
        // Instructions
        Container(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  Row(
                    children: [
                      Icon(Icons.map, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                          Text(
                        'Select Event Area',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Search for your location or tap on the map\n'
                    '2. Adjust the radius using the slider below\n'
                    '3. This area will contain all your boundaries',
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Search and Current Location Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search for location (e.g., "Central Park, NY")',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isSearching 
                          ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: _searchLocation,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSearching ? null : () => _searchLocation(_searchController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Search'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    // Check location permissions first
                    LocationPermission permission = await Geolocator.checkPermission();
                    if (permission == LocationPermission.denied) {
                      permission = await Geolocator.requestPermission();
                      if (permission == LocationPermission.denied) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Location permission is required to get your current location'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                    }

                    if (permission == LocationPermission.deniedForever) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Location permissions are permanently denied. Please enable them in settings.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Check if location services are enabled
                    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                    if (!serviceEnabled) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Location services are disabled. Please enable GPS.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    final position = await Geolocator.getCurrentPosition(
                      desiredAccuracy: LocationAccuracy.high,
                    );
                    final currentLocation = LatLng(position.latitude, position.longitude);
                    
                    setState(() {
                      _selectedAreaCenter = currentLocation;
                      _center = currentLocation;
                    });
                    
                    _updateEventArea();
                    
                    // Animate camera to the new location
                    if (_mapController != null) {
                      _mapController.animateCamera(
                        CameraUpdate.newLatLngZoom(currentLocation, 15.0),
                      );
                    }
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Event center set to your current location'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error getting current location: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.my_location),
                label: const Text('Use Current Location as Event Center'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Map
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GoogleMap(
                onMapCreated: (controller) {
                  _mapController = controller;
                  _getCurrentLocation();
                },
                initialCameraPosition: CameraPosition(
                  target: _center,
                  zoom: _zoom,
                ),
                onTap: _onMapTap,
                markers: _markers,
                circles: _circles,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
              ),
            ),
          ),
        ),
        
        // Radius slider
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Event Area Radius:'),
                  Text('${_selectedAreaRadius.round()} meters'),
                ],
              ),
              Slider(
                value: _selectedAreaRadius,
                min: 50.0,
                max: 1000.0,
                divisions: 19,
                label: '${_selectedAreaRadius.round()}m',
                onChanged: (value) {
                  setState(() {
                    _selectedAreaRadius = value;
                    _updateEventArea();
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBoundaryCreationStep() {
    return Column(
      children: [
                // Instructions
        Container(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Boundaries',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            Text(
                              'Create claimable locations for participants',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_boundaries.length} boundaries added • Each boundary is a claimable location for participants',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Boundaries list
        Expanded(
          child: _boundaries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_off,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No Boundaries Added',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start by adding your first boundary',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Tap the button below to get started',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _boundaries.length,
                  itemBuilder: (context, index) {
                    final boundary = _boundaries[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          boundary.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          boundary.description ?? 'No description provided',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        trailing: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeBoundary(index),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
        
        // Add boundary button
        Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _addBoundary,
            icon: const Icon(Icons.add_location, size: 24),
            label: const Text(
              'Add Boundary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: AppTheme.primaryColor.withOpacity(0.3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Previous'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_currentStep == _totalSteps - 1 ? 'Create Event' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedAreaCenter = position;
      _updateEventArea();
    });
  }

  void _updateEventArea() {
    if (_selectedAreaCenter != null) {
      setState(() {
        _markers.clear();
        _circles.clear();
        
        _markers.add(Marker(
          markerId: const MarkerId('event_center'),
          position: _selectedAreaCenter!,
          infoWindow: const InfoWindow(title: 'Event Center'),
        ));
        
        _circles.add(Circle(
          circleId: const CircleId('event_area'),
          center: _selectedAreaCenter!,
          radius: _selectedAreaRadius,
          fillColor: AppTheme.primaryColor.withOpacity(0.2),
          strokeColor: AppTheme.primaryColor,
          strokeWidth: 2,
        ));
      });
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final newCenter = LatLng(location.latitude, location.longitude);
        
        setState(() {
          _selectedAreaCenter = newCenter;
          _center = newCenter;
        });
        
        _updateEventArea();
        
        // Animate camera to the new location
        if (_mapController != null) {
          _mapController.animateCamera(
            CameraUpdate.newLatLngZoom(newCenter, 15.0),
          );
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found: $query'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
          content: Text('Could not find location: $query'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          ),
        );
    } finally {
        setState(() {
        _isSearching = false;
        });
      }
    }

  void _addBoundary() {
    _showBoundaryDialog();
  }

  void _addBoundaryWithLocation(String name, String description, String? imagePath, LatLng location) {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter boundary name')),
      );
      return;
    }
    if (imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }
    
    final boundary = Boundary(
      name: name,
      description: description,
      imageUrl: imagePath,
      latitude: location.latitude,
      longitude: location.longitude,
      radius: _boundaryRadius,
      eventId: '', // Will be set when event is created
    );
    
    setState(() {
      _boundaries.add(boundary);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Boundary "$name" added at your current location'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _removeBoundary(int index) {
    setState(() {
      _boundaries.removeAt(index);
    });
  }

    void _showBoundaryDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedImagePath;
    LatLng? selectedLocation = _selectedAreaCenter ?? _center;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 400,
              maxHeight: 600,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add_location,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Add New Boundary',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Boundary Name
                        Text(
                          'Boundary Name *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'Enter boundary name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Description
                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: descriptionController,
                          decoration: InputDecoration(
                            hintText: 'Enter description (optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),
                
                        // Location Selection
                        Text(
                          'Boundary Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Choose how to set the boundary location:',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        // Get current location
                                        try {
                                          // Check location permissions first
                                          LocationPermission permission = await Geolocator.checkPermission();
                                          if (permission == LocationPermission.denied) {
                                            permission = await Geolocator.requestPermission();
                                            if (permission == LocationPermission.denied) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Location permission is required to get your current location'),
                                                  backgroundColor: Colors.orange,
                                                ),
                                              );
                                              return;
                                            }
                                          }

                                          if (permission == LocationPermission.deniedForever) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Location permissions are permanently denied. Please enable them in settings.'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                            return;
                                          }

                                          // Check if location services are enabled
                                          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                                          if (!serviceEnabled) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Location services are disabled. Please enable GPS.'),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                            return;
                                          }

                                          final position = await Geolocator.getCurrentPosition(
                                            desiredAccuracy: LocationAccuracy.high,
                                          );
                                          final currentLocation = LatLng(position.latitude, position.longitude);
                                          
                                          // Check if current location is within event area
                                          if (_selectedAreaCenter != null) {
                                            final distance = _calculateDistance(
                                              _selectedAreaCenter!.latitude,
                                              _selectedAreaCenter!.longitude,
                                              currentLocation.latitude,
                                              currentLocation.longitude,
                                            );
                                            
                                            if (distance <= _selectedAreaRadius) {
                                              setDialogState(() {
                                                selectedLocation = currentLocation;
                                              });
                                              Navigator.of(context).pop();
                                              _addBoundaryWithLocation(nameController.text, descriptionController.text, selectedImagePath, currentLocation);
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Your current location is outside the event area (${distance.round()}m away). Please move closer or select a different location.'),
                                                  backgroundColor: Colors.orange,
                                                ),
                                              );
                                            }
                                          } else {
                                            setDialogState(() {
                                              selectedLocation = currentLocation;
                                            });
                                            Navigator.of(context).pop();
                                            _addBoundaryWithLocation(nameController.text, descriptionController.text, selectedImagePath, currentLocation);
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error getting current location: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.my_location, size: 20),
                                      label: const Text(
                                        'Use Current Location',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.accentColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _showLocationPickerDialog(nameController.text, descriptionController.text, selectedImagePath);
                                      },
                                      icon: const Icon(Icons.map, size: 20),
                                      label: const Text(
                                        'Select on Map',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                                // Boundary Radius
                        Text(
                          'Boundary Radius',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Set the radius (in meters) for this boundary. Users must be within this distance to claim.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Radius: ${_boundaryRadius.round()}m',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        _boundaryRadius = 2.0; // Default 2 meters
                                      });
                                    },
                                    icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                                    tooltip: 'Reset to 2m',
                                  ),
                                ],
                              ),
                              Slider(
                                value: _boundaryRadius,
                                min: 1.0,
                                max: 10.0,
                                divisions: 9,
                                label: '${_boundaryRadius.round()}m',
                                activeColor: AppTheme.primaryColor,
                                onChanged: (value) {
                                  setDialogState(() {
                                    _boundaryRadius = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Image Selection
                        Text(
                          'Boundary Image',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final image = await _imagePicker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1024,
                              maxHeight: 1024,
                            );
                            if (image != null) {
                              setDialogState(() {
                                selectedImagePath = image.path;
                              });
                            }
                          },
                          icon: const Icon(Icons.image, size: 20),
                          label: const Text(
                            'Select Image',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            foregroundColor: Colors.grey[700],
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                        ),
                        if (selectedImagePath != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Image selected: ${selectedImagePath!.split('/').last}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                // Footer Actions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (nameController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter boundary name')),
                              );
                              return;
                            }
                            if (selectedImagePath == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select an image')),
                              );
                              return;
                            }
                            
                            final boundary = Boundary(
                              name: nameController.text,
                              description: descriptionController.text,
                              imageUrl: selectedImagePath!,
                              latitude: selectedLocation!.latitude,
                              longitude: selectedLocation!.longitude,
                              radius: _boundaryRadius,
                              eventId: '', // Will be set when event is created
                            );
                            
                            setState(() {
                              _boundaries.add(boundary);
                            });
                            
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Add Boundary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLocationPickerDialog(String name, String description, String? imagePath) {
    LatLng? selectedLocation = _selectedAreaCenter ?? _center;
    final Set<Marker> boundaryMarkers = {};
    final Set<Circle> eventAreaCircle = {};
    
    // Add event area circle
    if (_selectedAreaCenter != null) {
      eventAreaCircle.add(Circle(
        circleId: const CircleId('event_area_picker'),
        center: _selectedAreaCenter!,
        radius: _selectedAreaRadius,
        fillColor: AppTheme.primaryColor.withOpacity(0.1),
        strokeColor: AppTheme.primaryColor,
        strokeWidth: 2,
      ));
    }
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Boundary Location'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                Text(
                  'Tap within the event area to place your boundary',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GoogleMap(
                      onMapCreated: (controller) {
                        controller.animateCamera(
                          CameraUpdate.newLatLngZoom(_selectedAreaCenter ?? _center, 16.0),
                        );
                      },
                      initialCameraPosition: CameraPosition(
                        target: _selectedAreaCenter ?? _center,
                        zoom: 16.0,
                      ),
                      onTap: (location) {
                        // Check if location is within event area
                        if (_selectedAreaCenter != null) {
                          final distance = _calculateDistance(
                            _selectedAreaCenter!.latitude,
                            _selectedAreaCenter!.longitude,
                            location.latitude,
                            location.longitude,
                          );
                          
                          if (distance <= _selectedAreaRadius) {
                            setDialogState(() {
                              selectedLocation = location;
                              boundaryMarkers.clear();
                              boundaryMarkers.add(Marker(
                                markerId: const MarkerId('boundary_location'),
                                position: location,
                                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                                infoWindow: InfoWindow(title: name),
                              ));
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a location within the event area'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        } else {
                          setDialogState(() {
                            selectedLocation = location;
                            boundaryMarkers.clear();
                            boundaryMarkers.add(Marker(
                              markerId: const MarkerId('boundary_location'),
                              position: location,
                              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                              infoWindow: InfoWindow(title: name),
                            ));
                          });
                        }
                      },
                      markers: boundaryMarkers,
                      circles: eventAreaCircle,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: false,
                    ),
                  ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
              onPressed: () {
                if (selectedLocation != null) {
                  final boundary = Boundary(
                    name: name,
                    description: description,
                    imageUrl: imagePath ?? '',
                    latitude: selectedLocation!.latitude,
                    longitude: selectedLocation!.longitude,
                    eventId: '', // Will be set when event is created
                  );
                  
                  setState(() {
                    _boundaries.add(boundary);
                  });
                  
                  Navigator.of(context).pop();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Boundary "$name" added at selected location'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              },
              child: const Text('Confirm Location'),
            ),
          ],
        ),
      ),
    );
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

  void _showEventCreatedDialog(Event event) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successColor, size: 28),
            const SizedBox(width: 8),
            const Text('Event Created Successfully!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your event "${event.name}" has been created successfully!',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.qr_code, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Event Code',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.eventCode,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: event.eventCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Event code copied to clipboard!'),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy to clipboard',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share this code with participants so they can join your event!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Event Details:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text('• Venue: ${event.venueName}'),
            Text('• Boundaries: ${event.boundaries.length} locations'),
            Text('• Event Code: ${event.eventCode}'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/wallet/options');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validate event details
    if (!_formKey.currentState!.validate()) return;
      setState(() {
        _currentStep++;
      });
    } else if (_currentStep == 1) {
      // Validate area selection
      if (_selectedAreaCenter == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an event area on the map'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      setState(() {
        _currentStep++;
      });
    } else if (_currentStep == 2) {
      // Create event
      _createEvent();
    }
  }

  Future<void> _createEvent() async {
    if (_boundaries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one boundary'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final walletService = WalletService();
      final walletAddress = walletService.connectedWalletAddress ?? 'demo_wallet';
      
      // Create event
      final event = Event(
        name: _nameController.text,
        description: _descriptionController.text,
        organizerWalletAddress: walletAddress,
        latitude: _selectedAreaCenter?.latitude ?? _center.latitude,
        longitude: _selectedAreaCenter?.longitude ?? _center.longitude,
        venueName: _venueController.text,
        boundaries: _boundaries,
      );
      
      // Save to Supabase
      final supabaseService = SupabaseService();
      
      // Test connection first
      final isConnected = await supabaseService.testConnection();
      if (!isConnected) {
        throw Exception('Cannot connect to Supabase. Please check your internet connection and database setup.');
      }
      
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

  // Test Supabase connection
  Future<void> _testSupabaseConnection() async {
    setState(() => _isLoading = true);
    
    try {
      final supabaseService = SupabaseService();
      final isConnected = await supabaseService.testConnection();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isConnected 
              ? 'Supabase connection successful!' 
              : 'Supabase connection failed. Please check database setup.'),
            backgroundColor: isConnected ? AppTheme.successColor : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection test error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    super.dispose();
  }
}

