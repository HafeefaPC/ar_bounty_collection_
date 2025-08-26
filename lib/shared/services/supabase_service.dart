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
      // Check if Supabase is initialized
      if (_client == null) {
        throw Exception('Supabase client not initialized');
      }
      
      // Test connection first
      await _client.from('events').select('count').limit(1);
      
      // Try to create event with retry logic for duplicate event codes
      Event? createdEvent;
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          // Create event data without boundaries and goodies
          final eventData = {
            'id': event.id,
            'name': event.name,
            'description': event.description ?? '',
            'organizer_wallet_address': event.organizerWalletAddress,
            'created_at': event.createdAt.toIso8601String(),
            'start_date': event.startDate?.toIso8601String(),
            'end_date': event.endDate?.toIso8601String(),
            'latitude': event.latitude,
            'longitude': event.longitude,
            'venue_name': event.venueName,
            'event_code': event.eventCode,
          };
          
          final response = await _client
              .from('events')
              .insert(eventData)
              .select()
              .single();
          
          createdEvent = Event.fromJson(response);
          break; // Success, exit the retry loop
          
        } catch (e) {
          // Check if it's a duplicate event code error
          if (e.toString().contains('duplicate key value violates unique constraint') && 
              e.toString().contains('events_event_code_key')) {
            retryCount++;
            if (retryCount >= maxRetries) {
              throw Exception('Failed to generate unique event code after $maxRetries attempts. Please try again.');
            }
            
            // Generate a new event code and try again
            final newEventCode = _generateUniqueEventCode();
            event = event.copyWith(eventCode: newEventCode);
            print('Retrying with new event code: $newEventCode (attempt $retryCount)');
            continue;
          } else {
            // It's not a duplicate event code error, rethrow
            rethrow;
          }
        }
      }
      
      // Now create boundaries separately
      if (createdEvent != null) {
        for (var boundary in event.boundaries) {
          final boundaryData = {
            'id': boundary.id,
            'name': boundary.name,
            'description': boundary.description ?? '',
            'image_url': boundary.imageUrl,
            'latitude': boundary.latitude,
            'longitude': boundary.longitude,
            'radius': boundary.radius,
            'event_id': createdEvent.id,
            'position': {
              'x': boundary.position.x,
              'y': boundary.position.y,
              'z': boundary.position.z,
            },
            'rotation': {
              'x': boundary.rotation.x,
              'y': boundary.rotation.y,
              'z': boundary.rotation.z,
            },
            'scale': {
              'x': boundary.scale.x,
              'y': boundary.scale.y,
              'z': boundary.scale.z,
            },
          };
          await _client.from('boundaries').insert(boundaryData);
        }
        
        return createdEvent;
      } else {
        throw Exception('Failed to create event after retries');
      }
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
          })
          .eq('id', boundaryId);
    } catch (e) {
      print('Error claiming boundary: $e');
      rethrow;
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
