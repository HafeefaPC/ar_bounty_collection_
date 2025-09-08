// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface IEventFactory {
    struct Event {
        uint256 id;
        address organizer;
        string name;
        string description;
        string venue;
        uint256 startTime;
        uint256 endTime;
        uint256 totalNFTs;
        string metadataURI;
        bool active;
        uint256 createdAt;
        uint256 claimedCount;
        int256 latitude;
        int256 longitude;
        uint256 radius;
    }
    
    function getEvent(uint256 eventId) external view returns (Event memory);
    function isEventActive(uint256 eventId) external view returns (bool);
    function incrementClaimedCount(uint256 eventId) external;
}

contract BoundaryNFT is ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ORGANIZER_ROLE = keccak256("ORGANIZER_ROLE");
    
    uint256 private _tokenIdCounter;
    
    IEventFactory public eventFactory;
    
    struct NFTMetadata {
        uint256 eventId;
        string name;
        string description;
        string imageURI; // IPFS CID
        int256 latitude;  // Latitude * 1e6 for precision
        int256 longitude; // Longitude * 1e6 for precision
        uint256 radius;   // Claim radius in meters
        uint256 mintTimestamp;
        uint256 claimTimestamp;
        address claimer;
        bytes32 merkleRoot; // For location verification
    }
    
    struct ClaimProof {
        int256 latitude;
        int256 longitude;
        uint256 timestamp;
        bytes32[] merkleProof;
    }
    
    mapping(uint256 => NFTMetadata) public nftMetadata;
    mapping(uint256 => uint256[]) public eventTokens; // eventId => tokenIds
    mapping(address => uint256[]) public userTokens; // user => tokenIds
    mapping(uint256 => bool) public claimedTokens;
    mapping(uint256 => bytes32) public locationMerkleRoots; // tokenId => merkle root for location verification
    
    event BoundaryNFTMinted(
        uint256 indexed tokenId,
        uint256 indexed eventId,
        address indexed organizer,
        string name,
        int256 latitude,
        int256 longitude
    );
    
    event BoundaryNFTClaimed(
        uint256 indexed tokenId,
        uint256 indexed eventId,
        address indexed claimer,
        uint256 claimTime,
        int256 claimLatitude,
        int256 claimLongitude
    );
    
    event LocationMerkleRootUpdated(uint256 indexed tokenId, bytes32 merkleRoot);
    
    constructor(address eventFactoryAddress) ERC721("TOKON Boundary NFT", "TOKON") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(ORGANIZER_ROLE, msg.sender);
        eventFactory = IEventFactory(eventFactoryAddress);
    }
    
    modifier onlyActiveEvent(uint256 eventId) {
        require(eventFactory.isEventActive(eventId), "Event is not active");
        _;
    }
    
    modifier onlyEventOrganizer(uint256 eventId) {
        IEventFactory.Event memory eventData = eventFactory.getEvent(eventId);
        require(eventData.organizer == msg.sender, "Not the event organizer");
        _;
    }
    
    modifier tokenExists(uint256 tokenId) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        _;
    }
    
    function mintBoundaryNFT(
        uint256 eventId,
        string calldata name,
        string calldata description,
        string calldata imageURI,
        int256 latitude,
        int256 longitude,
        uint256 radius,
        string calldata nftTokenURI,
        bytes32 merkleRoot
    ) external onlyEventOrganizer(eventId) nonReentrant returns (uint256) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(radius > 0 && radius <= 1000, "Invalid radius"); // Max 1km radius
        
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        
        // Mint to the organizer initially
        IEventFactory.Event memory eventData = eventFactory.getEvent(eventId);
        _safeMint(eventData.organizer, tokenId);
        _setTokenURI(tokenId, nftTokenURI);
        
        nftMetadata[tokenId] = NFTMetadata({
            eventId: eventId,
            name: name,
            description: description,
            imageURI: imageURI,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            mintTimestamp: block.timestamp,
            claimTimestamp: 0,
            claimer: address(0),
            merkleRoot: merkleRoot
        });
        
        eventTokens[eventId].push(tokenId);
        locationMerkleRoots[tokenId] = merkleRoot;
        
        emit BoundaryNFTMinted(tokenId, eventId, eventData.organizer, name, latitude, longitude);
        emit LocationMerkleRootUpdated(tokenId, merkleRoot);
        
        return tokenId;
    }
    
    
    function claimBoundaryNFT(
        uint256 tokenId,
        ClaimProof calldata proof
    ) external tokenExists(tokenId) nonReentrant {
        require(!claimedTokens[tokenId], "NFT already claimed");
        
        NFTMetadata storage metadata = nftMetadata[tokenId];
        require(metadata.eventId > 0, "Invalid NFT");
        require(eventFactory.isEventActive(metadata.eventId), "Event is not active");
        
        // Verify location using Merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(
            msg.sender,
            proof.latitude,
            proof.longitude,
            proof.timestamp
        ));
        
        require(
            MerkleProof.verify(proof.merkleProof, metadata.merkleRoot, leaf),
            "Invalid location proof"
        );
        
        // Verify claim is within time window (e.g., proof must be recent)
        require(
            proof.timestamp >= block.timestamp - 300, // 5 minutes window
            "Proof too old"
        );
        
        // Transfer NFT from organizer to claimer
        address currentOwner = ownerOf(tokenId);
        _transfer(currentOwner, msg.sender, tokenId);
        
        // Update metadata
        metadata.claimTimestamp = block.timestamp;
        metadata.claimer = msg.sender;
        claimedTokens[tokenId] = true;
        userTokens[msg.sender].push(tokenId);
        
        // Update event factory
        eventFactory.incrementClaimedCount(metadata.eventId);
        
        emit BoundaryNFTClaimed(
            tokenId,
            metadata.eventId,
            msg.sender,
            block.timestamp,
            proof.latitude,
            proof.longitude
        );
    }
    
    function updateLocationMerkleRoot(
        uint256 tokenId,
        bytes32 newMerkleRoot
    ) external tokenExists(tokenId) {
        NFTMetadata storage metadata = nftMetadata[tokenId];
        require(metadata.eventId > 0, "Invalid NFT");
        
        IEventFactory.Event memory eventData = eventFactory.getEvent(metadata.eventId);
        require(eventData.organizer == msg.sender, "Not the event organizer");
        
        metadata.merkleRoot = newMerkleRoot;
        locationMerkleRoots[tokenId] = newMerkleRoot;
        
        emit LocationMerkleRootUpdated(tokenId, newMerkleRoot);
    }
    
    // ===== PUBLIC MINTING FUNCTION (NEW) =====
    
    /**
     * @dev Public function to mint NFT directly to user's wallet
     * This allows users to claim NFTs without organizer role
     * Added for AR bounty collection system
     */
    function publicMintNFT(
        string calldata name,
        string calldata description,
        string calldata imageURI,
        string calldata nftTokenURI
    ) external nonReentrant returns (uint256) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(bytes(imageURI).length > 0, "Image URI cannot be empty");
        require(bytes(nftTokenURI).length > 0, "NFT Token URI cannot be empty");
        
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        
        // Mint directly to the caller
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, nftTokenURI);
        
        // Create metadata for public mint
        nftMetadata[tokenId] = NFTMetadata({
            eventId: 0, // No specific event for public mints
            name: name,
            description: description,
            imageURI: imageURI,
            latitude: 0,
            longitude: 0,
            radius: 0,
            mintTimestamp: block.timestamp,
            claimTimestamp: block.timestamp,
            claimer: msg.sender,
            merkleRoot: bytes32(0)
        });
        
        // Add to user's tokens
        userTokens[msg.sender].push(tokenId);
        
        emit BoundaryNFTMinted(tokenId, 0, msg.sender, name, 0, 0);
        emit BoundaryNFTClaimed(tokenId, 0, msg.sender, block.timestamp, 0, 0);
        
        return tokenId;
    }
    
    function getEventTokens(uint256 eventId) external view returns (uint256[] memory) {
        return eventTokens[eventId];
    }
    
    function getUserTokens(address user) external view returns (uint256[] memory) {
        return userTokens[user];
    }
    
    function getClaimedTokensByEvent(uint256 eventId) external view returns (uint256[] memory) {
        uint256[] memory allTokens = eventTokens[eventId];
        uint256 claimedCount = 0;
        
        // Count claimed tokens
        for (uint256 i = 0; i < allTokens.length; i++) {
            if (claimedTokens[allTokens[i]]) {
                claimedCount++;
            }
        }
        
        // Create array of claimed tokens
        uint256[] memory claimedTokensList = new uint256[](claimedCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allTokens.length; i++) {
            if (claimedTokens[allTokens[i]]) {
                claimedTokensList[index] = allTokens[i];
                index++;
            }
        }
        
        return claimedTokensList;
    }
    
    function getNFTMetadata(uint256 tokenId) external view tokenExists(tokenId) returns (NFTMetadata memory) {
        return nftMetadata[tokenId];
    }
    
    function isNFTClaimed(uint256 tokenId) external view tokenExists(tokenId) returns (bool) {
        return claimedTokens[tokenId];
    }
    
    function getTotalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }

    function batchMintBoundaryNFTs(
        uint256 eventId,
        string[] calldata names,
        string[] calldata descriptions,
        string[] calldata imageURIs,
        int256[] calldata latitudes,
        int256[] calldata longitudes,
        uint256[] calldata radiuses,
        string[] calldata tokenURIs,
        bytes32[] calldata merkleRoots
    ) external onlyEventOrganizer(eventId) nonReentrant returns (uint256[] memory) {
        require(names.length == descriptions.length, "Array length mismatch");
        require(names.length == imageURIs.length, "Array length mismatch");
        require(names.length == latitudes.length, "Array length mismatch");
        require(names.length == longitudes.length, "Array length mismatch");
        require(names.length == radiuses.length, "Array length mismatch");
        require(names.length == tokenURIs.length, "Array length mismatch");
        require(names.length == merkleRoots.length, "Array length mismatch");
        require(names.length <= 100, "Too many NFTs in batch"); // Limit batch size
        
        uint256[] memory tokenIds = new uint256[](names.length);
        IEventFactory.Event memory eventData = eventFactory.getEvent(eventId);
        
        for (uint256 i = 0; i < names.length; i++) {
            require(bytes(names[i]).length > 0, "Name cannot be empty");
            require(radiuses[i] > 0 && radiuses[i] <= 1000, "Invalid radius");
            
            _tokenIdCounter++;
            uint256 tokenId = _tokenIdCounter;
            
            _safeMint(eventData.organizer, tokenId);
            _setTokenURI(tokenId, tokenURIs[i]);
            
            nftMetadata[tokenId] = NFTMetadata({
                eventId: eventId,
                name: names[i],
                description: descriptions[i],
                imageURI: imageURIs[i],
                latitude: latitudes[i],
                longitude: longitudes[i],
                radius: radiuses[i],
                mintTimestamp: block.timestamp,
                claimTimestamp: 0,
                claimer: address(0),
                merkleRoot: merkleRoots[i]
            });
            
            eventTokens[eventId].push(tokenId);
            locationMerkleRoots[tokenId] = merkleRoots[i];
            
            tokenIds[i] = tokenId;
            
            emit BoundaryNFTMinted(tokenId, eventId, eventData.organizer, names[i], latitudes[i], longitudes[i]);
            emit LocationMerkleRootUpdated(tokenId, merkleRoots[i]);
        }
        
        return tokenIds;
    }
    
    // Override required functions for OpenZeppelin v5
    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function _update(address to, uint256 tokenId, address auth) 
        internal 
        override(ERC721, ERC721Enumerable) 
        returns (address) 
    {
        return super._update(to, tokenId, auth);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    // Admin functions
    function grantMinterRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, account);
    }
    
    function revokeMinterRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MINTER_ROLE, account);
    }
    
    function grantOrganizerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ORGANIZER_ROLE, account);
    }
    
    function revokeOrganizerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ORGANIZER_ROLE, account);
    }
}