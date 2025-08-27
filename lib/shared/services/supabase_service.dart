import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';
import '../models/boundary.dart';
import '../models/goodie.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late final SupabaseClient _client;

  Future<void> initialize() async {
    try {
      // Check if already initialized
      if (Supabase.instance.client != null) {
        _client = Supabase.instance.client;
        print('Supabase already initialized, using existing client');
        return;
      }
      
      await Supabase.initialize(
        url: 'https://kkzgqrjgjcusmdivvbmj.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtremdxcmpnamN1c21kaXZ2Ym1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYxMjg1NzEsImV4cCI6MjA3MTcwNDU3MX0.g82dcf0a2dS0aFEMigp_cpPZlDwRbmOKtuGoXuf0dEA',
      );
      _client = Supabase.instance.client;
      print('Supabase initialized successfully');
    } catch (e) {
      print('Error initializing Supabase: $e');
      rethrow;
    }
  }

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
            'event_id': createdEvent.id,
            'nft_token_id': boundary.nftTokenId,
            'nft_metadata': boundary.nftMetadata,
            'claim_progress': boundary.claimProgress,
            'last_notification_distance': boundary.lastNotificationDistance,
            'is_visible': boundary.isVisible,
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

  // Helper method to generate unique event codes
  String _generateUniqueEventCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch + 
                   (DateTime.now().microsecondsSinceEpoch % 1000) +
                   (DateTime.now().microsecond % 1000);
    return String.fromCharCodes(
      Iterable.generate(6, (index) {
        final seed = random + index * 1000;
        return chars.codeUnitAt(seed % chars.length);
      })
    );
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
}
