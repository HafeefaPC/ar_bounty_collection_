import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';

class IPFSService {
  static final IPFSService _instance = IPFSService._internal();
  factory IPFSService() => _instance;
  IPFSService._internal();

  final Dio _dio = Dio();
  
  // Using Pinata as IPFS provider
  static const String _pinataApiUrl = 'https://api.pinata.cloud';
  static const String _pinataGatewayUrl = 'https://gateway.pinata.cloud';
  
  // Alternative: Web3.Storage (reserved for future implementation)
  // ignore: unused_field
  static const String _web3StorageApiUrl = 'https://api.web3.storage';
  
  // Configuration - using provided Pinata credentials
  static const String _pinataJWT = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySW5mb3JtYXRpb24iOnsiaWQiOiI3YzE1NGViNy00ODVjLTQyMGMtODMzNy03ZDg4N2RjMGFhZWUiLCJlbWFpbCI6ImFhemltYW5pc2hnZGV2QGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJwaW5fcG9saWN5Ijp7InJlZ2lvbnMiOlt7ImRlc2lyZWRSZXBsaWNhdGlvbkNvdW50IjoxLCJpZCI6IkZSQTEifSx7ImRlc2lyZWRSZXBsaWNhdGlvbkNvdW50IjoxLCJpZCI6Ik5ZQzEifV0sInZlcnNpb24iOjF9LCJtZmFfZW5hYmxlZCI6ZmFsc2UsInN0YXR1cyI6IkFDVElWRSJ9LCJhdXRoZW50aWNhdGlvblR5cGUiOiJzY29wZWRLZXkiLCJzY29wZWRLZXlLZXkiOiI5OTFmMDQ0YzZlMTY2MzgyMzc2YSIsInNjb3BlZEtleVNlY3JldCI6IjIwZjUyMzRlYWExNzEwOWE5OGQ1NDlkNTZmZTk0YTllMjczY2VhY2I2OThiMjRlMDEzMjQ4MTZiMTIxNThkMjAiLCJleHAiOjE3ODgwOTEzNTB9.tqTP-KB7qLh0xTEPwxPhoKmrqC4NDY7jKEUY-PEr1D0';
  
  // Initialize with API credentials
  void initialize() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);
  }

  // Upload a single file to IPFS via Pinata
  Future<String> uploadFile(
    File file, {
    String? name,
    Map<String, dynamic>? metadata,
    bool pin = true,
  }) async {

    try {
      final fileName = name ?? file.path.split('/').last;
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
        if (metadata != null)
          'pinataMetadata': jsonEncode({
            'name': fileName,
            ...metadata,
          }),
        if (pin)
          'pinataOptions': jsonEncode({
            'cidVersion': 1,
          }),
      });

      final response = await _dio.post(
        '$_pinataApiUrl/pinning/pinFileToIPFS',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_pinataJWT',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200) {
        final result = response.data;
        return result['IpfsHash'] as String;
      } else {
        throw Exception('Failed to upload file: ${response.statusMessage}');
      }
    } catch (e) {
      print('IPFS upload error: $e');
      throw Exception('Failed to upload file to IPFS: $e');
    }
  }

  // Upload JSON metadata to IPFS
  Future<String> uploadJson(
    Map<String, dynamic> jsonData, {
    String? name,
    Map<String, dynamic>? metadata,
  }) async {

    try {
      final metadataName = name ?? 'metadata-${DateTime.now().millisecondsSinceEpoch}';
      
      final requestData = {
        'pinataContent': jsonData,
        'pinataMetadata': {
          'name': metadataName,
          if (metadata != null) ...metadata,
        },
        'pinataOptions': {
          'cidVersion': 1,
        },
      };

      final response = await _dio.post(
        '$_pinataApiUrl/pinning/pinJSONToIPFS',
        data: requestData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_pinataJWT',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final result = response.data;
        return result['IpfsHash'] as String;
      } else {
        throw Exception('Failed to upload JSON: ${response.statusMessage}');
      }
    } catch (e) {
      print('IPFS JSON upload error: $e');
      throw Exception('Failed to upload JSON to IPFS: $e');
    }
  }

  // Retrieve content from IPFS
  Future<Map<String, dynamic>?> getJson(String cid) async {
    try {
      final response = await _dio.get(
        '$_pinataGatewayUrl/ipfs/$cid',
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data is String 
            ? jsonDecode(response.data) 
            : response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to retrieve JSON: ${response.statusMessage}');
      }
    } catch (e) {
      print('IPFS retrieve error: $e');
      return null;
    }
  }

  // Get IPFS URL for a given CID
  String getIpfsUrl(String cid) {
    return '$_pinataGatewayUrl/ipfs/$cid';
  }

  // Upload event metadata to IPFS
  Future<String> uploadEventMetadata({
    required String eventId,
    required String name,
    required String description,
    required String venue,
    required String organizerAddress,
    required double latitude,
    required double longitude,
    required List<Map<String, dynamic>> boundaries,
    String? imageIpfsHash,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final eventMetadata = {
      'name': name,
      'description': description,
      'image': imageIpfsHash != null ? 'ipfs://$imageIpfsHash' : null,
      'external_url': 'https://tokon.app/events/$eventId',
      'attributes': [
        {
          'trait_type': 'Event Type',
          'value': 'AR Bounty Hunt',
        },
        {
          'trait_type': 'Organizer',
          'value': organizerAddress,
        },
        {
          'trait_type': 'Total Boundaries',
          'value': boundaries.length,
        },
        {
          'trait_type': 'Location',
          'value': venue,
        },
      ],
      'properties': {
        'event_id': eventId,
        'organizer': organizerAddress,
        'venue': {
          'name': venue,
          'coordinates': {
            'latitude': latitude,
            'longitude': longitude,
          },
        },
        'boundaries': boundaries.map((boundary) => {
          'id': boundary['id'],
          'name': boundary['name'],
          'description': boundary['description'],
          'location': {
            'latitude': boundary['latitude'],
            'longitude': boundary['longitude'],
            'radius': boundary['radius'],
          },
          'image': boundary['imageIpfsHash'] != null 
              ? 'ipfs://${boundary['imageIpfsHash']}' 
              : null,
        }).toList(),
        'created_at': DateTime.now().toIso8601String(),
        if (additionalMetadata != null) ...additionalMetadata,
      },
    };

    return await uploadJson(
      eventMetadata,
      name: 'event-$eventId-metadata',
      metadata: {
        'type': 'event_metadata',
        'event_id': eventId,
        'created_by': 'tokon_app',
      },
    );
  }

  // Upload NFT metadata to IPFS (ERC721 compatible)
  Future<String> uploadNFTMetadata({
    required String tokenId,
    required String eventId,
    required String name,
    required String description,
    required double latitude,
    required double longitude,
    required double radius,
    String? imageIpfsHash,
    String? animationIpfsHash,
    Map<String, dynamic>? additionalAttributes,
  }) async {
    final nftMetadata = {
      'name': name,
      'description': description,
      'image': imageIpfsHash != null ? 'ipfs://$imageIpfsHash' : null,
      if (animationIpfsHash != null) 'animation_url': 'ipfs://$animationIpfsHash',
      'external_url': 'https://tokon.app/nft/$tokenId',
      'attributes': [
        {
          'trait_type': 'Event ID',
          'value': eventId,
        },
        {
          'trait_type': 'Location Type',
          'value': 'AR Boundary',
        },
        {
          'trait_type': 'Claim Radius',
          'value': '${radius}m',
        },
        {
          'trait_type': 'Latitude',
          'value': latitude,
          'display_type': 'number',
        },
        {
          'trait_type': 'Longitude',
          'value': longitude,
          'display_type': 'number',
        },
        if (additionalAttributes != null)
          ...additionalAttributes.entries.map((entry) => {
            'trait_type': entry.key,
            'value': entry.value,
          }),
      ],
      'properties': {
        'token_id': tokenId,
        'event_id': eventId,
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'radius': radius,
        },
        'minted_at': DateTime.now().toIso8601String(),
        'blockchain': 'avalanche',
        'standard': 'ERC721',
      },
    };

    return await uploadJson(
      nftMetadata,
      name: 'nft-$tokenId-metadata',
      metadata: {
        'type': 'nft_metadata',
        'token_id': tokenId,
        'event_id': eventId,
        'created_by': 'tokon_app',
      },
    );
  }

  // Upload image and get IPFS hash
  Future<String> uploadImage(File imageFile, {String? name}) async {
    return await uploadFile(
      imageFile,
      name: name,
      metadata: {
        'type': 'image',
        'uploaded_by': 'tokon_app',
      },
    );
  }

  // Batch upload multiple files
  Future<List<String>> uploadFiles(
    List<File> files, {
    List<String>? names,
    Map<String, dynamic>? metadata,
  }) async {
    final results = <String>[];
    
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final name = names != null && names.length > i ? names[i] : null;
      
      try {
        final cid = await uploadFile(file, name: name, metadata: metadata);
        results.add(cid);
      } catch (e) {
        print('Failed to upload file ${file.path}: $e');
        rethrow;
      }
    }
    
    return results;
  }

  // Pin existing IPFS content
  Future<bool> pinByCID(String cid, {String? name}) async {

    try {
      final requestData = {
        'hashToPin': cid,
        if (name != null)
          'pinataMetadata': {
            'name': name,
          },
      };

      final response = await _dio.post(
        '$_pinataApiUrl/pinning/pinByHash',
        data: requestData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_pinataJWT',
            'Content-Type': 'application/json',
          },
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('IPFS pin error: $e');
      return false;
    }
  }

  // Unpin IPFS content
  Future<bool> unpin(String cid) async {

    try {
      final response = await _dio.delete(
        '$_pinataApiUrl/pinning/unpin/$cid',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_pinataJWT',
          },
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('IPFS unpin error: $e');
      return false;
    }
  }

  // Get pinned content list
  Future<List<Map<String, dynamic>>> getPinnedContent({
    String? status,
    String? metadata,
    int? limit,
    int? offset,
  }) async {

    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;
      if (metadata != null) queryParams['metadata'] = metadata;
      if (limit != null) queryParams['pageLimit'] = limit;
      if (offset != null) queryParams['pageOffset'] = offset;

      final response = await _dio.get(
        '$_pinataApiUrl/data/pinList',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_pinataJWT',
          },
        ),
      );

      if (response.statusCode == 200) {
        final result = response.data;
        return List<Map<String, dynamic>>.from(result['rows'] ?? []);
      } else {
        throw Exception('Failed to get pinned content: ${response.statusMessage}');
      }
    } catch (e) {
      print('IPFS pinned content error: $e');
      return [];
    }
  }

  // Generate a hash for content verification
  String generateContentHash(Uint8List content) {
    final digest = sha256.convert(content);
    return digest.toString();
  }

  // Validate IPFS CID format
  bool isValidCID(String cid) {
    // Basic CID validation - can be enhanced
    return cid.isNotEmpty && 
           (cid.startsWith('Qm') || cid.startsWith('bafy') || cid.startsWith('bafk'));
  }

  // Clean up and dispose resources
  void dispose() {
    _dio.close();
  }
}