import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/services/ar_service.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/services/wallet_service.dart';
import '../../shared/services/event_service.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/models/event.dart';
import '../../shared/models/user.dart';
import '../../shared/models/boundary.dart';
import '../../shared/models/goodie.dart';

// Service Providers
final arServiceProvider = Provider<ARService>((ref) {
  return ARService();
});

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final walletServiceProvider = Provider<WalletService>((ref) {
  return WalletService();
});

final eventServiceProvider = Provider<EventService>((ref) {
  return EventService();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// State Notifiers
class CurrentEventNotifier extends StateNotifier<Event?> {
  CurrentEventNotifier() : super(null);

  void setEvent(Event event) {
    state = event;
  }

  void clearEvent() {
    state = null;
  }
}

class CurrentUserNotifier extends StateNotifier<User?> {
  CurrentUserNotifier() : super(null);

  void setUser(User user) {
    state = user;
  }

  void clearUser() {
    state = null;
  }
}

class ClaimedBoundariesNotifier extends StateNotifier<List<Boundary>> {
  ClaimedBoundariesNotifier() : super([]);

  void addClaimedBoundary(Boundary boundary) {
    state = [...state, boundary];
  }

  void removeClaimedBoundary(String boundaryId) {
    state = state.where((b) => b.id != boundaryId).toList();
  }

  void clearClaimedBoundaries() {
    state = [];
  }
}

class ClaimedGoodiesNotifier extends StateNotifier<List<Goodie>> {
  ClaimedGoodiesNotifier() : super([]);

  void addClaimedGoodie(Goodie goodie) {
    state = [...state, goodie];
  }

  void removeClaimedGoodie(String goodieId) {
    state = state.where((g) => g.id != goodieId).toList();
  }

  void clearClaimedGoodies() {
    state = [];
  }
}

// State Providers
final currentEventProvider = StateNotifierProvider<CurrentEventNotifier, Event?>((ref) {
  return CurrentEventNotifier();
});

final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, User?>((ref) {
  return CurrentUserNotifier();
});

final claimedBoundariesProvider = StateNotifierProvider<ClaimedBoundariesNotifier, List<Boundary>>((ref) {
  return ClaimedBoundariesNotifier();
});

final claimedGoodiesProvider = StateNotifierProvider<ClaimedGoodiesNotifier, List<Goodie>>((ref) {
  return ClaimedGoodiesNotifier();
});

// Async Providers
final eventsProvider = FutureProvider<List<Event>>((ref) async {
  final supabaseService = ref.read(supabaseServiceProvider);
  return await supabaseService.getEvents();
});

final eventByCodeProvider = FutureProvider.family<Event?, String>((ref, eventCode) async {
  final supabaseService = ref.read(supabaseServiceProvider);
  return await supabaseService.getEventByCode(eventCode);
});

final eventBoundariesProvider = FutureProvider.family<List<Boundary>, String>((ref, eventId) async {
  final supabaseService = ref.read(supabaseServiceProvider);
  return await supabaseService.getEventBoundaries(eventId);
});

final eventGoodiesProvider = FutureProvider.family<List<Goodie>, String>((ref, eventId) async {
  final supabaseService = ref.read(supabaseServiceProvider);
  return await supabaseService.getEventGoodies(eventId);
});

// Removed userByWalletProvider since we're not storing users in Supabase

final userClaimedBoundariesProvider = FutureProvider.family<List<Boundary>, String>((ref, walletAddress) async {
  final supabaseService = ref.read(supabaseServiceProvider);
  return await supabaseService.getUserClaimedBoundaries(walletAddress);
});

// Initialize providers
void initializeProviders() {
  // Initialize services
  final walletService = WalletService();
  
  // Initialize Wallet Service
  walletService.checkWalletConnection();
}
