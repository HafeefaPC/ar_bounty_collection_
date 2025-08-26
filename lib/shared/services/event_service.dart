import 'package:face_reflector/shared/models/event.dart';
import 'package:face_reflector/shared/models/goodie.dart';

class EventService {
  // In-memory storage for demo purposes
  // In a real app, this would use Supabase or Firebase
  static final Map<String, Event> _events = {};
  static final Map<String, List<Goodie>> _eventGoodies = {};

  Future<Event> createEvent({
    required String name,
    required String description,
    required String organizerWalletAddress,
    required double latitude,
    required double longitude,
    required String venueName,
    List<Goodie>? goodies,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final event = Event(
      name: name,
      description: description,
      organizerWalletAddress: organizerWalletAddress,
      latitude: latitude,
      longitude: longitude,
      venueName: venueName,
      goodies: goodies ?? [],
      startDate: startDate,
      endDate: endDate,
    );

    _events[event.id] = event;
    _eventGoodies[event.id] = event.goodies;

    return event;
  }

  Future<Event?> getEventByCode(String eventCode) async {
    try {
      final event = _events.values.firstWhere(
        (event) => event.eventCode == eventCode,
      );
      return event;
    } catch (e) {
      return null;
    }
  }

  Future<Event?> getEventById(String eventId) async {
    return _events[eventId];
  }

  Future<List<Goodie>> getEventGoodies(String eventId) async {
    return _eventGoodies[eventId] ?? [];
  }

  Future<void> addGoodieToEvent(String eventId, Goodie goodie) async {
    final event = _events[eventId];
    if (event != null) {
      final updatedEvent = event.copyWith(
        goodies: [...event.goodies, goodie],
      );
      _events[eventId] = updatedEvent;
      _eventGoodies[eventId] = updatedEvent.goodies;
    }
  }

  Future<void> updateGoodie(String eventId, Goodie goodie) async {
    final event = _events[eventId];
    if (event != null) {
      final updatedGoodies = event.goodies.map((g) {
        return g.id == goodie.id ? goodie : g;
      }).toList();
      
      final updatedEvent = event.copyWith(goodies: updatedGoodies);
      _events[eventId] = updatedEvent;
      _eventGoodies[eventId] = updatedGoodies;
    }
  }

  Future<List<Event>> getEventsByOrganizer(String walletAddress) async {
    return _events.values
        .where((event) => event.organizerWalletAddress == walletAddress)
        .toList();
  }

  Future<void> deleteEvent(String eventId) async {
    _events.remove(eventId);
    _eventGoodies.remove(eventId);
  }

  // Demo data for testing
  static void initializeDemoData() {
    final demoEvent = Event(
      id: 'demo-event-1',
      name: 'Tech Conference 2024',
      description: 'Annual technology conference with amazing goodies',
      organizerWalletAddress: '0x1234567890abcdef',
      latitude: 37.7749,
      longitude: -122.4194,
      venueName: 'San Francisco Convention Center',
      eventCode: 'TECH24',
      goodies: [
        Goodie(
          id: 'goodie-1',
          name: 'Conference T-Shirt',
          description: 'Limited edition conference t-shirt',
          logoUrl: 'https://via.placeholder.com/150/6366F1/FFFFFF?text=T-Shirt',
          latitude: 37.7749,
          longitude: -122.4194,
          eventId: 'demo-event-1',
        ),
        Goodie(
          id: 'goodie-2',
          name: 'Sticker Pack',
          description: 'Cool tech stickers',
          logoUrl: 'https://via.placeholder.com/150/8B5CF6/FFFFFF?text=Stickers',
          latitude: 37.7750,
          longitude: -122.4195,
          eventId: 'demo-event-1',
        ),
        Goodie(
          id: 'goodie-3',
          name: 'Coffee Voucher',
          description: 'Free coffee at the venue',
          logoUrl: 'https://via.placeholder.com/150/06B6D4/FFFFFF?text=Coffee',
          latitude: 37.7748,
          longitude: -122.4193,
          eventId: 'demo-event-1',
        ),
      ],
    );

    _events[demoEvent.id] = demoEvent;
    _eventGoodies[demoEvent.id] = demoEvent.goodies;
  }
}

