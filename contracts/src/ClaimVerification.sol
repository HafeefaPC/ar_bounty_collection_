// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract ClaimVerification is AccessControl, ReentrancyGuard {
    using ECDSA for bytes32;
    
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    
    struct LocationClaim {
        address claimer;
        uint256 tokenId;
        uint256 eventId;
        int256 latitude;  // Latitude * 1e6 for precision
        int256 longitude; // Longitude * 1e6 for precision
        uint256 timestamp;
        uint256 accuracy; // GPS accuracy in meters * 1e3 for precision
        bytes signature;  // Signed by trusted oracle or app
        bool verified;
        uint256 verificationTime;
    }
    
    struct LocationBoundary {
        int256 centerLatitude;
        int256 centerLongitude;
        uint256 radius; // in meters
        bool active;
    }
    
    mapping(bytes32 => LocationClaim) public locationClaims;
    mapping(uint256 => LocationBoundary) public tokenBoundaries;
    mapping(address => bool) public trustedSigners;
    mapping(uint256 => bytes32[]) public tokenClaimHistory; // tokenId => claim hashes
    
    // Configuration
    uint256 public maxClaimAge = 300; // 5 minutes in seconds
    uint256 public minAccuracy = 10000; // 10 meters * 1000 for precision
    uint256 public verificationWindow = 1800; // 30 minutes for verification
    
    event LocationClaimSubmitted(
        bytes32 indexed claimHash,
        address indexed claimer,
        uint256 indexed tokenId,
        int256 latitude,
        int256 longitude,
        uint256 timestamp
    );
    
    event LocationClaimVerified(
        bytes32 indexed claimHash,
        address indexed verifier,
        bool verified,
        uint256 verificationTime
    );
    
    event TrustedSignerUpdated(address indexed signer, bool trusted);
    event BoundaryUpdated(uint256 indexed tokenId, int256 latitude, int256 longitude, uint256 radius);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
    }
    
    function submitLocationClaim(
        uint256 tokenId,
        uint256 eventId,
        int256 latitude,
        int256 longitude,
        uint256 timestamp,
        uint256 accuracy,
        bytes calldata signature
    ) external nonReentrant returns (bytes32) {
        require(timestamp <= block.timestamp, "Future timestamp not allowed");
        require(timestamp >= block.timestamp - maxClaimAge, "Claim too old");
        require(accuracy <= minAccuracy, "GPS accuracy insufficient");
        
        bytes32 claimHash = keccak256(abi.encodePacked(
            msg.sender,
            tokenId,
            eventId,
            latitude,
            longitude,
            timestamp,
            accuracy
        ));
        
        require(locationClaims[claimHash].claimer == address(0), "Claim already exists");
        
        // Verify signature from trusted app or oracle
        bytes32 messageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            claimHash
        ));
        
        address signer = messageHash.recover(signature);
        require(trustedSigners[signer], "Signature not from trusted signer");
        
        locationClaims[claimHash] = LocationClaim({
            claimer: msg.sender,
            tokenId: tokenId,
            eventId: eventId,
            latitude: latitude,
            longitude: longitude,
            timestamp: timestamp,
            accuracy: accuracy,
            signature: signature,
            verified: false,
            verificationTime: 0
        });
        
        tokenClaimHistory[tokenId].push(claimHash);
        
        emit LocationClaimSubmitted(claimHash, msg.sender, tokenId, latitude, longitude, timestamp);
        
        return claimHash;
    }
    
    function verifyLocationClaim(
        bytes32 claimHash,
        bool isValid
    ) external onlyRole(VERIFIER_ROLE) {
        LocationClaim storage claim = locationClaims[claimHash];
        require(claim.claimer != address(0), "Claim does not exist");
        require(!claim.verified, "Claim already verified");
        require(
            block.timestamp <= claim.timestamp + verificationWindow,
            "Verification window expired"
        );
        
        if (isValid) {
            LocationBoundary memory boundary = tokenBoundaries[claim.tokenId];
            require(boundary.active, "Boundary not active");
            
            // Calculate distance using integer math to avoid floating point
            int256 deltaLat = claim.latitude - boundary.centerLatitude;
            int256 deltaLng = claim.longitude - boundary.centerLongitude;
            
            // Approximate distance calculation (good enough for small distances)
            uint256 distanceSquared = uint256(deltaLat * deltaLat + deltaLng * deltaLng);
            uint256 radiusSquared = boundary.radius * boundary.radius * 1000000; // Adjust for lat/lng scaling
            
            require(distanceSquared <= radiusSquared, "Location outside boundary");
        }
        
        claim.verified = true;
        claim.verificationTime = block.timestamp;
        
        emit LocationClaimVerified(claimHash, msg.sender, isValid, block.timestamp);
    }
    
    
    function setTokenBoundary(
        uint256 tokenId,
        int256 centerLatitude,
        int256 centerLongitude,
        uint256 radius
    ) external onlyRole(ORACLE_ROLE) {
        require(radius > 0 && radius <= 1000, "Invalid radius");
        
        tokenBoundaries[tokenId] = LocationBoundary({
            centerLatitude: centerLatitude,
            centerLongitude: centerLongitude,
            radius: radius,
            active: true
        });
        
        emit BoundaryUpdated(tokenId, centerLatitude, centerLongitude, radius);
    }
    
    function deactivateTokenBoundary(uint256 tokenId) external onlyRole(ORACLE_ROLE) {
        tokenBoundaries[tokenId].active = false;
    }
    
    function setTrustedSigner(address signer, bool trusted) external onlyRole(DEFAULT_ADMIN_ROLE) {
        trustedSigners[signer] = trusted;
        emit TrustedSignerUpdated(signer, trusted);
    }
    
    function updateVerificationParameters(
        uint256 newMaxClaimAge,
        uint256 newMinAccuracy,
        uint256 newVerificationWindow
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newMaxClaimAge <= 3600, "Max claim age too long"); // 1 hour max
        require(newMinAccuracy >= 1000, "Min accuracy too strict"); // 1 meter minimum
        require(newVerificationWindow <= 86400, "Verification window too long"); // 24 hours max
        
        maxClaimAge = newMaxClaimAge;
        minAccuracy = newMinAccuracy;
        verificationWindow = newVerificationWindow;
    }
    
    function getLocationClaim(bytes32 claimHash) external view returns (LocationClaim memory) {
        return locationClaims[claimHash];
    }
    
    function getTokenBoundary(uint256 tokenId) external view returns (LocationBoundary memory) {
        return tokenBoundaries[tokenId];
    }
    
    function getTokenClaimHistory(uint256 tokenId) external view returns (bytes32[] memory) {
        return tokenClaimHistory[tokenId];
    }
    
    function isClaimValid(bytes32 claimHash) external view returns (bool) {
        LocationClaim memory claim = locationClaims[claimHash];
        return claim.verified && claim.claimer != address(0);
    }
    
    function canClaimToken(
        address claimer,
        uint256 tokenId,
        int256 latitude,
        int256 longitude
    ) external view returns (bool) {
        LocationBoundary memory boundary = tokenBoundaries[tokenId];
        
        if (!boundary.active) {
            return false;
        }
        
        // Calculate distance
        int256 deltaLat = latitude - boundary.centerLatitude;
        int256 deltaLng = longitude - boundary.centerLongitude;
        
        uint256 distanceSquared = uint256(deltaLat * deltaLat + deltaLng * deltaLng);
        uint256 radiusSquared = boundary.radius * boundary.radius * 1000000;
        
        return distanceSquared <= radiusSquared;
    }
    
    function generateClaimProof(
        address claimer,
        uint256 tokenId,
        uint256 eventId,
        int256 latitude,
        int256 longitude,
        uint256 timestamp
    ) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            claimer,
            tokenId,
            eventId,
            latitude,
            longitude,
            timestamp
        ));
    }

    function batchVerifyLocationClaims(
        bytes32[] calldata claimHashes,
        bool[] calldata validities
    ) external onlyRole(VERIFIER_ROLE) {
        require(claimHashes.length == validities.length, "Array length mismatch");
        require(claimHashes.length <= 50, "Batch too large");
        
        for (uint256 i = 0; i < claimHashes.length; i++) {
            bytes32 claimHash = claimHashes[i];
            bool isValid = validities[i];
            
            LocationClaim storage claim = locationClaims[claimHash];
            require(claim.claimer != address(0), "Claim does not exist");
            require(!claim.verified, "Claim already verified");
            require(
                block.timestamp <= claim.timestamp + verificationWindow,
                "Verification window expired"
            );
            
            if (isValid) {
                LocationBoundary memory boundary = tokenBoundaries[claim.tokenId];
                require(boundary.active, "Boundary not active");
                
                int256 deltaLat = claim.latitude - boundary.centerLatitude;
                int256 deltaLng = claim.longitude - boundary.centerLongitude;
                
                uint256 distanceSquared = uint256(deltaLat * deltaLat + deltaLng * deltaLng);
                uint256 radiusSquared = boundary.radius * boundary.radius * 1000000;
                
                require(distanceSquared <= radiusSquared, "Location outside boundary");
            }
            
            claim.verified = true;
            claim.verificationTime = block.timestamp;
            
            emit LocationClaimVerified(claimHash, msg.sender, isValid, block.timestamp);
        }
    }
}