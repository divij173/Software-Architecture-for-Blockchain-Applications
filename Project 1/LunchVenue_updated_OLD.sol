/// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

/// @title Contract to agree on the lunch venue
/// @author Dilum Bandara , CSIRO ’s Data61

contract LunchVenue {

    struct Friend {
        string name ;
        bool voted ; // Vote state
    }

    struct Vote {
        address voterAddress ;
        uint restaurant ;
    }

    mapping(uint=>string) public restaurants ; // List of restaurants ( restaurant no ,name )
    mapping(address=>Friend) public friends ; // List of friends ( address , Friend )

    mapping(address=>bool) private hasVoted; // WEAKNESS          Track if a friend has voted
    bool timeCheck = false;
    uint private timeStart; // WEAKNESS strat time block
    uint private timeEnd; // WEAKNESS end time block

    uint public numRestaurants = 0;
    uint public numFriends = 0;
    uint public numVotes = 0;
    address public manager; // Contract manager
    string public votedRestaurant = ""; // Where to have lunch

    mapping(uint=>Vote) public votes; // List of votes ( vote no , Vote )
    mapping(uint=>uint) private _results; // List of vote counts ( restaurant no , noof votes )
    bool public voteOpen = true; // voting is open

    /**
    * @dev Set manager when contract starts
    */
    constructor() {
        manager = msg.sender; // Set contract creator as manager
        timeStart=block.number;
        timeEnd=block.number+1400;
    }


    // WEAKNESS
    function stopContract() public restricted SessionTimedOut returns (bool){
        // voteOpen = false;
        finalResult();
        return voteOpen;
    }

    /**
    * @notice Add a new restaurant
    * @dev To simplify the code , duplication of restaurants isn ’t checked
    *
    * @param name Restaurant name
    * @return Number of restaurants added so far
    */
    function addRestaurant(string memory name) public restricted SessionTimedOut returns ( uint ){
        
        require(bytes(name).length > 0, "Restaurant name cannot be empty");
        uint i = 1;
        while(i<=numRestaurants) {
            // Referenced from https://www.quicknode.com/guides/ethereum-development/smart-contracts/how-to-use-keccak256-with-solidity/#:~:text=Keccak256%20is%20a%20powerful%20tool,developers%20in%20the%20Ethereum%20ecosystem.
            require(keccak256(bytes(restaurants[i])) != keccak256(bytes(name)), "Restaurant already exists.");
            i++;
        }
        // require(restaurants[numRestaurants] != name, "Restaurant already exists");

        numRestaurants ++;
        restaurants[numRestaurants] = name;
        return numRestaurants;
    }

    /**
    * @notice Add a new friend to voter list
    * @dev To simplify the code duplication of friends is not checked
    *
    * @param friendAddress Friend ’s account / address
    * @param name Friend ’s name
    * @return Number of friends added so far
    */
    function addFriend(address friendAddress , string memory name) public restricted SessionTimedOut returns ( uint ){
        require(bytes(name).length > 0, "Name should not be empty");
        require(friends[friendAddress].voted == false, "Vote given already");
        // Referenced from https://www.quicknode.com/guides/ethereum-development/smart-contracts/how-to-use-keccak256-with-solidity/#:~:text=Keccak256%20is%20a%20powerful%20tool,developers%20in%20the%20Ethereum%20ecosystem.
        require(keccak256(bytes(friends[friendAddress].name)) != keccak256(bytes(name)), "Friend name already exists.");
        require(keccak256(bytes(friends[friendAddress].name)) > 0, "Friend already exists.");
        Friend memory f;
        f.name = name;
        f.voted = false;
        friends[friendAddress] = f;
        numFriends ++;
        return numFriends;
    }

    /**
    * @notice Vote for a restaurant
    * @dev To simplify the code duplicate votes by a friend is not checked
    *
    * @param restaurant Restaurant number being voted
    * @return validVote Is the vote valid ? A valid vote should be from a registered
        friend to a registered restaurant
    */
    function doVote (uint restaurant) public votingOpen SessionTimedOut returns ( bool validVote ){
        // validVote = false ; // Is the vote valid ?

        require(hasVoted[msg.sender]==false && friends[msg.sender].voted==false, "You have voted already");
        require(restaurant<=numRestaurants && restaurant>0, "Restaurant number is incorrect");
        
        if ( bytes(friends[msg.sender].name).length!= 0) { // Does friend exist ?
            if ( bytes(restaurants[restaurant]).length!= 0) { // Does restaurant exist ?
                hasVoted[msg.sender] = true;
                validVote = true;
                friends[msg.sender].voted = true;
                Vote memory v;
                v.voterAddress = msg.sender;
                v.restaurant = restaurant;
                numVotes++;
                votes[numVotes] = v;
            }
        }

        if ( numVotes >= numFriends/2 + 1) { // Quorum is met
            finalResult() ;
        }
        return validVote ;
    }

    function SessionTimed() private returns (bool){
        if (timeEnd <= block.number) {
            timeCheck = true;
            finalResult();
        }
        return timeCheck;
    }

    /**
    * @notice Determine winner restaurant
    * @dev If top 2 restaurants have the same no of votes , result depends on vote order
    */
    function finalResult() private {
        uint highestVotes = 0;
        uint highestRestaurant = 0;

        for ( uint i = 1; i <= numVotes ; i++) { // For each vote
            uint voteCount = 1;
            if( _results[votes[i].restaurant] > 0) { // Already start counting
                voteCount += _results[votes[i].restaurant];
            }
            _results[votes[i].restaurant] = voteCount ;

            if (voteCount > highestVotes){ // New winner
                highestVotes = voteCount;
                highestRestaurant = votes[i].restaurant;
            }
        }
        votedRestaurant = restaurants[highestRestaurant]; // Chosen restaurant
        voteOpen = false ; // Voting is now closed
    }

    /**
    * @notice Only the manager can do
    */
    modifier restricted() {
        require ( msg.sender == manager , "Can only be executed by the manager");
        _;
    }

    /**
    * @notice Only when voting is still open
    */
    modifier votingOpen() {
        require ( voteOpen == true , "Can vote only while voting is open.") ;
        _;
    }

    modifier SessionTimedOut() {
        require(SessionTimed() == false, "The contract has session timed.");
        _;
    }
    
}
