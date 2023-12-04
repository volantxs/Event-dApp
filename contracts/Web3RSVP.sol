// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract Web3RSVP{

    event NewEventCreated(
        bytes32 eventID,
        address creatorAddress,
        uint256 eventTimestamp,
        uint256 maxCapacity,
        uint256 deposit,
        string eventDataCID
    );

    event NewRSVP(bytes32 eventID, address attendeeAddress);

    event ConfirmedAttendee(bytes32 eventID, address attendeeAddress);

    event DepositsPaidOut(bytes32 eventID);

    struct CreateEvent {
        bytes32 eventID;
        string eventDataCID;
        address eventOwner;
        uint256 eventTimestamp;
        uint256 deposit;
        uint256 maxCapacity;
        address[] confirmedRSVPs;
        address[] claimedRSVPs;
        bool paidOut;
    }

    mapping(bytes32 => CreateEvent) public idToEvent; //defines realtion of event id to its data

    function createNewEvent(
        uint256 eventTimestamp,
        uint256 deposit,
        uint256 maxCapacity,
        string calldata eventDataCID //ref to IPFS hash containg metadata
    ) external { //visibility 
        // generate an eventID based on other things passed in to generate a hash
        bytes32 eventID = keccak256(
            abi.encodePacked(
                msg.sender,
                address(this),
                eventTimestamp,
                deposit,
                maxCapacity
            )
        );

        address[] memory confirmedRSVPs; //post physical attendance
        address[] memory claimedRSVPs; //over the dApp

        // creates a new CreateEvent struct and adds it to the idToEvent mapping
        idToEvent[eventID] = CreateEvent(
            eventID,
            eventDataCID,
            msg.sender,
            eventTimestamp,
            deposit,
            maxCapacity,
            confirmedRSVPs,
            claimedRSVPs,
            false //default
        );

        emit NewEventCreated(
            eventID,
            msg.sender,
            eventTimestamp,
            maxCapacity,
            deposit,
            eventDataCID
        );

    }

    
    function  createNewRSVP(bytes32 eventId) external payable {
        CreateEvent storage myEvent = idToEvent[eventId]; 
        require(msg.value == myEvent.deposit, "NOT ENOUGH");
        require(block.timestamp <= myEvent.eventTimestamp, "ALREADY HAPPENED");
        require(
            myEvent.confirmedRSVPs.length < myEvent.maxCapacity,
            "This event has reached capacity"
        );

        for (uint8 i = 0; i < myEvent.confirmedRSVPs.length; i++) {
            require((myEvent.confirmedRSVPs[i]) != msg.sender, "ALREADY CONFIRMED");
        }

        myEvent.confirmedRSVPs.push(payable(msg.sender));

        emit NewRSVP(eventId, msg.sender);


    }

    function confirmAttendee(bytes32 eventId, address attendee) public {
        CreateEvent storage myEvent = idToEvent[eventId];
        require(msg.sender == myEvent.eventOwner, "NOT AUTHORIZED");
        address rsvpConfirm;
        for (uint8 i = 0; i < myEvent.confirmedRSVPs.length; i++) {
            if (myEvent.confirmedRSVPs[i] == attendee){
                rsvpConfirm = myEvent.confirmedRSVPs[i];
            }
        }
        require(rsvpConfirm == attendee, "NO RSVP CONFIRM");
         for (uint8 i = 0; i < myEvent.claimedRSVPs.length; i++) {
            require(myEvent.claimedRSVPs[i] != attendee, "ALREADY CLAIMED");
        }
        require(myEvent.paidOut == false, "ALREADY PAID OUT");

        myEvent.claimedRSVPs.push(attendee);
        (bool sent,) = attendee.call{value: myEvent.deposit}("");
        if (!sent) {
            myEvent.claimedRSVPs.pop();
        }

        require(sent, "FAILED TO SENT ETH");

        emit ConfirmedAttendee(eventId, attendee);
    }

    function confirmAllAttendees(bytes32 eventId) external {
        CreateEvent memory myEvent = idToEvent[eventId];
        require(msg.sender == myEvent.eventOwner, "NOT AUTHORIZED");
        for (uint8 i = 0; i < myEvent.confirmedRSVPs.length; i++ ) {
            confirmAttendee(eventId, myEvent.confirmedRSVPs[i]);
        }
    }

    function withdrawUnclaimedDeposits(bytes32 eventId) external {
    CreateEvent memory myEvent = idToEvent[eventId];
    require(!myEvent.paidOut, "ALREADY PAID");
    require(
        block.timestamp >= (myEvent.eventTimestamp + 7 days),
        "TOO EARLY"
    );
    require(msg.sender == myEvent.eventOwner, "MUST BE EVENT OWNER");
    uint256 unclaimed = myEvent.confirmedRSVPs.length - myEvent.claimedRSVPs.length;
    uint256 payout = unclaimed * myEvent.deposit;
    myEvent.paidOut = true;
    (bool sent, ) = msg.sender.call{value: payout}("");
    if (!sent) {
        myEvent.paidOut = false;
    }
    require(sent, "Failed to send Ether");
    emit DepositsPaidOut(eventId);
}




}