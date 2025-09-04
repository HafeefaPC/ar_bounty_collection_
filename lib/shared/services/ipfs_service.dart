import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';

class IPFSService {
  // Using Pinata as IPFS provider (you'll need to get API keys)
  static const String _pinataApiUrl = 'https://api.pinata.cloud';
  static const String _pinataGatewayUrl = 'https://gateway.pinata.cloud/ipfs';
  
  // You need to get these from Pinata Cloud (https://pinata.cloud)
  // For now, using placeholder values - you'll need to replace these
  static const String _pinataApiKey = '559204340244924ee65f';
  static const String _pinataSecretKey = 'f78a3294d53c074d28cd9e9d8fb51fea88e4fb212ff12c0410b8c6a5365d6c6c';
  
  late Dio _dio;
  
  IPFSService() {
    _dio = Dio();
    _dio.options.baseUrl = _pinataApiUrl;
    _dio.options.headers = {
      'pinata_api_key': _pinataApiKey,
      'pinata_secret_api_key': _pinataSecretKey,
    };
  }
  
  // Upload file to IPFS
  Future<String> uploadFile(String filePath, {String? customName}) async {
    try {
      print('📤 IPFSService: Uploading file to IPFS...');
      print('File path: $filePath');
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }
      
      final fileName = customName ?? path.basename(filePath);
      final mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';
      
      // Create form data
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
        'pinataMetadata': jsonEncode({
          'name': fileName,
          'keyvalues': {
            'app': 'face_reflector',
            'type': 'nft_image',
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          }
        }),
        'pinataOptions': jsonEncode({
          'cidVersion': 1,
        }),
      });
      
      final response = await _dio.post('/pinning/pinFileToIPFS', data: formData);
      
      if (response.statusCode == 200) {
        final ipfsHash = response.data['IpfsHash'] as String;
        final ipfsUrl = '$_pinataGatewayUrl/$ipfsHash';
        
        print('✅ IPFSService: File uploaded successfully');
        print('IPFS Hash: $ipfsHash');
        print('IPFS URL: $ipfsUrl');
        
        return ipfsUrl;
      } else {
        throw Exception('Failed to upload file: ${response.statusMessage}');
      }
    } catch (e) {
      print('❌ IPFSService: Error uploading file: $e');
      rethrow;
    }
  }
  
  // Upload JSON metadata to IPFS
  Future<String> uploadMetadata(Map<String, dynamic> metadata) async {
    try {
      print('📤 IPFSService: Uploading metadata to IPFS...');
      
      final metadataJson = jsonEncode(metadata);
      final fileName = 'metadata_${DateTime.now().millisecondsSinceEpoch}.json';
      
      // Create form data
      final formData = FormData.fromMap({
        'file': MultipartFile.fromString(
          metadataJson,
          filename: fileName,
          contentType: MediaType.parse('application/json'),
        ),
        'pinataMetadata': jsonEncode({
          'name': fileName,
          'keyvalues': {
            'app': 'face_reflector',
            'type': 'metadata',
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          }
        }),
        'pinataOptions': jsonEncode({
          'cidVersion': 1,
        }),
      });
      
      final response = await _dio.post('/pinning/pinFileToIPFS', data: formData);
      
      if (response.statusCode == 200) {
        final ipfsHash = response.data['IpfsHash'] as String;
        final ipfsUrl = '$_pinataGatewayUrl/$ipfsHash';
        
        print('✅ IPFSService: Metadata uploaded successfully');
        print('IPFS Hash: $ipfsHash');
        print('IPFS URL: $ipfsUrl');
        
        return ipfsUrl;
      } else {
        throw Exception('Failed to upload metadata: ${response.statusMessage}');
      }
    } catch (e) {
      print('❌ IPFSService: Error uploading metadata: $e');
      rethrow;
    }
  }
  
  // Create NFT metadata JSON
  Map<String, dynamic> createNFTMetadata({
    required String name,
    required String description,
    required String imageUrl,
    required Map<String, dynamic> attributes,
    String? externalUrl,
  }) {
    return {
      'name': name,
      'description': description,
      'image': imageUrl,
      'external_url': externalUrl,
      'attributes': attributes.entries.map((entry) => {
        'trait_type': entry.key,
        'value': entry.value,
      }).toList(),
      'background_color': '000000',
      'animation_url': null,
      'youtube_url': null,
    };
  }
  
  // Create event metadata JSON
  Map<String, dynamic> createEventMetadata({
    required String name,
    required String description,
    required String organizer,
    required double latitude,
    required double longitude,
    required String venue,
    required int nftSupplyCount,
    required String imageUrl,
    required List<Map<String, dynamic>> boundaries,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return {
      'name': name,
      'description': description,
      'organizer': organizer,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
        'venue': venue,
      },
      'nft_supply_count': nftSupplyCount,
      'image': imageUrl,
      'boundaries': boundaries,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'version': '1.0.0',
    };
  }
  
  // Get file from IPFS
  Future<String> getFileFromIPFS(String ipfsHash) async {
    try {
      final response = await _dio.get('/$ipfsHash');
      return response.data;
    } catch (e) {
      print('❌ IPFSService: Error getting file from IPFS: $e');
      rethrow;
    }
  }
  
  // Get JSON data from IPFS
  Future<Map<String, dynamic>?> getJson(String cid) async {
    try {
      print('📥 IPFSService: Fetching JSON from IPFS...');
      print('CID: $cid');
      
      final response = await _dio.get('$_pinataGatewayUrl/$cid');
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          print('✅ IPFSService: JSON fetched successfully');
          return data;
        } else if (data is String) {
          print('✅ IPFSService: JSON string fetched, parsing...');
          return jsonDecode(data) as Map<String, dynamic>;
        }
      }
      
      print('❌ IPFSService: Failed to fetch JSON - Status: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ IPFSService: Error fetching JSON: $e');
      return null;
    }
  }

  // Test IPFS connection
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('/data/testAuthentication');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ IPFSService: Connection test failed: $e');
      return false;
    }
  }
  
  void dispose() {
    _dio.close();
  }
}

// Extension for MediaType
extension MediaTypeExtension on String {
  MediaType parse(String mimeType) {
    return MediaType.parse(mimeType);
  }
}