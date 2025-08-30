import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/services/wallet_service.dart';

class BoundaryHistoryScreen extends ConsumerStatefulWidget {
  const BoundaryHistoryScreen({super.key});

  @override
  ConsumerState<BoundaryHistoryScreen> createState() => _BoundaryHistoryScreenState();
}

class _BoundaryHistoryScreenState extends ConsumerState<BoundaryHistoryScreen> {
  List<Map<String, dynamic>> userClaims = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadUserClaims();
  }

  Future<void> _loadUserClaims() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final walletService = WalletService();
      final walletAddress = walletService.connectedWalletAddress ?? 'demo_wallet';
      
      final supabaseService = SupabaseService();
      // Try to get claims using RPC function first, fallback to direct query
      List<Map<String, dynamic>> claims = [];
      try {
        claims = await supabaseService.getUserClaims(walletAddress);
      } catch (e) {
        print('RPC function failed, using fallback method: $e');
        // Fallback: get claimed boundaries directly
        final claimedBoundaries = await supabaseService.getUserClaimedBoundaries(walletAddress);
        claims = claimedBoundaries.map((boundary) => {
          'boundary_id': boundary.id,
          'boundary_name': boundary.name,
          'event_id': boundary.eventId,
          'event_name': 'Unknown Event',
          'event_code': 'UNKNOWN',
          'claimed_at': boundary.claimedAt?.toIso8601String(),
          'claim_distance': 0.0,
        }).toList();
      }
      
      setState(() {
        userClaims = claims;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'My Boundary Collection',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/wallet/options'),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.1),
              AppTheme.secondaryColor.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Header Stats
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.celebration,
                        size: 48,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${userClaims.length}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Text(
                        'Boundaries Collected',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Claims List
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          ),
                        )
                      : error != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: Colors.red[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Error loading claims',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    error!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadUserClaims,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : userClaims.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.explore,
                                        size: 64,
                                        color: Colors.white.withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No boundaries claimed yet',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Join events and claim boundaries to see them here',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withValues(alpha: 0.7),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () => context.go('/event-join'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryColor,
                                        ),
                                        child: const Text('Join an Event'),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: userClaims.length,
                                  itemBuilder: (context, index) {
                                    final claim = userClaims[index];
                                    return _buildClaimCard(claim);
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> claim) {
    final boundaryName = claim['boundary_name'] ?? 'Unknown Boundary';
    final eventName = claim['event_name'] ?? 'Unknown Event';
    final eventCode = claim['event_code'] ?? 'UNKNOWN';
    final venueName = claim['venue_name'] ?? 'Unknown Venue';
    final claimedAt = claim['claimed_at'] != null 
        ? DateTime.parse(claim['claimed_at'])
        : null;
    final startDate = claim['start_date'] != null 
        ? DateTime.parse(claim['start_date'])
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Icon(
            Icons.check_circle,
            color: AppTheme.primaryColor,
            size: 30,
          ),
        ),
        title: Text(
          boundaryName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              eventName,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Event Code: $eventCode',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            if (venueName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Venue: $venueName',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
            if (startDate != null) ...[
              const SizedBox(height: 2),
              Text(
                'Event: ${startDate.toString().substring(0, 10)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
            if (claimedAt != null) ...[
              const SizedBox(height: 2),
              Text(
                'Claimed: ${claimedAt.toString().substring(0, 16)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],

          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.white.withValues(alpha: 0.5),
          size: 16,
        ),
        onTap: () {
          // Could show detailed view of the claim
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Claimed $boundaryName from $eventName'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        },
      ),
    );
  }
}
