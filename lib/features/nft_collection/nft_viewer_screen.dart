import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/nft.dart';
import '../../shared/services/nft_service.dart';
import '../../shared/providers/reown_provider.dart';
import '../../shared/widgets/tokon_logo.dart';

/// Provider for NFT collection state
final nftCollectionProvider = StateNotifierProvider<NFTCollectionNotifier, NFTCollectionState>((ref) {
  return NFTCollectionNotifier(ref);
});









/// NFT Collection State
class NFTCollectionState {
  final bool isLoading;
  final NFTCollection? collection;
  final String? error;
  final bool isRefreshing;

  const NFTCollectionState({
    this.isLoading = false,
    this.collection,
    this.error,
    this.isRefreshing = false,
  });

  NFTCollectionState copyWith({
    bool? isLoading,
    NFTCollection? collection,
    String? error,
    bool? isRefreshing,
  }) {
    return NFTCollectionState(
      isLoading: isLoading ?? this.isLoading,
      collection: collection ?? this.collection,
      error: error ?? this.error,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

/// NFT Collection Notifier
class NFTCollectionNotifier extends StateNotifier<NFTCollectionState> {
  final Ref _ref;
  final NFTService _nftService = NFTService();

  NFTCollectionNotifier(this._ref) : super(const NFTCollectionState()) {
    _initializeService();
  }

  void _initializeService() {
    final appKitModal = _ref.read(reownAppKitProvider);
    if (appKitModal != null) {
      _nftService.initialize(appKitModal);
    }
  }

  /// Load claimed NFTs for the current wallet
  Future<void> loadNFTs() async {
    final walletState = _ref.read(walletConnectionProvider);
    
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Initialize service if needed
      final appKitModal = _ref.read(reownAppKitProvider);
      if (appKitModal != null && !_nftService.isReady) {
        _nftService.initialize(appKitModal);
      }

      NFTCollection collection;
      
      if (walletState.isConnected && walletState.walletAddress != null) {
        // If wallet is connected, fetch NFTs for the specific wallet address
        collection = await _nftService.getNFTsByOwner(walletState.walletAddress!);
      } else {
        // If wallet is not connected, try to get locally stored NFTs
        // This allows offline viewing of previously claimed NFTs
        final localNFTs = await _nftService.getLocalClaimedNFTs('');
        collection = NFTCollection(
          owner: 'Local Storage',
          nfts: localNFTs,
          totalCount: localNFTs.length,
          lastUpdated: DateTime.now(),
        );
      }
      
      state = state.copyWith(
        collection: collection,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load NFTs: ${e.toString()}',
        isLoading: false,
      );
    }
  }

  /// Refresh NFTs
  Future<void> refreshNFTs() async {
    state = state.copyWith(isRefreshing: true);
    await loadNFTs();
    state = state.copyWith(isRefreshing: false);
  }
}

/// NFT Viewer Screen
class NFTViewerScreen extends ConsumerStatefulWidget {
  const NFTViewerScreen({super.key});

  @override
  ConsumerState<NFTViewerScreen> createState() => _NFTViewerScreenState();
}

class _NFTViewerScreenState extends ConsumerState<NFTViewerScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isGridView = true;
  String? _lastWalletAddress;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Load NFTs when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(nftCollectionProvider.notifier).loadNFTs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nftState = ref.watch(nftCollectionProvider);
    final walletState = ref.watch(walletConnectionProvider);

    // Check if wallet address changed and reload NFTs if needed
    final currentAddress = walletState.isConnected ? walletState.walletAddress : null;
    if (currentAddress != _lastWalletAddress) {
      _lastWalletAddress = currentAddress;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(nftCollectionProvider.notifier).loadNFTs();
      });
    }

    return Scaffold(
      body: Container(
        decoration: AppTheme.modernScaffoldBackground,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(walletState),
              
              // Tab Bar
              _buildTabBar(),
              
              // Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAllNFTsTab(nftState),
                    _buildClaimedNFTsTab(nftState),
                    _buildUnclaimedNFTsTab(nftState),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(WalletConnectionState walletState) {
    final isConnected = walletState.isConnected && walletState.walletAddress != null;
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textColor),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My NFT Collection',
                      style: AppTheme.modernTitle.copyWith(
                        fontSize: 24,
                        color: AppTheme.textColor,
                      ),
                    ),
                    Text(
                      isConnected 
                          ? _getStatsText()
                          : 'Connect your wallet to view your claimed NFTs',
                      style: AppTheme.modernBodySecondary.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isGridView = !_isGridView;
                  });
                },
                icon: Icon(
                  _isGridView ? Icons.list : Icons.grid_view,
                  color: AppTheme.primaryColor,
                ),
              ),
              IconButton(
                onPressed: () {
                  ref.read(nftCollectionProvider.notifier).refreshNFTs();
                },
                icon: const Icon(
                  Icons.refresh,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: AppTheme.modernContainerDecoration,
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: AppTheme.primaryGradient,
        ),
        labelColor: AppTheme.textColor,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: AppTheme.modernButton,
        unselectedLabelStyle: AppTheme.modernBodySecondary,
        tabs: const [
          Tab(text: 'All Claimed'),
          Tab(text: 'By Event'),
          Tab(text: 'Recent'),
        ],
      ),
    );
  }

  Widget _buildAllNFTsTab(NFTCollectionState nftState) {
    return _buildNFTContent(nftState, (collection) => collection.nfts);
  }

  Widget _buildClaimedNFTsTab(NFTCollectionState nftState) {
    // Group NFTs by event
    if (nftState.collection == null || nftState.collection!.isEmpty) {
      return _buildEmptyState();
    }
    
    return _buildEventGroupedContent(nftState);
  }

  Widget _buildUnclaimedNFTsTab(NFTCollectionState nftState) {
    // Show recent NFTs (claimed in last 7 days)
    if (nftState.collection == null || nftState.collection!.isEmpty) {
      return _buildEmptyState();
    }
    
    final recentNFTs = nftState.collection!.nfts.where((nft) {
      if (nft.claimTimestamp == null) return false;
      final daysSinceClaim = DateTime.now().difference(nft.claimTimestamp!).inDays;
      return daysSinceClaim <= 7;
    }).toList();
    
    return _buildNFTContent(nftState, (collection) => recentNFTs);
  }

  Widget _buildNFTContent(NFTCollectionState nftState, List<NFT> Function(NFTCollection) nftSelector) {
    if (nftState.isLoading) {
      return _buildLoadingState();
    }

    if (nftState.error != null) {
      return _buildErrorState(nftState.error!);
    }

    if (nftState.collection == null || nftState.collection!.isEmpty) {
      return _buildEmptyState();
    }

    final nfts = nftSelector(nftState.collection!);

    if (nfts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(nftCollectionProvider.notifier).refreshNFTs(),
      color: AppTheme.primaryColor,
      child: _isGridView 
          ? _buildGridView(nfts)
          : _buildListView(nfts),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: AppTheme.modernGlassEffect,
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading your NFTs...',
            style: AppTheme.modernBody.copyWith(
              color: AppTheme.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.modernContainerDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppTheme.errorColor,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading NFTs',
              style: AppTheme.modernTitle.copyWith(
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTheme.modernBodySecondary.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(nftCollectionProvider.notifier).loadNFTs();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventGroupedContent(NFTCollectionState nftState) {
    final collection = nftState.collection!;
    final eventGroups = <int, List<NFT>>{};
    
    // Group NFTs by event ID
    for (final nft in collection.nfts) {
      if (!eventGroups.containsKey(nft.eventId)) {
        eventGroups[nft.eventId] = [];
      }
      eventGroups[nft.eventId]!.add(nft);
    }
    
    return RefreshIndicator(
      onRefresh: () => ref.read(nftCollectionProvider.notifier).refreshNFTs(),
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: eventGroups.length,
        itemBuilder: (context, index) {
          final eventId = eventGroups.keys.elementAt(index);
          final eventNFTs = eventGroups[eventId]!;
          final eventName = eventNFTs.first.eventName ?? 'Event #$eventId';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: AppTheme.modernContainerDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.event,
                          color: AppTheme.textColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eventName,
                              style: AppTheme.modernSubtitle.copyWith(
                                color: AppTheme.textColor,
                              ),
                            ),
                            Text(
                              '${eventNFTs.length} claimed NFTs',
                              style: AppTheme.modernBodySecondary.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // NFTs Grid
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _isGridView 
                      ? _buildEventNFTsGrid(eventNFTs)
                      : _buildEventNFTsList(eventNFTs),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventNFTsGrid(List<NFT> nfts) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: nfts.length,
      itemBuilder: (context, index) {
        return _buildNFTCard(nfts[index]);
      },
    );
  }

  Widget _buildEventNFTsList(List<NFT> nfts) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: nfts.length,
      itemBuilder: (context, index) {
        return _buildNFTListItem(nfts[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    final walletState = ref.watch(walletConnectionProvider);
    final isConnected = walletState.isConnected && walletState.walletAddress != null;
    
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.modernContainerDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TokonLogo(
              size: 80,
              showText: false,
              coinColor: AppTheme.primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              isConnected ? 'No NFTs Found' : 'Wallet Not Connected',
              style: AppTheme.modernTitle.copyWith(
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isConnected 
                  ? 'You haven\'t claimed any bounty NFTs yet. Start exploring events to claim your first NFT!'
                  : 'Connect your wallet to view your claimed bounty NFTs and explore available bounties.',
              style: AppTheme.modernBodySecondary.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/events'),
              child: Text(isConnected ? 'Explore Bounties' : 'Explore Events'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(List<NFT> nfts) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: nfts.length,
      itemBuilder: (context, index) {
        return _buildNFTCard(nfts[index]);
      },
    );
  }

  Widget _buildListView(List<NFT> nfts) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: nfts.length,
      itemBuilder: (context, index) {
        return _buildNFTListItem(nfts[index]);
      },
    );
  }

  Widget _buildNFTCard(NFT nft) {
    return GestureDetector(
      onTap: () => _showNFTDetails(nft),
      child: Container(
        decoration: AppTheme.modernContainerDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // NFT Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: AppTheme.primaryGradient,
                ),
                child: nft.hasValidImage
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(
                          nft.formattedImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholderImage();
                          },
                        ),
                      )
                    : _buildPlaceholderImage(),
              ),
            ),
            
            // NFT Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nft.displayName,
                      style: AppTheme.modernButton.copyWith(
                        color: AppTheme.textColor,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nft.displayDescription,
                      style: AppTheme.modernBodySecondary.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Claimed',
                            style: AppTheme.modernBodySecondary.copyWith(
                              color: AppTheme.successColor,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '#${nft.tokenId}',
                          style: AppTheme.modernBodySecondary.copyWith(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Owner: ${nft.owner.substring(0, 6)}...${nft.owner.substring(nft.owner.length - 4)}',
                      style: AppTheme.modernBodySecondary.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 9,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildNFTListItem(NFT nft) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppTheme.modernContainerDecoration,
      child: ListTile(
        onTap: () => _showNFTDetails(nft),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: AppTheme.primaryGradient,
          ),
          child: nft.hasValidImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    nft.formattedImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildPlaceholderImage();
                    },
                  ),
                )
              : _buildPlaceholderImage(),
        ),
        title: Text(
          nft.displayName,
          style: AppTheme.modernButton.copyWith(
            color: AppTheme.textColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nft.displayDescription,
              style: AppTheme.modernBodySecondary.copyWith(
                color: AppTheme.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Claimed',
                    style: AppTheme.modernBodySecondary.copyWith(
                      color: AppTheme.successColor,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '#${nft.tokenId}',
                  style: AppTheme.modernBodySecondary.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                Text(
                  'Owner: ${nft.owner.substring(0, 6)}...${nft.owner.substring(nft.owner.length - 4)}',
                  style: AppTheme.modernBodySecondary.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: AppTheme.textSecondary,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(
          Icons.image,
          color: AppTheme.textColor,
          size: 24,
        ),
      ),
    );
  }

  void _showNFTDetails(NFT nft) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildNFTDetailsSheet(nft),
    );
  }

  Widget _buildNFTDetailsSheet(NFT nft) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    nft.displayName,
                    style: AppTheme.modernTitle.copyWith(
                      color: AppTheme.textColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.textColor),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NFT Image
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: nft.hasValidImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              nft.formattedImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholderImage();
                              },
                            ),
                          )
                        : _buildPlaceholderImage(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Description
                  Text(
                    'Description',
                    style: AppTheme.modernButton.copyWith(
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nft.displayDescription,
                    style: AppTheme.modernBody.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Details
                  _buildDetailRow('Token ID', '#${nft.tokenId}'),
                  _buildDetailRow('Event ID', '#${nft.eventId}'),
                  _buildDetailRow('Status', 'Claimed'),
                  _buildDetailRow('Owner', '${nft.owner.substring(0, 6)}...${nft.owner.substring(nft.owner.length - 4)}'),
                  _buildDetailRow('Location', nft.locationString),
                  _buildDetailRow('Radius', nft.radiusString),
                  
                  if (nft.eventName != null)
                    _buildDetailRow('Event', nft.eventName!),
                  
                  if (nft.eventVenue != null)
                    _buildDetailRow('Venue', nft.eventVenue!),
                  
                  if (nft.mintTimestamp != null)
                    _buildDetailRow('Minted', _formatDate(nft.mintTimestamp!)),
                  
                  if (nft.claimTimestamp != null)
                    _buildDetailRow('Claimed', _formatDate(nft.claimTimestamp!)),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTheme.modernBodySecondary.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.modernBody.copyWith(
                color: AppTheme.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getStatsText() {
    final nftState = ref.watch(nftCollectionProvider);
    final walletState = ref.watch(walletConnectionProvider);
    
    if (nftState.collection == null) {
      final displayAddress = walletState.walletAddress != null 
          ? '${walletState.walletAddress!.substring(0, 6)}...${walletState.walletAddress!.substring(walletState.walletAddress!.length - 4)}'
          : 'Unknown';
      return 'Wallet: $displayAddress';
    }
    
    final collection = nftState.collection!;
    final totalNFTs = collection.nfts.length;
    final uniqueEvents = collection.uniqueEventIds.length;
    
    if (totalNFTs == 0) {
      return 'No claimed NFTs yet';
    } else if (totalNFTs == 1) {
      return '1 NFT claimed from $uniqueEvents event${uniqueEvents == 1 ? '' : 's'}';
    } else {
      return '$totalNFTs NFTs claimed from $uniqueEvents event${uniqueEvents == 1 ? '' : 's'}';
    }
  }
}
