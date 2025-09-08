import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/web3_service.dart';
import '../../../shared/services/wallet_service.dart';
import '../../../shared/models/boundary.dart';
import '../../../core/theme/retro_theme.dart';

class NFTCollectionScreen extends ConsumerStatefulWidget {
  const NFTCollectionScreen({super.key});

  @override
  ConsumerState<NFTCollectionScreen> createState() => _NFTCollectionScreenState();
}

class _NFTCollectionScreenState extends ConsumerState<NFTCollectionScreen>
    with TickerProviderStateMixin {
  late Web3Service _web3Service;
  late WalletService _walletService;
  
  List<Map<String, dynamic>> _userNFTs = [];
  bool _isLoading = true;
  String? _error;
  
  late AnimationController _scanlineController;
  late Animation<double> _scanlineAnimation;
  
  @override
  void initState() {
    super.initState();
    _web3Service = Web3Service();
    _walletService = WalletService();
    
    _setupAnimations();
    _loadUserNFTs();
  }
  
  void _setupAnimations() {
    _scanlineController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scanlineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanlineController, curve: Curves.linear),
    );
    _scanlineController.repeat();
  }
  
  Future<void> _loadUserNFTs() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      final walletAddress = _walletService.connectedWalletAddress;
      if (walletAddress == null) {
        setState(() {
          _error = 'No wallet connected';
          _isLoading = false;
        });
        return;
      }
      
      print('🎨 Loading NFTs for wallet: $walletAddress');
      
      // Get user's NFT token IDs
      final tokenIds = await _web3Service.getUserNFTs(walletAddress);
      print('🎨 Found ${tokenIds.length} NFT tokens');
      
      // Load metadata for each NFT
      List<Map<String, dynamic>> nfts = [];
      for (int tokenId in tokenIds) {
        try {
          final metadata = await _web3Service.getNFTMetadata(tokenId);
          final isClaimed = await _web3Service.isTokenClaimed(tokenId);
          
          nfts.add({
            'tokenId': tokenId,
            'metadata': metadata,
            'isClaimed': isClaimed,
          });
        } catch (e) {
          print('❌ Error loading metadata for token $tokenId: $e');
        }
      }
      
      setState(() {
        _userNFTs = nfts;
        _isLoading = false;
      });
      
      print('🎨 Loaded ${nfts.length} NFTs successfully');
      
    } catch (e) {
      print('❌ Error loading user NFTs: $e');
      setState(() {
        _error = 'Failed to load NFTs: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background scanline effect
          AnimatedBuilder(
            animation: _scanlineAnimation,
            builder: (context, child) {
              return Positioned(
                top: MediaQuery.of(context).size.height * _scanlineAnimation.value,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        RetroTheme.brightGreen.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),
                
                // Content
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState()
                      : _error != null
                          ? _buildErrorState()
                          : _userNFTs.isEmpty
                              ? _buildEmptyState()
                              : _buildNFTGrid(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RetroTheme.darkGreen,
        border: Border.all(color: RetroTheme.primaryGreen, width: 2),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/wallet/options'),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: RetroTheme.primaryGreen,
                border: Border.all(color: RetroTheme.brightGreen, width: 1),
              ),
              child: Text(
                '<<',
                style: TextStyle(
                  fontFamily: 'Courier',
                  color: RetroTheme.brightGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'NFT COLLECTION',
              style: TextStyle(
                fontFamily: 'Courier',
                color: RetroTheme.brightGreen,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _loadUserNFTs,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: RetroTheme.primaryGreen,
                border: Border.all(color: RetroTheme.brightGreen, width: 1),
              ),
              child: Text(
                'REFRESH',
                style: TextStyle(
                  fontFamily: 'Courier',
                  color: RetroTheme.brightGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: RetroTheme.darkGreen,
          border: Border.all(color: RetroTheme.primaryGreen, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _scanlineAnimation,
              builder: (context, child) {
                return Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(color: RetroTheme.brightGreen, width: 2),
                    color: RetroTheme.primaryGreen.withOpacity(_scanlineAnimation.value * 0.5),
                  ),
                  child: Center(
                    child: Text(
                      'NFT',
                      style: TextStyle(
                        fontFamily: 'Courier',
                        color: RetroTheme.brightGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'LOADING NFT COLLECTION...',
              style: TextStyle(
                fontFamily: 'Courier',
                color: RetroTheme.brightGreen,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'SCANNING BLOCKCHAIN...',
              style: TextStyle(
                fontFamily: 'Courier',
                color: RetroTheme.lightGreen,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: RetroTheme.darkGreen,
          border: Border.all(color: RetroTheme.primaryGreen, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: RetroTheme.brightGreen, width: 2),
                color: RetroTheme.primaryGreen,
              ),
              child: Center(
                child: Text(
                  '!',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    color: RetroTheme.brightGreen,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ERROR LOADING NFTS',
              style: TextStyle(
                fontFamily: 'Courier',
                color: RetroTheme.brightGreen,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(
                fontFamily: 'Courier',
                color: RetroTheme.lightGreen,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loadUserNFTs,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: RetroTheme.primaryGreen,
                  border: Border.all(color: RetroTheme.brightGreen, width: 2),
                ),
                child: Text(
                  '[ RETRY ]',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    color: RetroTheme.brightGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: RetroTheme.darkGreen,
          border: Border.all(color: RetroTheme.primaryGreen, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: RetroTheme.primaryGreen, width: 2),
              ),
              child: Center(
                child: Text(
                  '?',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    color: RetroTheme.primaryGreen,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'NO NFTS FOUND',
              style: TextStyle(
                fontFamily: 'Courier',
                color: RetroTheme.brightGreen,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'START EXPLORING TO COLLECT NFTS',
              style: TextStyle(
                fontFamily: 'Courier',
                color: RetroTheme.lightGreen,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => context.go('/wallet/options'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: RetroTheme.primaryGreen,
                  border: Border.all(color: RetroTheme.brightGreen, width: 2),
                ),
                child: Text(
                  '[ EXPLORE ]',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    color: RetroTheme.brightGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNFTGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _userNFTs.length,
      itemBuilder: (context, index) {
        final nft = _userNFTs[index];
        return _buildNFTCard(nft);
      },
    );
  }
  
  Widget _buildNFTCard(Map<String, dynamic> nft) {
    final metadata = nft['metadata'] as Map<String, dynamic>;
    final tokenId = nft['tokenId'] as int;
    final isClaimed = nft['isClaimed'] as bool;
    
    return GestureDetector(
      onTap: () => _showNFTDetails(nft),
      child: Container(
        decoration: BoxDecoration(
          color: RetroTheme.darkGreen,
          border: Border.all(
            color: isClaimed ? RetroTheme.brightGreen : RetroTheme.primaryGreen,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: isClaimed ? RetroTheme.brightGreen : RetroTheme.primaryGreen,
              child: Text(
                'TOKEN #$tokenId',
                style: TextStyle(
                  fontFamily: 'Courier',
                  color: RetroTheme.darkGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // NFT Image
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isClaimed ? RetroTheme.brightGreen : RetroTheme.primaryGreen,
                    width: 1,
                  ),
                ),
                child: _buildNFTImage(metadata['imageURI'] ?? ''),
              ),
            ),
            
            // NFT Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: RetroTheme.primaryGreen,
              child: Column(
                children: [
                  Text(
                    (metadata['name'] ?? 'Unknown NFT').toString().toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Courier',
                      color: RetroTheme.darkGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isClaimed ? 'CLAIMED' : 'UNCLAIMED',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      color: RetroTheme.darkGreen,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNFTImage(String imageUrl) {
    if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      return Container(
        color: RetroTheme.primaryGreen,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: RetroTheme.brightGreen,
                  border: Border.all(color: RetroTheme.lightGreen, width: 1),
                ),
                child: Center(
                  child: Container(
                    width: 16,
                    height: 16,
                    color: RetroTheme.lightGreen,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'NFT',
                style: TextStyle(
                  fontFamily: 'Courier',
                  color: RetroTheme.brightGreen,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: RetroTheme.primaryGreen,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              valueColor: AlwaysStoppedAnimation<Color>(RetroTheme.brightGreen),
              backgroundColor: RetroTheme.primaryGreen,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: RetroTheme.primaryGreen,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: RetroTheme.brightGreen,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  'ERROR',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    color: RetroTheme.brightGreen,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  void _showNFTDetails(Map<String, dynamic> nft) {
    final metadata = nft['metadata'] as Map<String, dynamic>;
    final tokenId = nft['tokenId'] as int;
    final isClaimed = nft['isClaimed'] as bool;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: RetroTheme.primaryGreen,
            border: Border.all(color: RetroTheme.brightGreen, width: 3),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: RetroTheme.darkGreen,
              border: Border.all(color: RetroTheme.primaryGreen, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: RetroTheme.brightGreen,
                    border: Border.all(color: RetroTheme.lightGreen, width: 2),
                  ),
                  child: Text(
                    '>>> NFT DETAILS <<<',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      color: RetroTheme.darkGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // NFT Image
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: RetroTheme.brightGreen, width: 3),
                    color: RetroTheme.primaryGreen,
                  ),
                  child: _buildNFTImage(metadata['imageURI'] ?? ''),
                ),
                const SizedBox(height: 16),
                
                // NFT Info
                _buildDetailRow('Token ID', '#$tokenId'),
                _buildDetailRow('Name', metadata['name'] ?? 'Unknown'),
                _buildDetailRow('Description', metadata['description'] ?? 'No description'),
                _buildDetailRow('Status', isClaimed ? 'CLAIMED' : 'UNCLAIMED'),
                if (metadata['claimer'] != null)
                  _buildDetailRow('Claimer', metadata['claimer']),
                if (metadata['claimTimestamp'] != null)
                  _buildDetailRow('Claimed At', DateTime.fromMillisecondsSinceEpoch(
                    (metadata['claimTimestamp'] as int) * 1000
                  ).toString()),
                
                const SizedBox(height: 20),
                
                // Close button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                    decoration: BoxDecoration(
                      color: RetroTheme.primaryGreen,
                      border: Border.all(color: RetroTheme.brightGreen, width: 2),
                    ),
                    child: Text(
                      '[ CLOSE ]',
                      style: TextStyle(
                        fontFamily: 'Courier',
                        color: RetroTheme.brightGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 10,
              color: RetroTheme.lightGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: RetroTheme.primaryGreen,
              border: Border.all(color: RetroTheme.brightGreen, width: 1),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
                color: RetroTheme.darkGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _scanlineController.dispose();
    super.dispose();
  }
}
