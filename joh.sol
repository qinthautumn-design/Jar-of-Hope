// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title WishBoard
 * @notice On-chain wish board. Users pay a small amount of BOT to post a wish,
 *         other wallets can vote on their favorite wishes (Community Poll),
 *         and anyone can tip a wisher directly to support them (Tip Board).
 *
 *         The "Trending Wishes" and "Milestone Counter" features need NOTHING
 *         extra in this contract — they're pure sorting/animation logic on the
 *         frontend, since all the data (voteCount, total wish count) is already here.
 */
contract WishBoard {

    // ---------------------------------------------------------------
    // STATE VARIABLES
    // ---------------------------------------------------------------

    address public owner;

    // Price to post 1 wish (in wei — the smallest unit of BOT, same as ETH)
    // 0.001 BOT = 1e15 wei. Owner can change this later if needed.
    uint256 public wishPrice = 0.001 ether;

    struct Wish {
        address wisher;      // who posted it
        string message;      // the wish text
        uint256 timestamp;   // when it was posted
        uint256 voteCount;   // how many people voted for this wish
    }

    // All wishes are stored in this array, index 0, 1, 2, and so on
    Wish[] public wishes;

    // Tracks who has voted on which wish, so nobody can vote twice
    // wishIndex => (voter address => has voted or not)
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // Total BOT tipped to each wish (wishIndex => total amount in wei)
    mapping(uint256 => uint256) public totalTipped;

    // Total BOT a given address has tipped, across all wishes (used for a "Top Tipper" leaderboard)
    mapping(address => uint256) public tipperTotal;

    // ---------------------------------------------------------------
    // EVENTS — used to "notify" the frontend when a new transaction happens
    // ---------------------------------------------------------------

    event WishMade(uint256 indexed wishIndex, address indexed wisher, string message, uint256 timestamp);
    event WishVoted(uint256 indexed wishIndex, address indexed voter, uint256 newVoteCount);
    event WishTipped(uint256 indexed wishIndex, address indexed tipper, address indexed wisher, uint256 amount);

    // ---------------------------------------------------------------
    // CONSTRUCTOR — runs once, when the contract is deployed
    // ---------------------------------------------------------------

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can do this");
        _;
    }

    // ---------------------------------------------------------------
    // WRITE FUNCTIONS — require gas + MetaMask approval
    // ---------------------------------------------------------------

    /**
     * @notice Post a new wish. The user must send BOT >= wishPrice.
     * @param message The wish text (capped at 200 characters to save gas)
     */
    function makeWish(string calldata message) external payable {
        require(msg.value >= wishPrice, "Sent BOT is less than the wish price");
        require(bytes(message).length > 0, "Wish cannot be empty");
        require(bytes(message).length <= 200, "Wish must be 200 characters or fewer");

        wishes.push(Wish({
            wisher: msg.sender,
            message: message,
            timestamp: block.timestamp,
            voteCount: 0
        }));

        uint256 newIndex = wishes.length - 1;
        emit WishMade(newIndex, msg.sender, message, block.timestamp);
    }

    /**
     * @notice Vote for a wish. Each wallet can only vote once per wish.
     * @param wishIndex Index of the wish to vote for (starting from 0)
     */
    function voteWish(uint256 wishIndex) external {
        require(wishIndex < wishes.length, "Wish not found");
        require(!hasVoted[wishIndex][msg.sender], "You already voted for this wish");

        hasVoted[wishIndex][msg.sender] = true;
        wishes[wishIndex].voteCount += 1;

        emit WishVoted(wishIndex, msg.sender, wishes[wishIndex].voteCount);
    }

    /**
     * @notice Tip BOT directly to the person who posted a wish, as a show of support.
     *         The BOT goes straight to the wisher's wallet — it never sits in this contract.
     * @param wishIndex Index of the wish to tip
     */
    function tipWish(uint256 wishIndex) external payable {
        require(wishIndex < wishes.length, "Wish not found");
        require(msg.value > 0, "Tip must be greater than 0");

        address wisher = wishes[wishIndex].wisher;
        require(wisher != msg.sender, "You cannot tip your own wish");

        totalTipped[wishIndex] += msg.value;
        tipperTotal[msg.sender] += msg.value;

        (bool success, ) = payable(wisher).call{value: msg.value}("");
require(success, "Transfer failed");

        emit WishTipped(wishIndex, msg.sender, wisher, msg.value);
    }

    /**
     * @notice Owner can withdraw the BOT collected from wish payments.
     *         (Optional — remove this if you don't need it)
     */
    function withdraw() external onlyOwner {
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
require(success, "Transfer failed");
    }

    // ---------------------------------------------------------------
    // READ FUNCTIONS — free, no gas, no MetaMask approval needed
    // ---------------------------------------------------------------

    /// @notice Total number of wishes posted so far
    function getWishCount() external view returns (uint256) {
        return wishes.length;
    }

    /// @notice Get the details of one wish by its index
    function getWish(uint256 index) external view returns (
        address wisher,
        string memory message,
        uint256 timestamp,
        uint256 voteCount
    ) {
        require(index < wishes.length, "Wish not found");
        Wish memory w = wishes[index];
        return (w.wisher, w.message, w.timestamp, w.voteCount);
    }

    /// @notice Check whether a given address has already voted for a given wish
    function hasVotedFor(uint256 wishIndex, address voter) external view returns (bool) {
        return hasVoted[wishIndex][voter];
    }
}
