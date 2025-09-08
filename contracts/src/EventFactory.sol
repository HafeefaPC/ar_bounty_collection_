// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract EventFactory is Ownable, AccessControl, ReentrancyGuard {
    bytes32 public constant ORGANIZER_ROLE = keccak256("ORGANIZER_ROLE");
    
    uint256 private _eventIdCounter;
    
    struct Event {
        uint256 id;
        address organizer;
        string name;
        string description;
        string venue;
        uint256 startTime;
        uint256 endTime;
        uint256 totalNFTs;
        string metadataURI; // IPFS CID
        bool active;
        uint256 createdAt;
        uint256 claimedCount;
        // Geographic data (stored as scaled integers for precision)
        int256 latitude;  // Latitude * 1e6 for precision
        int256 longitude; // Longitude * 1e6 for precision
        uint256 radius;   // Radius in meters
    }
    
    struct EventMetrics {
        uint256 totalParticipants;
        uint256 totalClaims;
        uint256 uniqueClaimers;
    }
    
    mapping(uint256 => Event) public events;
    mapping(uint256 => EventMetrics) public eventMetrics;
    mapping(string => uint256) public eventCodeToId; // Event code to ID mapping
    mapping(uint256 => string) public eventIdToCode; // ID to event code mapping
    mapping(address => uint256[]) public organizerEvents;
    mapping(uint256 => address[]) public eventParticipants;
    
    event EventCreated(
        uint256 indexed eventId,
        address indexed organizer,
        string name,
        string eventCode,
        uint256 totalNFTs,
        string metadataURI
    );
    
    event EventUpdated(uint256 indexed eventId, string metadataURI);
    event EventDeactivated(uint256 indexed eventId);
    event EventActivated(uint256 indexed eventId);
    event ParticipantJoined(uint256 indexed eventId, address indexed participant);
    
    constructor() Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORGANIZER_ROLE, msg.sender);
    }
    
    modifier onlyEventOrganizer(uint256 eventId) {
        require(events[eventId].organizer == msg.sender, "Not the event organizer");
        _;
    }
    
    modifier eventExists(uint256 eventId) {
        require(events[eventId].id == eventId, "Event does not exist");
        _;
    }
    
    function createEvent(
        string calldata name,
        string calldata description,
        string calldata venue,
        uint256 startTime,
        uint256 endTime,
        uint256 totalNFTs,
        string calldata metadataURI,
        string calldata eventCode,
        int256 latitude,
        int256 longitude,
        uint256 radius
    ) external nonReentrant returns (uint256) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(eventCode).length >= 4, "Event code must be at least 4 characters");
        require(eventCodeToId[eventCode] == 0, "Event code already exists");
        require(totalNFTs > 0 && totalNFTs <= 10000, "Invalid NFT count");
        require(endTime > startTime, "End time must be after start time");
        require(startTime > block.timestamp, "Start time must be in the future");
        
        _eventIdCounter++;
        uint256 eventId = _eventIdCounter;
        
        events[eventId] = Event({
            id: eventId,
            organizer: msg.sender,
            name: name,
            description: description,
            venue: venue,
            startTime: startTime,
            endTime: endTime,
            totalNFTs: totalNFTs,
            metadataURI: metadataURI,
            active: true,
            createdAt: block.timestamp,
            claimedCount: 0,
            latitude: latitude,
            longitude: longitude,
            radius: radius
        });
        
        eventCodeToId[eventCode] = eventId;
        eventIdToCode[eventId] = eventCode;
        organizerEvents[msg.sender].push(eventId);
        
        emit EventCreated(eventId, msg.sender, name, eventCode, totalNFTs, metadataURI);
        
        return eventId;
    }
    
    function updateEventMetadata(
        uint256 eventId, 
        string calldata newMetadataURI
    ) external eventExists(eventId) onlyEventOrganizer(eventId) {
        events[eventId].metadataURI = newMetadataURI;
        emit EventUpdated(eventId, newMetadataURI);
    }
    
    function deactivateEvent(uint256 eventId) 
        external 
        eventExists(eventId) 
        onlyEventOrganizer(eventId) 
    {
        events[eventId].active = false;
        emit EventDeactivated(eventId);
    }
    
    function activateEvent(uint256 eventId) 
        external 
        eventExists(eventId) 
        onlyEventOrganizer(eventId) 
    {
        events[eventId].active = true;
        emit EventActivated(eventId);
    }
    
    function joinEvent(uint256 eventId) external eventExists(eventId) {
        require(events[eventId].active, "Event is not active");
        require(block.timestamp >= events[eventId].startTime, "Event has not started yet");
        require(block.timestamp <= events[eventId].endTime, "Event has ended");
        
        // Check if user already joined
        address[] storage participants = eventParticipants[eventId];
        for (uint i = 0; i < participants.length; i++) {
            if (participants[i] == msg.sender) {
                return; // Already joined
            }
        }
        
        participants.push(msg.sender);
        eventMetrics[eventId].totalParticipants++;
        
        emit ParticipantJoined(eventId, msg.sender);
    }
    
    function incrementClaimedCount(uint256 eventId) external eventExists(eventId) {
        // This should be called by the BoundaryNFT contract
        require(hasRole(ORGANIZER_ROLE, msg.sender), "Caller is not authorized");
        events[eventId].claimedCount++;
        eventMetrics[eventId].totalClaims++;
    }
    
    function getEventByCode(string calldata eventCode) 
        external 
        view 
        returns (Event memory) 
    {
        uint256 eventId = eventCodeToId[eventCode];
        require(eventId > 0, "Event code does not exist");
        return events[eventId];
    }
    
    function getEvent(uint256 eventId) 
        external 
        view 
        eventExists(eventId) 
        returns (Event memory) 
    {
        return events[eventId];
    }
    
    function getOrganizerEvents(address organizer) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return organizerEvents[organizer];
    }
    
    function getEventParticipants(uint256 eventId) 
        external 
        view 
        eventExists(eventId) 
        returns (address[] memory) 
    {
        return eventParticipants[eventId];
    }
    
    function getEventMetrics(uint256 eventId) 
        external 
        view 
        eventExists(eventId) 
        returns (EventMetrics memory) 
    {
        return eventMetrics[eventId];
    }
    
    function isEventActive(uint256 eventId) 
        external 
        view 
        eventExists(eventId) 
        returns (bool) 
    {
        Event memory evt = events[eventId];
        return evt.active && 
               block.timestamp >= evt.startTime && 
               block.timestamp <= evt.endTime;
    }
    
    function getTotalEvents() external view returns (uint256) {
        return _eventIdCounter;
    }
    
    // Admin functions
    function grantOrganizerRole(address account) external onlyOwner {
        _grantRole(ORGANIZER_ROLE, account);
    }
    
    function revokeOrganizerRole(address account) external onlyOwner {
        _revokeRole(ORGANIZER_ROLE, account);
    }
    
    // Grant ORGANIZER_ROLE to multiple addresses at once
    function grantOrganizerRoleToMultiple(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _grantRole(ORGANIZER_ROLE, accounts[i]);
        }
    }
    
    // Check if an address has ORGANIZER_ROLE
    function hasOrganizerRole(address account) external view returns (bool) {
        return hasRole(ORGANIZER_ROLE, account);
    }
}