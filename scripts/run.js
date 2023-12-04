const hre = require("hardhat");

const main = async () => {
    const rsvpContractFactory = await hre.ethers.getContractFactory("Web3RSVP");
    const rsvpContract = await rsvpContractFactory.deploy();
    await rsvpContract.deployed();
    console.log("Contract deployed to:", rsvpContract.address);
    
    //test wallet addresses
    const [deployer, address1, address2] = await hre.ethers.getSigners();
    
    //creating mock data
    let deposit = hre.ethers.utils.parseEther("1");
    let maxCapacity = 3;
    let timestamp = 1718926200;
    let eventDataCID =
        "bafybeibhwfzx6oo5rymsxmkdxpmkfwyvbjrrwcl7cekmbzlupmp5ypkyfi"; //IPFS CID

    //Testing CREATING A NEW EVENT
    let txn = await rsvpContract.createNewEvent(
        timestamp,
        deposit,
        maxCapacity,
        eventDataCID
        );
    let wait = await txn.wait();
    console.log("NEW EVENT CREATED:", wait.events[0].event, wait.events[0].args);

    let eventID = wait.events[0].args.eventID;
    console.log("EVENT ID:", eventID);

    //Testing  CREATING A NEW RSVP
    txn = await rsvpContract.createNewRSVP(eventID, { value: deposit });
    wait = await txn.wait();
    console.log("NEW RSVP:", wait.events[0].event, wait.events[0].args);

    //calling contract from another wallets
    txn = await rsvpContract
        .connect(address1)
        .createNewRSVP(eventID, { value: deposit });
    wait = await txn.wait();
    console.log("NEW RSVP:", wait.events[0].event, wait.events[0].args);

    txn = await rsvpContract
        .connect(address2)
        .createNewRSVP(eventID, { value: deposit });
    wait = await txn.wait();
    console.log("NEW RSVP:", wait.events[0].event, wait.events[0].args);

    //Testing CONFIRMING ATTENDEES
    txn = await rsvpContract.confirmAllAttendees(eventID);
    wait = await txn.wait();
    wait.events.forEach((event) =>
        console.log("CONFIRMED:", event.args.attendeeAddress)
    );

    //Manually skipping time -10 years
    await hre.network.provider.send("evm_increaseTime", [15778800000000]);

    txn = await rsvpContract.withdrawUnclaimedDeposits(eventID);
    wait = await txn.wait();
    console.log("WITHDRAWN:", wait.events[0].event, wait.events[0].args);


};

const runMain = async() => {
    try {
        await main();
        process.exit(0);

    } catch (error) {
        console.log(error);
        process.exit(1);
    }
};

runMain();
