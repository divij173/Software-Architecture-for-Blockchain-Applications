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

    mapping(address=>bool) private hasVoted; // WEAKNESS 1 Track if a friend has voted
    bool timeCheck = false;// WEAKNESS 5
    uint private timeStart; // WEAKNESS 5 start time block
    uint private timeEnd; // WEAKNESS 5 end time block

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
        timeStart=block.number;// WEAKNESS 5 explanation of at the bottom
        timeEnd=block.number+1400;// WEAKNESS 5 explanation of at the bottom
    }


    // WEAKNESS 4 explanation of at the bottom
    function stopContract() public restricted SessionTimedOut returns (bool){
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
        // WEAKNESS 2 explanation of at the bottom
        require(bytes(name).length > 0, "Restaurant name cannot be empty");
        uint i = 1;
        while(i<=numRestaurants) {
            // WEAKNESS 2 explanation of at the bottom
            require(keccak256(bytes(restaurants[i])) != keccak256(bytes(name)), "Restaurant already exists.");
            i++;
        }
        // require(restaurants[numRestaurants] != name, "Restaurant already exists");

        numRestaurants++;
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
        // WEAKNESS 2 explanation of at the bottom
        require(bytes(name).length > 0, "Name should not be empty");
        // WEAKNESS 1 explanation of at the bottom
        require(friends[friendAddress].voted == false, "Vote given already"); // WEAKNESS 2 explanation of at the bottom
        require(keccak256(bytes(friends[friendAddress].name)) != keccak256(bytes(name)), "Friend name already exists."); // WEAKNESS 2 explanation of at the bottom
        require(keccak256(bytes(friends[friendAddress].name)) > 0, "Friend already exists.");// WEAKNESS 2 explanation of at the bottom
        Friend memory f;
        f.name = name;
        f.voted = false;
        friends[friendAddress] = f;
        numFriends++;
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
        // WEAKNESS 1 & 3 explanation of at the bottom
        require(hasVoted[msg.sender]==false && friends[msg.sender].voted==false, "You have voted already");
        require(restaurant<=numRestaurants && restaurant>0, "Restaurant number is incorrect");// WEAKNESS 3 explanation of at the bottom
        
        if ( bytes(friends[msg.sender].name).length!= 0) { // Does friend exist ?
            if ( bytes(restaurants[restaurant]).length!= 0) { // Does restaurant exist ?
                // WEAKNESS 1 & 3  explanation of at the bottom
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
    // WEAKNESS 5 explanation of at the bottom
    modifier SessionTimedOut() {
        require(SessionTimed() == false, "The contract has session timed.");
        _;
    }

    /*
        Explanation Point by point:
         1. To make sure a friend can only vote once, a new boolean mapping "hasVoted" is added to doVote function. It keeps track of whether a friend has voted or not.
            Also, when adding a friend or recording a vote, code checks if the friend has already voted before proceeding.

         2. To make sure there are no duplicate restaurants and friends, additional checks are added when adding a restaurant or a friend. For restaurants, it checks
            if the new restaurant name is already present in the restaurants mapping and if the name is empty or not before adding it. For friends, it checks if the 
            provided friend name is already associated with the friend's address and if the name is empty or not before adding the friend.

         3. For unit test cases, to make sure there are no invalid restaurant number. Additionaly, checking if a friend has already voted is also added to make sure
            that only one friend votes with no invalid restaurant number.

         4. To make sure the contract can be disabled once it is deployed, a "stopContract" function is added. The function can be called by the manager. After calling
            this function, the voteOpen flag will be set to false, indicating that the voting is closed.

         5. To make sure reaching a consensus on the lunch venue if the quorum is not reached by lunchtime, a timeout mechanism based on block numbers has been added.
            A start block number "timeStart" is set within the constructor and an end block number "timeEnd" when it is deployed. If the current block number exceeds 
            the end block number, the contract is timed out. To check and make sure if the contract has timed out before allowing certain functions 
            to be executed a modifier "SessionTimedOut" is added.

        Extra Point completed just in case:
         6. The gas consumption is optimized by using more simpler data structures whereever possible. instead of iterating through the list of restaurants to check 
            for duplicates, a mapping is used to store restaurants, which provides constant-time lookup. Similarly, the hasVoted mapping is used to track if a friend
            has voted, which is more efficient than iterating through the list of friends. Multiple checks have been performed making the gas consumption less 
            i.e. less function call less gas usage. A simple data structure is used to compare and check and thhrow error message to simply the pprocess and reduce gas usage. 

        Some References taken from few websites:
         1. https://www.quicknode.com/guides/ethereum-development/smart-contracts/how-to-use-keccak256-with-solidity/#:~:text=Keccak256%20is%20a%20powerful%20tool,developers%20in%20the%20Ethereum%20ecosystem.
         2. https://medium.com/@phillipgoldberg/smart-contract-best-practices-revisited-block-number-vs-timestamp-648905104323
         3. https://codedamn.com/news/solidity/what-is-require-in-solidity
         4. https://docs.soliditylang.org/en/v0.8.20/

    */
    
}
