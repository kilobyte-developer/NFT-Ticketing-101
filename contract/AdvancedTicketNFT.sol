// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

contract AdvancedTicketNFT is ERC721, ERC721URIStorage, Ownable, IERC2981 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    struct Event {
        string name;
        string venue;
        uint256 date;
        uint256 price;
        uint256 maxSupply;
        uint256 currentSupply;
        bool isActive;
        address organizer;
        uint256 royaltyPercentage; // Percentage for resales (in basis points, e.g., 250 = 2.5%)
        uint256 maxResales; // Maximum number of resales allowed
    }

    struct Ticket {
        uint256 eventId;
        string[] attendeeNames;
        string[] attendeeEmails;
        string[] attendeeIds;
        bool isCheckedIn;
        uint256 purchaseTime;
        address originalBuyer;
        uint256 resaleCount;
        string qrCodeHash; // Hash of QR code data
    }

    struct TermsAndConditions {
        string termsHash; // IPFS hash of T&C document
        uint256 version;
        bool isActive;
    }

    mapping(uint256 => Event) public events;
    mapping(uint256 => Ticket) public tickets;
    mapping(uint256 => TermsAndConditions) public eventTerms;
    mapping(address => mapping(uint256 => bool)) public hasAcceptedTerms; // user => termsVersion => accepted
    mapping(uint256 => address) public ticketToOrganizer; // tokenId => organizer address
    
    uint256 public eventCounter;
    uint256 public termsVersion;

    event EventCreated(uint256 indexed eventId, string name, address organizer, uint256 royaltyPercentage);
    event TicketMinted(uint256 indexed tokenId, uint256 indexed eventId, address buyer, uint256 attendeeCount);
    event TicketCheckedIn(uint256 indexed tokenId, address organizer);
    event TicketResold(uint256 indexed tokenId, address from, address to, uint256 price, uint256 royalty);
    event TermsAccepted(address indexed user, uint256 termsVersion);
    event TermsUpdated(uint256 indexed eventId, string termsHash, uint256 version);

    constructor() ERC721("AdvancedEventTicket", "AETKT") {}

    function createEvent(
        string memory _name,
        string memory _venue,
        uint256 _date,
        uint256 _price,
        uint256 _maxSupply,
        uint256 _royaltyPercentage,
        uint256 _maxResales,
        string memory _termsHash
    ) external {
        require(_royaltyPercentage <= 1000, "Royalty too high"); // Max 10%
        require(_maxResales > 0, "Must allow at least 1 resale");

        events[eventCounter] = Event({
            name: _name,
            venue: _venue,
            date: _date,
            price: _price,
            maxSupply: _maxSupply,
            currentSupply: 0,
            isActive: true,
            organizer: msg.sender,
            royaltyPercentage: _royaltyPercentage,
            maxResales: _maxResales
        });

        // Set terms and conditions for this event
        termsVersion++;
        eventTerms[eventCounter] = TermsAndConditions({
            termsHash: _termsHash,
            version: termsVersion,
            isActive: true
        });

        emit EventCreated(eventCounter, _name, msg.sender, _royaltyPercentage);
        emit TermsUpdated(eventCounter, _termsHash, termsVersion);
        
        eventCounter++;
    }

    function acceptTerms(uint256 _eventId) external {
        require(events[_eventId].isActive, "Event not active");
        require(eventTerms[_eventId].isActive, "Terms not active");
        
        uint256 currentTermsVersion = eventTerms[_eventId].version;
        hasAcceptedTerms[msg.sender][currentTermsVersion] = true;
        
        emit TermsAccepted(msg.sender, currentTermsVersion);
    }

    function mintTicket(
        uint256 _eventId,
        string[] memory _attendeeNames,
        string[] memory _attendeeEmails,
        string[] memory _attendeeIds,
        string memory _qrCodeHash,
        string memory _tokenURI
    ) external payable {
        require(events[_eventId].isActive, "Event is not active");
        require(events[_eventId].currentSupply < events[_eventId].maxSupply, "Event sold out");
        require(msg.value >= events[_eventId].price, "Insufficient payment");
        require(_attendeeNames.length == _attendeeEmails.length && 
                _attendeeEmails.length == _attendeeIds.length, "Attendee data mismatch");
        require(_attendeeNames.length > 0, "At least one attendee required");
        
        // Check if user has accepted terms
        uint256 currentTermsVersion = eventTerms[_eventId].version;
        require(hasAcceptedTerms[msg.sender][currentTermsVersion], "Must accept terms first");

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        tickets[tokenId] = Ticket({
            eventId: _eventId,
            attendeeNames: _attendeeNames,
            attendeeEmails: _attendeeEmails,
            attendeeIds: _attendeeIds,
            isCheckedIn: false,
            purchaseTime: block.timestamp,
            originalBuyer: msg.sender,
            resaleCount: 0,
            qrCodeHash: _qrCodeHash
        });

        events[_eventId].currentSupply++;
        ticketToOrganizer[tokenId] = events[_eventId].organizer;

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);

        // Transfer payment to organizer (minus platform fee if any)
        payable(events[_eventId].organizer).transfer(msg.value);

        emit TicketMinted(tokenId, _eventId, msg.sender, _attendeeNames.length);
    }

    function checkInTicket(uint256 _tokenId, string memory _qrCodeData) external {
        require(_exists(_tokenId), "Ticket does not exist");
        require(ticketToOrganizer[_tokenId] == msg.sender, "Only organizer can check in");
        require(!tickets[_tokenId].isCheckedIn, "Ticket already checked in");
        
        // Verify QR code hash (in production, you'd want more sophisticated verification)
        require(keccak256(abi.encodePacked(_qrCodeData)) == keccak256(abi.encodePacked(tickets[_tokenId].qrCodeHash)), 
                "Invalid QR code");
        
        tickets[_tokenId].isCheckedIn = true;
        emit TicketCheckedIn(_tokenId, msg.sender);
    }

    function resaleTicket(uint256 _tokenId, uint256 _price) external payable {
        require(ownerOf(_tokenId) == msg.sender, "Not ticket owner");
        require(!tickets[_tokenId].isCheckedIn, "Cannot resell used ticket");
        require(tickets[_tokenId].resaleCount < events[tickets[_tokenId].eventId].maxResales, 
                "Resale limit exceeded");
        require(msg.value >= _price, "Insufficient payment for resale");

        uint256 eventId = tickets[_tokenId].eventId;
        uint256 royaltyAmount = (_price * events[eventId].royaltyPercentage) / 10000;
        uint256 sellerAmount = _price - royaltyAmount;

        address organizer = events[eventId].organizer;
        address seller = msg.sender;

        // Update resale count
        tickets[_tokenId].resaleCount++;

        // Transfer payments
        payable(organizer).transfer(royaltyAmount);
        payable(seller).transfer(sellerAmount);

        emit TicketResold(_tokenId, seller, msg.sender, _price, royaltyAmount);
    }

    // ERC2981 Royalty Standard Implementation
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) 
        external view override returns (address, uint256) {
        require(_exists(_tokenId), "Token does not exist");
        
        uint256 eventId = tickets[_tokenId].eventId;
        address organizer = events[eventId].organizer;
        uint256 royaltyAmount = (_salePrice * events[eventId].royaltyPercentage) / 10000;
        
        return (organizer, royaltyAmount);
    }

    // View functions
    function getEvent(uint256 _eventId) external view returns (Event memory) {
        return events[_eventId];
    }

    function getTicket(uint256 _tokenId) external view returns (Ticket memory) {
        return tickets[_tokenId];
    }

    function getEventTerms(uint256 _eventId) external view returns (TermsAndConditions memory) {
        return eventTerms[_eventId];
    }

    function hasUserAcceptedTerms(address _user, uint256 _eventId) external view returns (bool) {
        uint256 currentTermsVersion = eventTerms[_eventId].version;
        return hasAcceptedTerms[_user][currentTermsVersion];
    }

    function canResellTicket(uint256 _tokenId) external view returns (bool) {
        if (!_exists(_tokenId)) return false;
        if (tickets[_tokenId].isCheckedIn) return false;
        
        uint256 eventId = tickets[_tokenId].eventId;
        return tickets[_tokenId].resaleCount < events[eventId].maxResales;
    }

    // Override required functions
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) 
        public view override(ERC721, ERC721URIStorage, IERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Emergency functions
    function pauseEvent(uint256 _eventId) external {
        require(events[_eventId].organizer == msg.sender || owner() == msg.sender, "Not authorized");
        events[_eventId].isActive = false;
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
