// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleEventFactory {
    uint256 private _eventIdCounter;
    
    struct Event {
        uint256 id;
        address organizer;
        string name;
        string description;
        uint256 startTime;
        uint256 endTime;
    }
    
    mapping(uint256 => Event) public events;
    mapping(string => bool) public eventCodes;
    
    event EventCreated(
        uint256 indexed eventId,
        address indexed organizer,
        string name,
        string eventCode
    );
    
    function createEvent(
        string memory _name,
        string memory _description,
        string memory _eventCode,
        uint256 _startTime,
        uint256 _endTime
    ) external returns (uint256) {
        require(bytes(_name).length > 0, "Event name cannot be empty");
        require(bytes(_eventCode).length > 0, "Event code cannot be empty");
        require(!eventCodes[_eventCode], "Event code already exists");
        require(_startTime > block.timestamp, "Start time must be in the future");
        require(_endTime > _startTime, "End time must be after start time");
        
        _eventIdCounter++;
        uint256 eventId = _eventIdCounter;
        
        events[eventId] = Event({
            id: eventId,
            organizer: msg.sender,
            name: _name,
            description: _description,
            startTime: _startTime,
            endTime: _endTime
        });
        
        eventCodes[_eventCode] = true;
        
        emit EventCreated(eventId, msg.sender, _name, _eventCode);
        
        return eventId;
    }
    
    function getEvent(uint256 _eventId) external view returns (Event memory) {
        require(_eventId > 0 && _eventId <= _eventIdCounter, "Event does not exist");
        return events[_eventId];
    }
    
    function eventCodeExists(string memory _eventCode) external view returns (bool) {
        return eventCodes[_eventCode];
    }
    
    function getEventCount() external view returns (uint256) {
        return _eventIdCounter;
    }
}


