import 'dart:io';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';
import '../models/boundary.dart';
import '../models/goodie.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  
  // Verify Supabase configuration
  void verifyConfiguration() {
    try {
      final client = _client;
      print('Client initialized: ${client != null}');
      print('Auth state: ${client.auth.currentSession != null ? "Authenticated" : "Not authenticated"}');
    } catch (e) {
      print('Error verifying Supabase configuration: $e');
    }
  }
  
  // Public getter for external services that need direct client access
  SupabaseClient get client => _client;
  
  // Test basic Supabase connectivity
  Future<bool> testBasicConnectivity() async {
    try {
      print('=== TESTING BASIC CONNECTIVITY ===');
      print('Testing if we can reach Supabase...');
      
      // Try to access the auth endpoint
      final response = await _client.auth.signInAnonymously();
      print('Basic connectivity test successful');
      return true;
    } catch (e) {
      print('=== BASIC CONNECTIVITY TEST FAILED ===');
      print('Basic connectivity test failed: $e');
      print('Error type: ${e.runtimeType}');
      
      if (e.toString().contains('Network error')) {
        print('Network connectivity issue detected');
      }
      
      if (e.toString().contains('Invalid API key')) {
        print('API key issue detected');
      }
      
      return false;
    }
  }

  // Test if we can access the database at all
  Future<bool> testDatabaseAccess() async {
    try {
      print('=== TESTING DATABASE ACCESS ===');
      print('Testing basic database access...');
      
      // Check auth state first
      print('Current auth state: ${_client.auth.currentSession != null ? "Authenticated" : "Not authenticated"}');
      
      // Try to access a simple table or view
      final response = await _client
          .from('users')
          .select('id')
          .limit(1);
      
      print('Database access test successful: ${response.length} records found');
      print('=== DATABASE ACCESS TEST COMPLETED ===');
      return true;
    } catch (e) {
      print('=== DATABASE ACCESS TEST FAILED ===');
      print('Database access test failed: $e');
      print('Error type: ${e.runtimeType}');
      print('Full error details: $e');
      return false;
    }
  }

  // Ensure storage bucket exists for NFT images
  Future<void> _ensureStorageBucket() async {
    try {
      print('=== ENSURING STORAGE BUCKET ===');
      
      // Check if bucket exists
      final buckets = await _client.storage.listBuckets();
      print('Available buckets: ${buckets.map((b) => b.name).toList()}');
      
      // Use existing 'images' bucket instead of 'nft-images'
      final bucketExists = buckets.any((bucket) => bucket.name == 'images');
      print('images bucket exists: $bucketExists');
      
      if (!bucketExists) {
        print('Creating images storage bucket...');
        try {
          await _client.storage.createBucket('images');
          print('images storage bucket created successfully');
        } catch (createError) {
          print('Error creating bucket: $createError');
          // Try to continue anyway
        }
      } else {
        print('images storage bucket already exists - using existing bucket');
      }
    } catch (e) {
      print('Error ensuring storage bucket: $e');
      print('Full error details: ${e.toString()}');
      // Continue anyway - bucket might already exist
    }
  }

  // Test anonymous authentication specifically
  Future<Map<String, dynamic>> testAnonymousAuth() async {
    try {
      print('=== TESTING ANONYMOUS AUTHENTICATION ===');
      print('Testing anonymous authentication...');
      
      // Check current state
      print('Before auth - User: ${_client.auth.currentUser}');
      print('Before auth - Session: ${_client.auth.currentSession}');
      
      // Try to sign in anonymously
      final authResponse = await _client.auth.signInAnonymously();
      print('Auth response received: ${authResponse.user?.id}');
      
      // Check state after auth
      print('After auth - User: ${_client.auth.currentUser}');
      print('After auth - Session: ${_client.auth.currentSession}');
      
      if (_client.auth.currentSession != null) {
        print('=== ANONYMOUS AUTH TEST SUCCESSFUL ===');
        return {'success': true, 'message': 'Authentication successful'};
      } else {
        print('=== ANONYMOUS AUTH TEST FAILED - No session ===');
        return {'success': false, 'message': 'No session created after authentication'};
      }
    } catch (e) {
      print('=== ANONYMOUS AUTH TEST FAILED ===');
      print('Anonymous auth test failed: $e');
      print('Error type: ${e.runtimeType}');
      print('Full error details: $e');
      
      String errorMessage = e.toString();
      
      // Check if this is a configuration issue
      if (e.toString().contains('Anonymous signups are disabled')) {
        print('ERROR: Anonymous signups are disabled in your Supabase project');
        print('SOLUTION: Enable anonymous signups in Supabase Dashboard > Authentication > Settings');
        errorMessage = 'Anonymous signups are disabled in your Supabase project. Go to Authentication > Settings and enable anonymous signups.';
      }
      
      if (e.toString().contains('Invalid API key')) {
        print('ERROR: Invalid API key');
        print('SOLUTION: Check your Supabase anon key in main.dart');
        errorMessage = 'Invalid API key. Please check your Supabase configuration in main.dart.';
      }
      
      if (e.toString().contains('Network error')) {
        errorMessage = 'Network error. Please check your internet connection and Supabase project status.';
      }
      
      return {'success': false, 'message': errorMessage};
    }
  }

  // Test minimal event creation
  Future<bool> testMinimalEventCreation() async {
    try {
      print('=== TESTING MINIMAL EVENT CREATION ===');
      print('Testing minimal event creation...');
      
      // Check current auth state
      print('Current auth state:');
      print('- User: ${_client.auth.currentUser}');
      print('- Session: ${_client.auth.currentSession}');
      print('- Auth state: ${_client.auth.currentSession != null ? "Authenticated" : "Not authenticated"}');
      
      // Ensure we have a session
      if (_client.auth.currentSession == null) {
        print('No session found, attempting anonymous sign in...');
        try {
          final authResponse = await _client.auth.signInAnonymously();
          print('Anonymous sign in response: ${authResponse.user?.id}');
          print('Session after sign in: ${_client.auth.currentSession}');
        } catch (authError) {
          print('Anonymous sign in failed: $authError');
          print('Auth error type: ${authError.runtimeType}');
          throw Exception('Failed to authenticate: $authError');
        }
      }
      
      // Verify we now have a session
      if (_client.auth.currentSession == null) {
        throw Exception('Still no session after authentication attempt');
      }
      
      print('Authentication successful, proceeding with event creation...');
      
      // Try to create a minimal event
      final testEventData = {
        'name': 'Test Event',
        'description': 'Test Description',
        'organizer_wallet_address': 'test_wallet',
        'latitude': 37.7749,
        'longitude': -122.4194,
        'venue_name': 'Test Venue',
        'event_code': 'TEST_${DateTime.now().millisecondsSinceEpoch}',
        'nft_supply_count': 1,
      };
      
      print('Inserting test event data: $testEventData');
      
      final response = await _client
          .from('events')
          .insert(testEventData)
          .select()
          .single();
      
      print('Test event created successfully: ${response['id']}');
      
      // Clean up - delete the test event
      await _client
          .from('events')
          .delete()
          .eq('id', response['id']);
      
      print('Test event cleaned up');
      print('=== TEST COMPLETED SUCCESSFULLY ===');
      return true;
    } catch (e) {
      print('=== TEST FAILED ===');
      print('Test minimal event creation failed: $e');
      print('Error type: ${e.runtimeType}');
      print('Full error details: $e');
      
      // Try to get more specific error information
      if (e.toString().contains('PostgrestException')) {
        print('This is a PostgrestException - likely a database permission issue');
      }
      
      if (e.toString().contains('Authentication required')) {
        print('Authentication issue detected');
      }
      
      return false;
    }
  }

  // Test Supabase connection
  Future<bool> testConnection() async {
    try {
      print('Testing Supabase connection...');
      verifyConfiguration();
      print('Client initialized: ${_client != null}');
      print('Current user: ${_client.auth.currentUser}');
      print('Current session: ${_client.auth.currentSession}');
      
      // If no session exists, try to sign in anonymously
      if (_client.auth.currentSession == null) {
        print('No session found, attempting anonymous sign in...');
        try {
          await _client.auth.signInAnonymously();
          print('Anonymous sign in successful');
        } catch (authError) {
          print('Anonymous sign in failed: $authError');
          // Continue anyway, some Supabase setups work without auth
        }
      }
      
      // Try to make a simple query to test connection
      final response = await _client
          .from('events')
          .select('id, name, event_code')
          .limit(5);
      print('Supabase connection test successful: ${response.length} records found');
      
      if (response.isNotEmpty) {
        print('Sample events in database:');
        for (final event in response) {
          print('  - ${event['name']} (Code: ${event['event_code']})');
        }
      }
      
      return true;
    } catch (e) {
      print('Supabase connection test failed: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: ${e.toString()}');
      return false;
    }
  }

  // Event Operations
  Future<List<Event>> getEvents() async {
    try {
      print('=== GETTING ALL EVENTS ===');
      
      // Get all events first
      final eventsResponse = await _client
          .from('events')
          .select('*')
          .order('created_at', ascending: false);
      
      print('Found ${eventsResponse.length} events');
      
      // Convert events with their boundaries and goodies
      final events = <Event>[];
      for (final eventData in eventsResponse) {
        try {
          // Get boundaries for this event
          final boundariesResponse = await _client
              .from('boundaries')
              .select('*')
              .eq('event_id', eventData['id']);
          
          // Get goodies for this event
          final goodiesResponse = await _client
              .from('goodies')
              .select('*')
              .eq('event_id', eventData['id']);
          
          // Create event with boundaries and goodies
          final event = Event.fromJson({
            ...eventData,
            'boundaries': boundariesResponse,
            'goodies': goodiesResponse,
          });
          
          events.add(event);
        } catch (e) {
          print('Error processing event ${eventData['name']}: $e');
          // Continue with other events
        }
      }
      
      print('Successfully processed ${events.length} events');
      return events;
    } catch (e) {
      print('Error fetching events: $e');
      return [];
    }
  }

  // Enhanced get event by code with all boundaries (from EnhancedSupabaseService)
  Future<Event?> getEventByCode(String eventCode) async {
    try {
      print('=== GETTING EVENT BY CODE ===');
      print('Event code: $eventCode');
      print('Event code type: ${eventCode.runtimeType}');
      print('Event code length: ${eventCode.length}');
      
      // First, let's check if the event exists at all
      final eventCheck = await _client
          .from('events')
          .select('id, name, event_code')
          .eq('event_code', eventCode);
      
      print('Event check result: ${eventCheck.length} events found');
      if (eventCheck.isNotEmpty) {
        print('Found event: ${eventCheck.first}');
      }
      
      // Get the event first
      final eventResponse = await _client
          .from('events')
          .select('*')
          .eq('event_code', eventCode)
          .single();

      if (eventResponse == null) {
        print('No event found for code: $eventCode');
        return null;
      }

      print('Event found: ${eventResponse['name']}');
      print('Event ID: ${eventResponse['id']}');
      print('Event code from DB: ${eventResponse['event_code']}');
      
      // Debug: Print all event fields
      print('=== EVENT DATA STRUCTURE ===');
      eventResponse.forEach((key, value) {
        print('  $key: $value (${value.runtimeType})');
      });

      // Now get boundaries separately to avoid join issues
      final boundariesResponse = await _client
          .from('boundaries')
          .select('*')
          .eq('event_id', eventResponse['id']);

      print('Boundaries found: ${boundariesResponse.length}');
      
      // Debug: Print first boundary structure if available
      if (boundariesResponse.isNotEmpty) {
        print('=== FIRST BOUNDARY DATA STRUCTURE ===');
        final firstBoundary = boundariesResponse.first as Map<String, dynamic>;
        firstBoundary.forEach((key, value) {
          print('  $key: $value (${value.runtimeType})');
        });
      }

      // Convert boundaries
      final boundaries = <Boundary>[];
      for (final boundaryData in boundariesResponse) {
        try {
          final boundary = Boundary.fromJson(boundaryData as Map<String, dynamic>);
          boundaries.add(boundary);
          print('Successfully converted boundary: ${boundary.name}');
        } catch (e) {
          print('Error converting boundary: $e');
          print('Boundary data: $boundaryData');
        }
      }

      print('Converted ${boundaries.length} boundaries');

      // Create event with proper data structure
      print('Creating Event object with data:');
      print('  - Event data keys: ${eventResponse.keys.toList()}');
      print('  - Boundaries count: ${boundaries.length}');
      
      try {
        // Convert boundaries back to JSON format for Event.fromJson
        final boundariesJson = boundaries.map((b) => b.toJson()).toList();
        print('Converted boundaries to JSON format');
        
        final event = Event.fromJson({
          ...eventResponse,
          'boundaries': boundariesJson,  // Now it's List<Map<String, dynamic>>
        });
        
        print('Successfully created Event object: ${event.name}');
        return event;
      } catch (e) {
        print('Error creating Event object: $e');
        print('Error type: ${e.runtimeType}');
        print('Full error details: ${e.toString()}');
        return null;
      }
    } catch (e) {
      print('Error getting event by code: $e');
      print('Error type: ${e.runtimeType}');
      print('Full error details: ${e.toString()}');
      
      // Check if this is a "not found" error
      if (e.toString().contains('No rows returned')) {
        print('This appears to be a "not found" error - event code $eventCode does not exist in database');
      }
      
      return null;
    }
  }

  // Get all events with their boundary counts (from EnhancedSupabaseService)
  Future<List<Map<String, dynamic>>> getEventsWithStats() async {
    try {
      print('=== GETTING EVENTS WITH STATS ===');
      
      // Get all events first
      final eventsResponse = await _client
          .from('events')
          .select('*');

      print('Found ${eventsResponse.length} events');
      
      final eventsWithStats = <Map<String, dynamic>>[];
      
      for (final event in eventsResponse) {
        try {
          // Get boundaries for this event
          final boundariesResponse = await _client
              .from('boundaries')
              .select('id, is_claimed')
              .eq('event_id', event['id']);
          
          final boundaries = boundariesResponse as List<dynamic>;
          final totalBoundaries = boundaries.length;
          final claimedBoundaries = boundaries
              .where((b) => b['is_claimed'] == true)
              .length;
          
          eventsWithStats.add({
            ...event,
            'total_boundaries': totalBoundaries,
            'claimed_boundaries': claimedBoundaries,
            'completion_percentage': totalBoundaries > 0 
                ? (claimedBoundaries / totalBoundaries * 100).round()
                : 0,
          });
        } catch (e) {
          print('Error processing event ${event['name']}: $e');
          // Continue with other events
        }
      }
      
      print('Successfully processed ${eventsWithStats.length} events with stats');
      return eventsWithStats;
    } catch (e) {
      print('Error getting events with stats: $e');
      return [];
    }
  }

  Future<Event> createEvent(Event event) async {
    try {
      print('=== CREATING EVENT ===');
      print('Creating event: ${event.name}');
      print('Supabase client initialized: ${_client != null}');
      print('Current session: ${_client.auth.currentSession}');
      
      // Ensure we have a valid session
      if (_client.auth.currentSession == null) {
        print('No session found, attempting anonymous sign in...');
        try {
          final authResponse = await _client.auth.signInAnonymously();
          print('Anonymous sign in response: ${authResponse.user?.id}');
          print('Session after sign in: ${_client.auth.currentSession}');
          
          // Verify we now have a session
          if (_client.auth.currentSession == null) {
            throw Exception('Authentication failed - no session after sign in');
          }
        } catch (authError) {
          print('Anonymous sign in failed: $authError');
          print('Auth error type: ${authError.runtimeType}');
          throw Exception('Authentication required for event creation: $authError');
        }
      }
      
      print('Authentication verified, proceeding with event creation...');
      
      // Ensure storage bucket exists
      await _ensureStorageBucket();
      
      // Upload event image to Supabase storage if it's a local file
      String? eventImageUrl = event.eventImageUrl;
      if (eventImageUrl != null && eventImageUrl.startsWith('/')) {
        print('Uploading event image to Supabase storage...');
        try {
          final file = File(eventImageUrl);
          if (await file.exists()) {
            final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
            final bytes = await file.readAsBytes();
            
            await _client.storage
                .from('images')
                .uploadBinary(fileName, bytes);
            
            eventImageUrl = _client.storage
                .from('images')
                .getPublicUrl(fileName);
            
            print('Event image uploaded successfully: $eventImageUrl');
            print('Final event image URL stored in database: $eventImageUrl');
          }
        } catch (uploadError) {
          print('Failed to upload event image: $uploadError');
          print('Full upload error details: ${uploadError.toString()}');
          // Continue without image if upload fails
        }
      } else {
        print('Event image URL is not a local file: $eventImageUrl');
      }
      
      // First create the event
      final eventData = {
        'id': event.id,
        'name': event.name,
        'description': event.description,
        'organizer_wallet_address': event.organizerWalletAddress,
        'latitude': event.latitude,
        'longitude': event.longitude,
        'venue_name': event.venueName,
        'event_code': event.eventCode,
        'start_date': event.startDate?.toIso8601String(),
        'end_date': event.endDate?.toIso8601String(),
        'nft_supply_count': event.nftSupplyCount,
        'event_image_url': eventImageUrl,
        'boundary_description': event.boundaryDescription,
        'notification_distances': event.notificationDistances,
        'visibility_radius': event.visibilityRadius,
      };

      print('Event data prepared: $eventData');
      
      final createdEventResponse = await _client
          .from('events')
          .insert(eventData)
          .select()
          .single();

      final createdEvent = Event.fromJson(createdEventResponse);
      
      // Now create boundaries separately
      if (event.boundaries.isNotEmpty) {
        for (var boundary in event.boundaries) {
          // Upload boundary NFT image to Supabase storage if it's a local file
          String? boundaryImageUrl = boundary.imageUrl;
          if (boundaryImageUrl != null && boundaryImageUrl.startsWith('/')) {
            print('Uploading boundary NFT image to Supabase storage...');
            try {
                              final file = File(boundaryImageUrl);
              if (await file.exists()) {
                final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
                final bytes = await file.readAsBytes();
                
                await _client.storage
                    .from('images')
                    .uploadBinary(fileName, bytes);
                
                boundaryImageUrl = _client.storage
                    .from('images')
                    .getPublicUrl(fileName);
                
                print('Boundary NFT image uploaded successfully: $boundaryImageUrl');
                print('Final boundary image URL stored in database: $boundaryImageUrl');
              }
            } catch (uploadError) {
              print('Failed to upload boundary NFT image: $uploadError');
              print('Full upload error details: ${uploadError.toString()}');
              // Continue without image if upload fails
            }
          } else {
            print('Boundary image URL is not a local file: $boundaryImageUrl');
          }
          
          final boundaryData = {
            'id': boundary.id,
            'name': boundary.name,
            'description': boundary.description,
            'image_url': boundaryImageUrl,
            'latitude': boundary.latitude,
            'longitude': boundary.longitude,
            'radius': boundary.radius,
            'is_claimed': false, // Explicitly set to false for new boundaries
            'claimed_by': null, // Explicitly set to null
            'claimed_at': null, // Explicitly set to null
            'event_id': createdEvent.id,
            'nft_token_id': boundary.nftTokenId,
            'nft_metadata': boundary.nftMetadata,
            'claim_progress': 0.0, // Start with 0 progress
            'is_visible': true, // Start as visible
            'ar_position': {
              'x': boundary.position.x,
              'y': boundary.position.y,
              'z': boundary.position.z,
            },
            'ar_rotation': {
              'x': boundary.rotation.x,
              'y': boundary.rotation.y,
              'z': boundary.rotation.z,
            },
            'ar_scale': {
              'x': boundary.scale.x,
              'y': boundary.scale.y,
              'z': boundary.scale.z,
            },
          };
          await _client.from('boundaries').insert(boundaryData);
        }
      }
      
      print('Event created successfully: ${createdEvent.id}');
      return createdEvent;
    } catch (e) {
      print('Error creating event: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: ${e.toString()}');
      
      if (e.toString().contains('relation "events" does not exist')) {
        throw Exception('Database tables not created. Please run the SQL setup in Supabase.');
      }
      
      if (e.toString().contains('permission denied')) {
        throw Exception('Permission denied. Please check your Supabase configuration and ensure RLS is properly disabled.');
      }
      
      if (e.toString().contains('Unauthorized')) {
        throw Exception('Unauthorized access. Please check your Supabase API keys and configuration.');
      }
      
      rethrow;
    }
  }

  Future<void> updateEvent(Event event) async {
    try {
      await _client
          .from('events')
          .update(event.toJson())
          .eq('id', event.id);
    } catch (e) {
      print('Error updating event: $e');
      rethrow;
    }
  }

  // Boundary Operations
  Future<List<Boundary>> getEventBoundaries(String eventId) async {
    try {
      final response = await _client
          .from('boundaries')
          .select('*')
          .eq('event_id', eventId);
      
      return (response as List).map((json) => Boundary.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching boundaries: $e');
      return [];
    }
  }

  // Get claimed boundaries for a specific event (from EnhancedSupabaseService)
  Future<List<Boundary>> getClaimedBoundariesForEvent(String eventId) async {
    try {
      final response = await _client
          .from('boundaries')
          .select('*')
          .eq('event_id', eventId)
          .eq('is_claimed', true)
          .order('claimed_at', ascending: false);

      return (response as List<dynamic>)
          .map((b) => Boundary.fromJson(b as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting claimed boundaries: $e');
      return [];
    }
  }

  Future<Boundary> createBoundary(Boundary boundary) async {
    try {
      final response = await _client
          .from('boundaries')
          .insert(boundary.toJson())
          .select()
          .single();
      
      return Boundary.fromJson(response);
    } catch (e) {
      print('Error creating boundary: $e');
      rethrow;
    }
  }

  Future<void> claimBoundary(String boundaryId, String walletAddress) async {
    try {
      await _client
          .from('boundaries')
          .update({
            'is_claimed': true,
            'claimed_by': walletAddress,
            'claimed_at': DateTime.now().toIso8601String(),
            'claim_progress': 100.0,
          })
          .eq('id', boundaryId);
    } catch (e) {
      print('Error claiming boundary: $e');
      rethrow;
    }
  }

  // Enhanced boundary claiming with full database updates (from EnhancedSupabaseService)
  Future<bool> claimBoundaryWithFullUpdate({
    required String boundaryId,
    required String claimedBy,
    required double distance,
    required String claimTxHash,
    required Map<String, dynamic> nftMetadata,
  }) async {
    try {
      // First, check if boundary is already claimed
      final existingClaim = await _client
          .from('boundaries')
          .select('is_claimed, claimed_by')
          .eq('id', boundaryId)
          .single();

      if (existingClaim['is_claimed'] == true) {
        print('Boundary already claimed by: ${existingClaim['claimed_by']}');
        return false;
      }

      // Update the boundary with all claim information
      final response = await _client
          .from('boundaries')
          .update({
            'is_claimed': true,
            'claimed_by': claimedBy,
            'claimed_at': DateTime.now().toIso8601String(),
            'claim_tx_hash': claimTxHash,
            'nft_metadata': nftMetadata,
            'claim_progress': 100.0, // Mark as fully claimed
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', boundaryId)
          .eq('is_claimed', false); // Only update if still unclaimed

      print('Claim update response: $response');
      return true;
    } catch (e) {
      print('Error claiming boundary: $e');
      return false;
    }
  }

  // Check if user can claim boundary (distance and availability check) (from EnhancedSupabaseService)
  Future<Map<String, dynamic>> checkBoundaryClaimability({
    required String boundaryId,
    required String walletAddress,
    required double userLatitude,
    required double userLongitude,
  }) async {
    try {
      final boundary = await _client
          .from('boundaries')
          .select('*')
          .eq('id', boundaryId)
          .single();

      if (boundary == null) {
        return {'canClaim': false, 'reason': 'Boundary not found'};
      }

      if (boundary['is_claimed'] == true) {
        return {
          'canClaim': false, 
          'reason': 'Already claimed by ${boundary['claimed_by']}'
        };
      }

      // Calculate distance
      final boundaryLat = boundary['latitude'] as double;
      final boundaryLng = boundary['longitude'] as double;
      final radius = boundary['radius'] as double? ?? 2.0;
      
      final distance = _calculateDistance(
        userLatitude, userLongitude,
        boundaryLat, boundaryLng,
      );

      if (distance > radius) {
        return {
          'canClaim': false,
          'reason': 'Too far from boundary',
          'distance': distance,
          'requiredDistance': radius,
        };
      }

      return {
        'canClaim': true,
        'distance': distance,
        'boundary': Boundary.fromJson(boundary),
      };
    } catch (e) {
      print('Error checking boundary claimability: $e');
      return {'canClaim': false, 'reason': 'Error checking boundary'};
    }
  }

  // Calculate distance between two coordinates in meters (from EnhancedSupabaseService)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = 
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // New method to get nearby boundaries with progress
  Future<List<Map<String, dynamic>>> getNearbyBoundaries(
    double userLat, 
    double userLon, 
    String userWallet,
    {double maxDistance = 1000.0}
  ) async {
    try {
      final response = await _client
          .rpc('get_nearby_boundaries', params: {
            'user_lat': userLat,
            'user_lon': userLon,
            'user_wallet': userWallet,
            'max_distance': maxDistance,
          });
      
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching nearby boundaries: $e');
      return [];
    }
  }

  // New method to update boundary visibility
  Future<void> updateBoundaryVisibility(
    double userLat, 
    double userLon, 
    String userWallet
  ) async {
    try {
      await _client
          .rpc('update_boundary_visibility', params: {
            'user_lat': userLat,
            'user_lon': userLon,
            'user_wallet': userWallet,
          });
    } catch (e) {
      print('Error updating boundary visibility: $e');
    }
  }

  // User Operations - Simplified (no Supabase integration for users)
  // We're not storing user data in Supabase, only events and boundaries

  // Enhanced user's claimed boundaries across all events (from EnhancedSupabaseService)
  Future<List<Boundary>> getUserClaimedBoundaries(String walletAddress) async {
    try {
      print('=== GETTING USER CLAIMED BOUNDARIES ===');
      print('Wallet address: $walletAddress');
      
      // Get claimed boundaries first
      final boundariesResponse = await _client
          .from('boundaries')
          .select('*')
          .eq('claimed_by', walletAddress)
          .order('claimed_at', ascending: false);

      print('Found ${boundariesResponse.length} claimed boundaries');
      
      final boundaries = <Boundary>[];
      
      for (final boundaryData in boundariesResponse) {
        try {
          // Get event information for this boundary
          final eventResponse = await _client
              .from('events')
              .select('name, event_code, venue_name')
              .eq('id', boundaryData['event_id'])
              .maybeSingle();
          
          if (eventResponse != null) {
            // Add event info to boundary data
            boundaryData['event_name'] = eventResponse['name'];
            boundaryData['event_code'] = eventResponse['event_code'];
            boundaryData['venue_name'] = eventResponse['venue_name'];
          }
          
          final boundary = Boundary.fromJson(boundaryData);
          boundaries.add(boundary);
        } catch (e) {
          print('Error processing boundary ${boundaryData['id']}: $e');
          // Continue with other boundaries
        }
      }
      
      print('Successfully processed ${boundaries.length} boundaries');
      return boundaries;
    } catch (e) {
      print('Error getting user claimed boundaries: $e');
      return [];
    }
  }

  // Get event statistics
  Future<Map<String, dynamic>?> getEventStatistics(String eventId) async {
    try {
      final response = await _client
          .from('event_statistics')
          .select('*')
          .eq('event_id', eventId)
          .single();
      
      return response;
    } catch (e) {
      print('Error fetching event statistics: $e');
      return null;
    }
  }

  // Log user proximity for analytics
  Future<void> logUserProximity({
    required String userWalletAddress,
    required String boundaryId,
    required String eventId,
    required double distanceMeters,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _client
          .from('user_proximity_logs')
          .insert({
            'user_wallet_address': userWalletAddress,
            'boundary_id': boundaryId,
            'event_id': eventId,
            'distance_meters': distanceMeters,
            'latitude': latitude,
            'longitude': longitude,
          });
    } catch (e) {
      print('Error logging user proximity: $e');
    }
  }

  // Goodie Operations
  Future<List<Goodie>> getEventGoodies(String eventId) async {
    try {
      final response = await _client
          .from('goodies')
          .select('*')
          .eq('event_id', eventId);
      
      return (response as List).map((json) => Goodie.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching goodies: $e');
      return [];
    }
  }

  Future<Goodie> createGoodie(Goodie goodie) async {
    try {
      final response = await _client
          .from('goodies')
          .insert(goodie.toJson())
          .select()
          .single();
      
      return Goodie.fromJson(response);
    } catch (e) {
      print('Error creating goodie: $e');
      rethrow;
    }
  }

  Future<void> claimGoodie(String goodieId, String walletAddress) async {
    try {
      await _client
          .from('goodies')
          .update({
            'is_claimed': true,
            'claimed_by': walletAddress,
            'claimed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', goodieId);
    } catch (e) {
      print('Error claiming goodie: $e');
      rethrow;
    }
  }

  // File Upload
  Future<String> uploadImage(String filePath, String fileName) async {
    try {
      final file = File(filePath);
      await _client.storage
          .from('images')
          .upload(fileName, file);
      
      return _client.storage
          .from('images')
          .getPublicUrl(fileName);
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  // User Boundary Claims
  Future<List<Map<String, dynamic>>> getUserClaims(String walletAddress) async {
    try {
      // First try RPC function
      try {
        final response = await _client
            .rpc('get_user_claims', params: {'user_wallet': walletAddress});
        
        return (response as List).cast<Map<String, dynamic>>();
      } catch (rpcError) {
        print('RPC function failed, using direct query: $rpcError');
        
        // Fallback: direct database query with event information
        final boundariesResponse = await _client
            .from('boundaries')
            .select('''
              id,
              name,
              description,
              image_url,
              latitude,
              longitude,
              event_id,
              claimed_at,
              claim_progress
            ''')
            .eq('claimed_by', walletAddress)
            .eq('is_claimed', true)
            .order('claimed_at', ascending: false);
        
        final claims = <Map<String, dynamic>>[];
        
        for (final boundaryData in boundariesResponse) {
          try {
            // Get event information for this boundary
            final eventResponse = await _client
                .from('events')
                .select('name, event_code, venue_name, start_date, end_date')
                .eq('id', boundaryData['event_id'])
                .maybeSingle();
            
            if (eventResponse != null) {
              claims.add({
                'boundary_id': boundaryData['id'],
                'boundary_name': boundaryData['name'],
                'boundary_description': boundaryData['description'],
                'image_url': boundaryData['image_url'],
                'latitude': boundaryData['latitude'],
                'longitude': boundaryData['longitude'],
                'event_id': boundaryData['event_id'],
                'event_name': eventResponse['name'] ?? 'Unknown Event',
                'event_code': eventResponse['event_code'] ?? 'UNKNOWN',
                'venue_name': eventResponse['venue_name'] ?? 'Unknown Venue',
                'start_date': eventResponse['start_date'],
                'end_date': eventResponse['end_date'],
                'claimed_at': boundaryData['claimed_at'],
                'claim_distance': boundaryData['claim_progress'] ?? 0.0,
              });
            }
          } catch (e) {
            print('Error processing boundary ${boundaryData['id']}: $e');
            // Continue with other boundaries
          }
        }
        
        return claims;
      }
    } catch (e) {
      print('Error fetching user claims: $e');
      return [];
    }
  }

  // Test method to verify database connectivity and permissions
  Future<bool> testDatabaseConnection() async {
    try {
      print('Testing database connection...');
      
      // Try to read events first
      final eventsResponse = await _client
          .from('events')
          .select('id, name, event_code')
          .limit(5);
      
      print('Events test read successful: ${eventsResponse.length} records');
      if (eventsResponse.isNotEmpty) {
        print('Sample events:');
        for (final event in eventsResponse) {
          print('  - ${event['name']} (Code: ${event['event_code']})');
        }
      }
      
      // Try to read boundaries
      final boundariesResponse = await _client
          .from('boundaries')
          .select('id, name, event_id')
          .limit(3);
      
      print('Boundaries test read successful: ${boundariesResponse.length} records');
      if (boundariesResponse.isNotEmpty) {
        print('Sample boundaries:');
        for (final boundary in boundariesResponse) {
          print('  - ${boundary['name']} (Event ID: ${boundary['event_id']})');
        }
      }
      
      // Try to update a test field (should fail if no permissions)
      try {
        final testUpdate = await _client
            .from('boundaries')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', 'test-id')
            .select('id');
        
        print('Test update response: $testUpdate');
        return true;
      } catch (updateError) {
        print('Test update failed (expected): $updateError');
        return true; // Read works, update might have permission issues
      }
      
    } catch (e) {
      print('Database connection test failed: $e');
      return false;
    }
  }

  // Test method to check if an event code exists
  Future<bool> testEventCodeExists(String eventCode) async {
    try {
      print('=== TESTING EVENT CODE EXISTENCE ===');
      print('Testing if event code exists: $eventCode');
      
      final response = await _client
          .from('events')
          .select('id, name, event_code')
          .eq('event_code', eventCode)
          .maybeSingle();
      
      if (response != null) {
        print('✅ Event code $eventCode EXISTS in database');
        print('  Event: ${response['name']}');
        print('  ID: ${response['id']}');
        return true;
      } else {
        print('❌ Event code $eventCode NOT FOUND in database');
        return false;
      }
    } catch (e) {
      print('❌ Error testing event code existence: $e');
      return false;
    }
  }

  // Simple method to list all event codes in database
  Future<List<String>> getAllEventCodes() async {
    try {
      print('=== GETTING ALL EVENT CODES ===');
      
      final response = await _client
          .from('events')
          .select('event_code, name')
          .order('created_at', ascending: false);
      
      final eventCodes = <String>[];
      for (final event in response) {
        eventCodes.add('${event['event_code']} (${event['name']})');
      }
      
      print('Found ${eventCodes.length} event codes:');
      for (final code in eventCodes) {
        print('  - $code');
      }
      
      return eventCodes;
    } catch (e) {
      print('❌ Error getting event codes: $e');
      return [];
    }
  }

  // Test method to verify boundary claiming permissions
  Future<bool> testBoundaryClaiming(String boundaryId) async {
    try {
      print('Testing boundary claiming permissions...');
      
      // Try to read the specific boundary
      final boundaryResponse = await _client
          .from('boundaries')
          .select('*')
          .eq('id', boundaryId)
          .maybeSingle();
      
      if (boundaryResponse == null) {
        print('Boundary not found for testing');
        return false;
      }
      
      print('Boundary found: ${boundaryResponse['name']}');
      print('Current status: claimed=${boundaryResponse['is_claimed']}, by=${boundaryResponse['claimed_by']}');
      
      // Try a test update (this should work if permissions are correct)
      try {
        final testUpdate = await _client
            .from('boundaries')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', boundaryId)
            .select('id');
        
        print('Test update successful: $testUpdate');
        return true;
      } catch (updateError) {
        print('Test update failed: $updateError');
        return false;
      }
      
    } catch (e) {
      print('Boundary claiming test failed: $e');
      return false;
    }
  }

  Future<bool> claimBoundaryForUser(String boundaryId, String walletAddress, double distance) async {
    try {
      print('=== ATTEMPTING TO CLAIM BOUNDARY ===');
      print('Boundary ID: $boundaryId');
      print('Wallet Address: $walletAddress');
      print('Distance: ${distance.toStringAsFixed(2)}m');
      
      // Check if client is available
      if (_client == null) {
        print('❌ Supabase client is null');
        return false;
      }
      
      // Check authentication state
      final session = _client.auth.currentSession;
      if (session == null) {
        print('❌ No active session, attempting anonymous auth...');
        try {
          await _client.auth.signInAnonymously();
          print('✅ Anonymous authentication successful');
        } catch (authError) {
          print('❌ Anonymous authentication failed: $authError');
          return false;
        }
      }
      
      // First, verify the boundary exists and get its details
      Map<String, dynamic>? boundaryResponse;
      try {
        boundaryResponse = await _client
            .from('boundaries')
            .select('*')
            .eq('id', boundaryId)
            .maybeSingle();
      } catch (e) {
        print('❌ Error fetching boundary details: $e');
        // Try one more time after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          boundaryResponse = await _client
              .from('boundaries')
              .select('*')
              .eq('id', boundaryId)
              .maybeSingle();
        } catch (retryError) {
          print('❌ Retry also failed: $retryError');
          return false;
        }
      }
      
      if (boundaryResponse == null) {
        print('Boundary not found: $boundaryId');
        return false;
      }
      
      final boundary = boundaryResponse;
      final eventId = boundary['event_id'];
      final isAlreadyClaimed = boundary['is_claimed'] ?? false;
      final claimedBy = boundary['claimed_by'];
      final boundaryRadius = boundary['radius'] ?? 2.0;
      
      print('Boundary details:');
      print('  Event ID: $eventId');
      print('  Already claimed: $isAlreadyClaimed');
      print('  Claimed by: $claimedBy');
      print('  Radius: ${boundaryRadius}m');
      
      // Check if already claimed
      if (isAlreadyClaimed) {
        print('Boundary already claimed by: $claimedBy');
        return false;
      }
      
      // Check if user is within claiming radius
      if (distance > boundaryRadius) {
        print('User too far from boundary: ${distance}m > ${boundaryRadius}m');
        return false;
      }
      
      // Check if user has already claimed this boundary (double-check)
      final existingClaim = await _client
          .from('boundaries')
          .select('id')
          .eq('id', boundaryId)
          .eq('claimed_by', walletAddress)
          .maybeSingle();
      
      if (existingClaim != null) {
        print('User already claimed this boundary');
        return false;
      }
      
      // First try RPC function for atomic claiming
      try {
        print('Attempting RPC claim...');
        final response = await _client
            .rpc('claim_boundary', params: {
              'boundary_id': boundaryId,
              'user_wallet': walletAddress,
              'claim_distance': distance,
            });
        
        if (response == true) {
          print('RPC claim successful');
          return true;
        } else {
          print('RPC claim returned false');
          return false;
        }
      } catch (rpcError) {
        print('RPC function failed, using direct database update: $rpcError');
        
        // Fallback: direct database update with transaction-like behavior
        try {
          print('Attempting direct database update...');
          
          // First, verify the boundary still exists and is not claimed
          final verifyResponse = await _client
              .from('boundaries')
              .select('id, is_claimed, claimed_by')
              .eq('id', boundaryId)
              .maybeSingle();
          
          if (verifyResponse == null) {
            print('Boundary not found during update');
            return false;
          }
          
          final currentClaimed = verifyResponse['is_claimed'] ?? false;
          final currentClaimedBy = verifyResponse['claimed_by'];
          
          print('Current boundary status: claimed=$currentClaimed, by=$currentClaimedBy');
          
          if (currentClaimed) {
            print('Boundary was claimed by someone else during the process');
            return false;
          }
          
          // Now perform the update
          final updateResponse = await _client
              .from('boundaries')
              .update({
                'is_claimed': true,
                'claimed_by': walletAddress,
                'claimed_at': DateTime.now().toIso8601String(),
                'claim_progress': 100.0,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', boundaryId)
              .eq('is_claimed', false) // Double-check condition
              .select('id');
          
          print('Update response: $updateResponse');
          
          if (updateResponse.isEmpty) {
            print('Update failed - no rows were updated');
            return false;
          }
          
          print('Direct database update successful');
          
          // Log the claim in user_proximity_logs for tracking
          try {
            await _client
                .from('user_proximity_logs')
                .insert({
                  'user_wallet_address': walletAddress,
                  'boundary_id': boundaryId,
                  'event_id': eventId,
                  'distance_meters': distance,
                  'latitude': 0.0, // Will be filled by actual location
                  'longitude': 0.0, // Will be filled by actual location
                  'claimed_at': DateTime.now().toIso8601String(),
                });
            print('Proximity log created successfully');
          } catch (logError) {
            print('Could not log proximity: $logError');
            // This is not critical, continue
          }
          
          return true;
        } catch (updateError) {
          print('Error during direct database update: $updateError');
          
          // Try a simpler update approach as last resort
          try {
            print('Attempting simple update as fallback...');
            final simpleUpdate = await _client
                .from('boundaries')
                .update({
                  'is_claimed': true,
                  'claimed_by': walletAddress,
                  'claimed_at': DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', boundaryId);
            
            print('Simple update result: $simpleUpdate');
            
            // Verify the update worked
            final verifyUpdate = await _client
                .from('boundaries')
                .select('is_claimed, claimed_by')
                .eq('id', boundaryId)
                .maybeSingle();
            
            if (verifyUpdate != null && verifyUpdate['is_claimed'] == true) {
              print('Simple update successful');
              return true;
            } else {
              print('Simple update failed verification');
              return false;
            }
          } catch (simpleError) {
            print('Simple update also failed: $simpleError');
            return false;
          }
        }
      }
    } catch (e) {
      print('❌ Error claiming boundary: $e');
      print('Error type: ${e.runtimeType}');
      
      if (e.toString().contains('Connection closed')) {
        print('🔌 Connection issue detected - this might be a network problem');
      } else if (e.toString().contains('PGRST116')) {
        print('📊 Database query issue - no rows found where expected');
      } else if (e.toString().contains('timeout')) {
        print('⏰ Request timed out - server might be slow');
      }
      
      return false;
    }
  }

  Future<List<Boundary>> getNearbyBoundariesForUser(double lat, double lng, String eventId, {double maxDistance = 5.0}) async {
    try {
      final response = await _client
          .rpc('get_nearby_boundaries', params: {
            'user_lat': lat,
            'user_lng': lng,
            'event_id': eventId,
            'max_distance': maxDistance,
          });
      
      return (response as List).map((json) => Boundary.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching nearby boundaries: $e');
      return [];
    }
  }

  // Get boundaries by event code for proper event isolation
  Future<List<Boundary>> getBoundariesByEventCode(String eventCode) async {
    try {
      print('Fetching boundaries for event code: $eventCode');
      
      // First get the event by code
      final eventResponse = await _client
          .from('events')
          .select('id, name')
          .eq('event_code', eventCode)
          .single();
      
      if (eventResponse == null) {
        print('Event not found for code: $eventCode');
        return [];
      }
      
      final eventId = eventResponse['id'];
      final eventName = eventResponse['name'];
      
      print('Found event: $eventName (ID: $eventId)');
      
      // Get all boundaries for this event
      final boundariesResponse = await _client
          .from('boundaries')
          .select('*')
          .eq('event_id', eventId)
          .eq('is_visible', true) // Only show visible boundaries
          .order('created_at');
      
      final boundaries = (boundariesResponse as List)
          .map((json) => Boundary.fromJson(json))
          .toList();
      
      print('Found ${boundaries.length} boundaries for event $eventCode');
      
      return boundaries;
    } catch (e) {
      print('Error fetching boundaries by event code: $e');
      return [];
    }
  }

  Future<Map<String, int>> getEventStats(String eventId) async {
    try {
      final response = await _client
          .rpc('get_event_stats', params: {'event_id': eventId});
      
      if (response is List && response.isNotEmpty) {
        final stats = response.first as Map<String, dynamic>;
        return {
          'total_boundaries': stats['total_boundaries'] ?? 0,
          'claimed_boundaries': stats['claimed_boundaries'] ?? 0,
          'unique_claimers': stats['unique_claimers'] ?? 0,
        };
      }
      return {'total_boundaries': 0, 'claimed_boundaries': 0, 'unique_claimers': 0};
    } catch (e) {
      print('Error fetching event stats: $e');
      return {'total_boundaries': 0, 'claimed_boundaries': 0, 'unique_claimers': 0};
    }
  }

  Future<List<Boundary>> getUserEventClaims(String walletAddress, String eventId) async {
    try {
      // Since user_boundary_claims table doesn't exist, query boundaries directly
      final response = await _client
          .from('boundaries')
          .select('*')
          .eq('claimed_by', walletAddress)
          .eq('event_id', eventId)
          .eq('is_claimed', true);
      
      return (response as List).map((json) => Boundary.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching user event claims: $e');
      return [];
    }
  }

  // Debug method to reset all boundaries for an event (for testing) (from EnhancedSupabaseService)
  Future<void> resetEventBoundaries(String eventId) async {
    try {
      await _client
          .from('boundaries')
          .update({
            'is_claimed': false,
            'claimed_by': null,
            'claimed_at': null,
            'claim_tx_hash': null,
            'nft_metadata': null,
            'claim_progress': 0.0,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('event_id', eventId);
      
      print('Successfully reset boundaries for event: $eventId');
    } catch (e) {
      print('Error resetting boundaries: $e');
      throw e;
    }
  }

  // Check boundary status for debugging (from EnhancedSupabaseService)
  Future<List<Map<String, dynamic>>> getBoundaryStatus(String eventId) async {
    try {
      final response = await _client
          .from('boundaries')
          .select('id, name, is_claimed, claimed_by, claimed_at')
          .eq('event_id', eventId)
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting boundary status: $e');
      return [];
    }
  }

  // Fix incorrectly claimed boundaries (for debugging) (from EnhancedSupabaseService)
  Future<void> fixIncorrectlyClaimedBoundaries(String eventId) async {
    try {
      // Reset boundaries that might have been incorrectly claimed
      await _client
          .from('boundaries')
          .update({
            'is_claimed': false,
            'claimed_by': null,
            'claimed_at': null,
            'claim_tx_hash': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('event_id', eventId)
          .or('claim_tx_hash.is.null,claim_tx_hash.eq.null'); // Only reset those without valid tx hash
      
      print('Fixed incorrectly claimed boundaries for event: $eventId');
    } catch (e) {
      print('Error fixing boundaries: $e');
      throw e;
    }
  }

  // Get claimed boundaries grouped by event for better organization
  Future<Map<String, List<Map<String, dynamic>>>> getClaimedBoundariesByEvent(String walletAddress) async {
    try {
      final allClaims = await getUserClaims(walletAddress);
      
      // Group by event_code
      final Map<String, List<Map<String, dynamic>>> groupedClaims = {};
      
      for (final claim in allClaims) {
        final eventCode = claim['event_code'] ?? 'UNKNOWN';
        if (!groupedClaims.containsKey(eventCode)) {
          groupedClaims[eventCode] = [];
        }
        groupedClaims[eventCode]!.add(claim);
      }
      
      return groupedClaims;
    } catch (e) {
      print('Error grouping claimed boundaries by event: $e');
      return {};
    }
  }

  // Real-time subscription to boundary changes for an event (from EnhancedSupabaseService)
  Stream<List<Boundary>> subscribeToBoundaryChanges(String eventId) {
    return _client
        .from('boundaries')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .map((data) => data
            .map((item) => Boundary.fromJson(item))
            .toList());
  }

  // Batch update boundaries (for admin purposes) (from EnhancedSupabaseService)
  Future<bool> batchUpdateBoundaries(List<Map<String, dynamic>> updates) async {
    try {
      for (final update in updates) {
        await _client
            .from('boundaries')
            .update(update)
            .eq('id', update['id']);
      }
      return true;
    } catch (e) {
      print('Error batch updating boundaries: $e');
      return false;
    }
  }

  // Get boundary claim history for analytics (from EnhancedSupabaseService)
  Future<List<Map<String, dynamic>>> getBoundaryClaimHistory(String eventId) async {
    try {
      final response = await _client
          .from('boundaries')
          .select('name, claimed_by, claimed_at, claim_tx_hash')
          .eq('event_id', eventId)
          .eq('is_claimed', true)
          .order('claimed_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting claim history: $e');
      return [];
    }
  }

  // User Management Methods
  Future<Map<String, dynamic>?> getUserByWalletAddress(String walletAddress) async {
    try {
      print('SupabaseService: Getting user by wallet address: $walletAddress');
      final response = await _client
          .from('users')
          .select()
          .eq('wallet_address', walletAddress)
          .single();
      
      print('SupabaseService: User found: ${response != null ? 'Yes' : 'No'}');
      return response;
    } catch (e) {
      print('SupabaseService: Error getting user by wallet address: $e');
      print('SupabaseService: Error details: ${e.toString()}');
      return null;
    }
  }

  Future<bool> createUser(Map<String, dynamic> userData) async {
    try {
      print('SupabaseService: Creating user with data: $userData');
      final response = await _client.from('users').insert(userData);
      print('SupabaseService: Create user response: $response');
      return true;
    } catch (e) {
      print('SupabaseService: Error creating user: $e');
      print('SupabaseService: Error details: ${e.toString()}');
      return false;
    }
  }

  Future<bool> updateUserLastLogin(String walletAddress) async {
    try {
      print('SupabaseService: Updating last login for wallet: $walletAddress');
      final response = await _client
          .from('users')
          .update({'last_login': DateTime.now().toIso8601String()})
          .eq('wallet_address', walletAddress);
      print('SupabaseService: Update last login response: $response');
      return true;
    } catch (e) {
      print('SupabaseService: Error updating user last login: $e');
      print('SupabaseService: Error details: ${e.toString()}');
      return false;
    }
  }

  Future<bool> updateUserStats(String walletAddress, Map<String, dynamic> stats) async {
    try {
      await _client
          .from('users')
          .update({'stats': stats})
          .eq('wallet_address', walletAddress);
      return true;
    } catch (e) {
      print('Error updating user stats: $e');
      return false;
    }
  }
}