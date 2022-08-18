// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.9.0;

contract Auction {
    address payable public owner;
    uint public start;
    uint public end;
    string public ipfsHash;
    enum State {
        Started,
        Running,
        Ended,
        Canceled
    }
    State public auctionState;
    uint public highestBindingBid;
    address payable public highestBidder;
    uint bidIncrement;

    mapping(address => uint) public bids;

    constructor(address eoa) {
        owner = payable(eoa);
        auctionState = State.Running;
        start = block.number;
        // end = start + 40320;
        end = start + 3;
        ipfsHash = "";
        // bidIncrement = 100;
        bidIncrement = 1000000000000000000;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier notOwner() {
        require(msg.sender != owner);
        _;
    }

    modifier afterStart() {
        require(block.number >= start);
        _;
    }

    modifier beforeEnd() {
        require(block.number <= end);
        _;
    }

    function cancelAuction() public onlyOwner {
        auctionState = State.Canceled;
    }

    function min(uint value1, uint value2) internal pure returns(uint) {
        if (value1 <= value2) {
            return value1;
        } else {
            return value2;
        }
    }

    function placeBid() public payable notOwner afterStart beforeEnd {
        require(auctionState == State.Running);
        // require(msg.value >= 100);
        require(msg.value >= 1000000000000000000);
        uint currentBid = bids[msg.sender] + msg.value;
        require(currentBid > highestBindingBid);
        bids[msg.sender] = currentBid;

        if (currentBid <= bids[highestBidder]) {
            highestBindingBid = min(currentBid + bidIncrement, bids[highestBidder]);
        } else {
            highestBindingBid = min(currentBid, bids[highestBidder] + bidIncrement);
            highestBidder = payable(msg.sender);
        }
    }

    function finalizeAuction() public {
        require(auctionState == State.Canceled || block.number > end);
        require(msg.sender == owner || bids[msg.sender] > 0);

        address payable recipient;
        uint value;

        if (auctionState == State.Canceled) {
            recipient = payable(msg.sender);
            value = bids[msg.sender];
        } else {
            if (msg.sender == owner) {
                recipient = owner;
                value = highestBindingBid;
            } else {
                if (msg.sender == highestBidder) {
                    recipient = highestBidder;
                    value = bids[highestBidder] - highestBindingBid;
                } else {
                    recipient = payable(msg.sender);
                    value = bids[msg.sender];
                }
            }
        }
        bids[recipient] = 0;

        recipient.transfer(value);
    }
}

contract AuctionCreator {
    mapping(address => Auction[]) public auctions;
    Auction[] public deployedAuctions;

    function deployAuction() public {
        Auction newAuction = new Auction(msg.sender);
        deployedAuctions.push(newAuction);
        if (auctions[msg.sender].length > 0) {
            Auction[] storage userAuctions = auctions[msg.sender];
            userAuctions.push(newAuction);
            auctions[msg.sender] = userAuctions;
        } else {
            auctions[msg.sender] = [newAuction];
        }
    }

    function getUserAuctions(address add) public view returns(Auction[] memory) {
        return auctions[add];
    }
}
