import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';
import '../models/boundary.dart';
import '../models/goodie.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  
  // Public getter for external services that need direct client access
  SupabaseClient get client => _client;

  // Test Supabase connection
  Future<bool> testConnection() async {
    try {
      await _client.from('events').select('count').limit(1);
      return true;
    } catch (e) {
      print('Supabase connection test failed: $e');
      return false;
    }
  }

  // Event Operations
  Future<List<Event>> getEvents() async {
    try {
      final response = await _client
          .from('events')
          .select('*, goodies(*), boundaries(*)')
          .order('created_at', ascending: false);
      
      return (response as List).map((json) => Event.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching events: $e');
      return [];
    }
  }

  Future<Event?> getEventByCode(String eventCode) async {
    try {
      final response = await _client
          .from('events')
          .select('*, goodies(*), boundaries(*)')
          .eq('event_code', eventCode)
          .single();
      
      return Event.fromJson(response);
    } catch (e) {
      print('Error fetching event by code: $e');
      return null;
    }
  }

  Future<Event> createEvent(Event event) async {
    try {
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
        'event_image_url': event.eventImageUrl,
        'boundary_description': event.boundaryDescription,
        'notification_distances': event.notificationDistances,
        'visibility_radius': event.visibilityRadius,
      };

      final createdEventResponse = await _client
          .from('events')
          .insert(eventData)
          .select()
          .single();

      final createdEvent = Event.fromJson(createdEventResponse);
      
      // Now create boundaries separately
      if (event.boundaries.isNotEmpty) {
        for (var boundary in event.boundaries) {
          final boundaryData = {
            'id': boundary.id,
            'name': boundary.name,
            'description': boundary.description,
            'image_url': boundary.imageUrl,
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
      
      return createdEvent;
    } catch (e) {
      print('Error creating event: $e');
      if (e.toString().contains('relation "events" does not exist')) {
        throw Exception('Database tables not created. Please run the SQL setup in Supabase.');
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

  Future<List<Boundary>> getUserClaimedBoundaries(String walletAddress) async {
    try {
      final response = await _client
          .from('boundaries')
          .select('*')
          .eq('claimed_by', walletAddress);
      
      return (response as List).map((json) => Boundary.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching user claimed boundaries: $e');
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
        final response = await _client
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
              claim_progress,
              events!inner(
                name,
                event_code,
                venue_name,
                start_date,
                end_date
              )
            ''')
            .eq('claimed_by', walletAddress)
            .eq('is_claimed', true)
            .order('claimed_at', ascending: false);
        
        return (response as List).map((json) {
          final eventData = json['events'] as Map<String, dynamic>;
          return {
            'boundary_id': json['id'],
            'boundary_name': json['name'],
            'boundary_description': json['description'],
            'image_url': json['image_url'],
            'latitude': json['latitude'],
            'longitude': json['longitude'],
            'event_id': json['event_id'],
            'event_name': eventData['name'] ?? 'Unknown Event',
            'event_code': eventData['event_code'] ?? 'UNKNOWN',
            'venue_name': eventData['venue_name'] ?? 'Unknown Venue',
            'start_date': eventData['start_date'],
            'end_date': eventData['end_date'],
            'claimed_at': json['claimed_at'],
            'claim_distance': json['claim_progress'] ?? 0.0,
          };
        }).toList();
      }
    } catch (e) {
      print('Error fetching user claims: $e');
      return [];
    }
  }

  Future<bool> claimBoundaryForUser(String boundaryId, String walletAddress, double distance) async {
    try {
      // First try RPC function
      try {
        final response = await _client
            .rpc('claim_boundary', params: {
              'boundary_id': boundaryId,
              'user_wallet': walletAddress,
              'claim_distance': distance,
            });
        
        return response == true;
      } catch (rpcError) {
        print('RPC function failed, using direct database update: $rpcError');
        
        // Fallback: direct database update
        await _client
            .from('boundaries')
            .update({
              'is_claimed': true,
              'claimed_by': walletAddress,
              'claimed_at': DateTime.now().toIso8601String(),
              'claim_progress': 100.0,
            })
            .eq('id', boundaryId);
        
        // Log the claim in user_proximity_logs for tracking
        try {
          // Get event_id from the boundary
          final boundaryResponse = await _client
              .from('boundaries')
              .select('event_id')
              .eq('id', boundaryId)
              .single();
          
          final eventId = boundaryResponse['event_id'];
          
          await _client
              .from('user_proximity_logs')
              .insert({
                'user_wallet_address': walletAddress,
                'boundary_id': boundaryId,
                'event_id': eventId,
                'distance_meters': distance,
                'latitude': 0.0, // Will be filled by actual location
                'longitude': 0.0, // Will be filled by actual location
              });
        } catch (logError) {
          print('Could not log proximity: $logError');
          // This is not critical, continue
        }
        
        return true;
      }
    } catch (e) {
      print('Error claiming boundary: $e');
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

  // Debug method to reset all boundaries for an event (for testing)
  Future<void> resetEventBoundaries(String eventId) async {
    try {
      await _client
          .from('boundaries')
          .update({
            'is_claimed': false,
            'claimed_by': null,
            'claimed_at': null,
            'claim_progress': 0.0,
          })
          .eq('event_id', eventId);
      
      print('Reset all boundaries for event: $eventId');
    } catch (e) {
      print('Error resetting boundaries: $e');
    }
  }

  // Debug method to check boundary status
  Future<List<Map<String, dynamic>>> getBoundaryStatus(String eventId) async {
    try {
      final response = await _client
          .from('boundaries')
          .select('id, name, is_claimed, claimed_by, claimed_at')
          .eq('event_id', eventId);
      
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error checking boundary status: $e');
      return [];
    }
  }

  // Fix incorrectly claimed boundaries (for debugging)
  Future<void> fixIncorrectlyClaimedBoundaries(String eventId) async {
    try {
      // Find boundaries that are marked as claimed but have no claimed_by or claimed_at
      final response = await _client
          .from('boundaries')
          .select('id, name, is_claimed, claimed_by, claimed_at')
          .eq('event_id', eventId)
          .eq('is_claimed', true);
      
      for (final boundary in response) {
        if (boundary['claimed_by'] == null || boundary['claimed_at'] == null) {
          // Fix incorrectly claimed boundary
          await _client
              .from('boundaries')
              .update({
                'is_claimed': false,
                'claimed_by': null,
                'claimed_at': null,
                'claim_progress': 0.0,
              })
              .eq('id', boundary['id']);
          
          print('Fixed incorrectly claimed boundary: ${boundary['name']}');
        }
      }
      
      print('Boundary validation completed for event: $eventId');
    } catch (e) {
      print('Error fixing incorrectly claimed boundaries: $e');
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
}
