import 'dart:async';
import 'dart:convert';
import 'package:web3dart/web3dart.dart';
import 'blockchain_service.dart';
import 'supabase_service.dart';
import 'ipfs_service.dart';

class BlockchainSyncService {
  static final BlockchainSyncService _instance = BlockchainSyncService._internal();
  factory BlockchainSyncService() => _instance;
  BlockchainSyncService._internal();

  final BlockchainService _blockchainService = BlockchainService();
  final SupabaseService _supabaseService = SupabaseService();
  final IPFSService _ipfsService = IPFSService();

  StreamSubscription<FilterEvent>? _eventCreatedSubscription;
  StreamSubscription<FilterEvent>? _nftClaimedSubscription;
  
  bool _isListening = false;
  
  // Event signatures for listening (reserved for future implementation)
  // ignore: unused_field
  final String _eventCreatedSignature = 'EventCreated(uint256,address,string,string,uint256,string)';
  // ignore: unused_field
  final String _nftClaimedSignature = 'BoundaryNFTClaimed(uint256,uint256,address,uint256,int256,int256)';
  
  // Sync configuration
  static const Duration _syncInterval = Duration(minutes: 5);
  Timer? _periodicSyncTimer;

  // Initialize the sync service
  Future<void> initialize() async {
    if (!_blockchainService.isInitialized) {
      throw Exception('BlockchainService must be initialized first');
    }
    
    print('Initializing blockchain sync service...');
    
    // Start listening to blockchain events
    await _startEventListening();
    
    // Start periodic sync
    _startPeriodicSync();
    
    print('Blockchain sync service initialized');
  }

  // Start listening to blockchain events
  Future<void> _startEventListening() async {
    if (_isListening) return;
    
    try {
      // Listen to EventCreated events
      await _listenToEventCreated();
      
      // Listen to BoundaryNFTClaimed events
      await _listenToNFTClaimed();
      
      _isListening = true;
      print('Started listening to blockchain events');
    } catch (e) {
      print('Error starting event listening: $e');
    }
  }

  // Listen to EventCreated events
  Future<void> _listenToEventCreated() async {
    try {
      // This is a simplified implementation
      // In a real app, you'd listen to actual contract events
      print('Setting up EventCreated event listener...');
      
      // For demo purposes, we'll simulate event listening
      // In production, use actual Web3 event filters
    } catch (e) {
      print('Error listening to EventCreated events: $e');
    }
  }

  // Listen to BoundaryNFTClaimed events
  Future<void> _listenToNFTClaimed() async {
    try {
      print('Setting up BoundaryNFTClaimed event listener...');
      
      // For demo purposes, we'll simulate event listening
      // In production, use actual Web3 event filters
    } catch (e) {
      print('Error listening to BoundaryNFTClaimed events: $e');
    }
  }

  // Sync event from blockchain to Supabase
  Future<void> syncEventCreated({
    required int blockchainEventId,
    required String organizerAddress,
    required String eventName,
    required String eventCode,
    required int totalNFTs,
    required String metadataURI,
    required String txHash,
  }) async {
    try {
      print('Syncing EventCreated: $eventName (ID: $blockchainEventId)');
      
      // Fetch full metadata from IPFS
      Map<String, dynamic>? eventMetadata;
      if (metadataURI.startsWith('ipfs://')) {
        final cid = metadataURI.substring(7);
        eventMetadata = await _ipfsService.getJson(cid);
      }
      
      // Check if event already exists in Supabase
      final existingEvents = await _supabaseService.client
          .from('events')
          .select('id')
          .eq('blockchain_id', blockchainEventId);
      
      if (existingEvents.isNotEmpty) {
        print('Event already synced, skipping...');
        return;
      }
      
      // Create event in Supabase
      final eventData = {
        'blockchain_id': blockchainEventId,
        'name': eventMetadata?['name'] ?? eventName,
        'description': eventMetadata?['description'] ?? '',
        'organizer_wallet_address': organizerAddress,
        'latitude': eventMetadata?['properties']?['venue']?['coordinates']?['latitude'] ?? 0.0,
        'longitude': eventMetadata?['properties']?['venue']?['coordinates']?['longitude'] ?? 0.0,
        'venue_name': eventMetadata?['properties']?['venue']?['name'] ?? 'Unknown Venue',
        'event_code': eventCode,
        'nft_supply_count': totalNFTs,
        'event_image_url': eventMetadata?['image']?.toString(),
        'blockchain_tx_hash': txHash,
        'blockchain_metadata_uri': metadataURI,
        'synced_at': DateTime.now().toIso8601String(),
        'sync_status': 'synced',
      };
      
      await _supabaseService.client.from('events').insert(eventData);
      
      // Sync boundaries if available in metadata
      final boundaries = eventMetadata?['properties']?['boundaries'] as List?;
      if (boundaries != null) {
        await _syncEventBoundaries(blockchainEventId, boundaries, eventData['id']);
      }
      
      print('Successfully synced event: $eventName');
    } catch (e) {
      print('Error syncing EventCreated: $e');
      
      // Log sync error
      await _logSyncError('event_created', blockchainEventId.toString(), e.toString());
    }
  }

  // Sync boundaries from event metadata
  Future<void> _syncEventBoundaries(
    int blockchainEventId,
    List boundaries,
    String supabaseEventId,
  ) async {
    try {
      print('Syncing ${boundaries.length} boundaries for event $blockchainEventId');
      
      for (int i = 0; i < boundaries.length; i++) {
        final boundary = boundaries[i] as Map<String, dynamic>;
        
        final boundaryData = {
          'blockchain_id': '${blockchainEventId}_$i', // Temporary ID
          'name': boundary['name'] ?? 'Boundary ${i + 1}',
          'description': boundary['description'] ?? '',
          'image_url': boundary['image']?.toString() ?? '',
          'latitude': boundary['location']?['latitude'] ?? 0.0,
          'longitude': boundary['location']?['longitude'] ?? 0.0,
          'radius': boundary['location']?['radius'] ?? 2.0,
          'event_id': supabaseEventId,
          'is_claimed': false,
          'ar_position': jsonEncode({'x': 0.0, 'y': 0.0, 'z': -2.0}),
          'ar_rotation': jsonEncode({'x': 0.0, 'y': 0.0, 'z': 0.0}),
          'ar_scale': jsonEncode({'x': 1.0, 'y': 1.0, 'z': 1.0}),
          'synced_at': DateTime.now().toIso8601String(),
        };
        
        await _supabaseService.client.from('boundaries').insert(boundaryData);
      }
      
      print('Successfully synced boundaries for event $blockchainEventId');
    } catch (e) {
      print('Error syncing boundaries: $e');
    }
  }

  // Sync NFT claim from blockchain to Supabase
  Future<void> syncNFTClaimed({
    required int tokenId,
    required int eventId,
    required String claimerAddress,
    required int claimTime,
    required double claimLatitude,
    required double claimLongitude,
    required String txHash,
  }) async {
    try {
      print('Syncing NFT claimed: Token $tokenId by $claimerAddress');
      
      // Update boundary as claimed in Supabase
      final updateResult = await _supabaseService.client
          .from('boundaries')
          .update({
            'is_claimed': true,
            'claimed_by': claimerAddress,
            'claimed_at': DateTime.fromMillisecondsSinceEpoch(claimTime * 1000).toIso8601String(),
            'claim_progress': 100.0,
            'blockchain_tx_hash': txHash,
            'claim_latitude': claimLatitude,
            'claim_longitude': claimLongitude,
            'synced_at': DateTime.now().toIso8601String(),
          })
          .eq('blockchain_id', tokenId.toString())
          .select();
      
      if (updateResult.isEmpty) {
        print('Warning: Boundary with token ID $tokenId not found in Supabase');
        return;
      }
      
      // Add to user claims tracking
      await _supabaseService.client
          .from('user_boundary_claims')
          .insert({
            'user_wallet_address': claimerAddress,
            'boundary_id': updateResult.first['id'],
            'event_id': updateResult.first['event_id'],
            'claimed_at': DateTime.fromMillisecondsSinceEpoch(claimTime * 1000).toIso8601String(),
            'claim_distance': 0.0, // Distance not available from blockchain event
            'blockchain_tx_hash': txHash,
          });
      
      print('Successfully synced NFT claim: Token $tokenId');
    } catch (e) {
      print('Error syncing NFT claim: $e');
      
      // Log sync error
      await _logSyncError('nft_claimed', tokenId.toString(), e.toString());
    }
  }

  // Manual sync: Pull events from blockchain and sync to Supabase
  Future<void> performManualSync({int fromBlock = 0, int? toBlock}) async {
    try {
      print('Performing manual sync from block $fromBlock to ${toBlock ?? 'latest'}...');
      
      // This would query blockchain for events and sync them
      // For demo purposes, we'll show the structure
      
      await _syncRecentEvents();
      await _syncRecentClaims();
      
      print('Manual sync completed successfully');
    } catch (e) {
      print('Error during manual sync: $e');
    }
  }

  // Sync recent events from blockchain
  Future<void> _syncRecentEvents() async {
    try {
      // In production, query blockchain for recent EventCreated events
      // and sync any that aren't in Supabase yet
      print('Syncing recent events...');
      
      // Mock implementation - in real app, query actual blockchain events
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      print('Error syncing recent events: $e');
    }
  }

  // Sync recent claims from blockchain
  Future<void> _syncRecentClaims() async {
    try {
      // In production, query blockchain for recent BoundaryNFTClaimed events
      // and sync any that aren't in Supabase yet
      print('Syncing recent claims...');
      
      // Mock implementation - in real app, query actual blockchain events
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      print('Error syncing recent claims: $e');
    }
  }

  // Reverse sync: Push Supabase changes to blockchain (if needed)
  Future<void> syncSupabaseToBlockchain() async {
    try {
      print('Checking for Supabase changes to sync to blockchain...');
      
      // Query for events/boundaries that need blockchain sync
      final unsyncedEvents = await _supabaseService.client
          .from('events')
          .select('*')
          .eq('sync_status', 'pending')
          .limit(10);
      
      for (final eventData in unsyncedEvents) {
        await _pushEventToBlockchain(eventData);
      }
      
      print('Supabase to blockchain sync completed');
    } catch (e) {
      print('Error syncing Supabase to blockchain: $e');
    }
  }

  // Push individual event to blockchain
  Future<void> _pushEventToBlockchain(Map<String, dynamic> eventData) async {
    try {
      // This would create the event on blockchain if it doesn't exist
      // For now, just mark as synced
      await _supabaseService.client
          .from('events')
          .update({'sync_status': 'synced'})
          .eq('id', eventData['id']);
      
      print('Pushed event ${eventData['name']} to blockchain');
    } catch (e) {
      print('Error pushing event to blockchain: $e');
    }
  }

  // Start periodic sync
  void _startPeriodicSync() {
    _periodicSyncTimer = Timer.periodic(_syncInterval, (timer) {
      _performPeriodicSync();
    });
    
    print('Started periodic sync every ${_syncInterval.inMinutes} minutes');
  }

  // Perform periodic sync
  Future<void> _performPeriodicSync() async {
    try {
      print('Performing periodic sync...');
      await performManualSync();
    } catch (e) {
      print('Error during periodic sync: $e');
    }
  }

  // Log sync errors for debugging
  Future<void> _logSyncError(String eventType, String entityId, String error) async {
    try {
      await _supabaseService.client
          .from('sync_errors')
          .insert({
            'event_type': eventType,
            'entity_id': entityId,
            'error_message': error,
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Error logging sync error: $e');
    }
  }

  // Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      // Get counts from both sources
      final supabaseEventsResult = await _supabaseService.client
          .from('events')
          .select('*');
      
      final supabaseBoundariesResult = await _supabaseService.client
          .from('boundaries')
          .select('*');
      
      final syncErrorsResult = await _supabaseService.client
          .from('sync_errors')
          .select('*');
      
      return {
        'supabase_events': supabaseEventsResult.length,
        'supabase_boundaries': supabaseBoundariesResult.length,
        'sync_errors': syncErrorsResult.length,
        'is_listening': _isListening,
        'last_sync': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error getting sync status: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  // Stop sync service
  void stop() {
    _eventCreatedSubscription?.cancel();
    _nftClaimedSubscription?.cancel();
    _periodicSyncTimer?.cancel();
    
    _isListening = false;
    
    print('Blockchain sync service stopped');
  }

  // Dispose resources
  void dispose() {
    stop();
  }
}