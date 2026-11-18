// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// contracts/src/AgentGate.sol

/// @notice Minimal read interface of the SPACE ID Agent ID contract (BSC mainnet
///         0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F). Verified against the live
///         contract: balanceOf(avelin holder) = 1, handleOf(holder) = "avelin".
interface IAgentID {
    function balanceOf(address owner) external view returns (uint256);
    function handleOf(address owner) external view returns (string memory);
    function ownerOfHandle(string calldata handle) external view returns (address);
}

/// @notice Shared Agent ID gate for the Agent Streak suite.
///         Every state-changing entry point passes through `onlyAgent`:
///         the caller must hold an Agent ID (SPACE ID "AI" NFT, soulbound,
///         one per person) on BNB Chain. The Agent ID contract address is set
///         once at deployment and is immutable.
abstract contract AgentGate {
    IAgentID public immutable AGENT_ID;

    error NoAgentId(address caller);

    constructor(address agentId_) {
        AGENT_ID = IAgentID(agentId_);
    }

    modifier onlyAgent() {
        _requireAgent(msg.sender);
        _;
    }

    function _requireAgent(address who) internal view {
        if (AGENT_ID.balanceOf(who) == 0) revert NoAgentId(who);
    }

    /// @notice True if `who` currently holds an Agent ID.
    function isAgent(address who) external view returns (bool) {
        return AGENT_ID.balanceOf(who) > 0;
    }

    /// @notice The Agent ID handle (without ".ai") of an address, read on-chain.
    function handleOf(address who) external view returns (string memory) {
        return AGENT_ID.handleOf(who);
    }

    /// @notice The caller's own Agent ID handle.
    function myHandle() external view returns (string memory) {
        return AGENT_ID.handleOf(msg.sender);
    }
}

// contracts/src/AgentStreakBadge.sol

interface ICheckInStats {
    function totalCheckInsOf(address who) external view returns (uint64);
    function bestStreakOf(address who) external view returns (uint32);
}

/// @title Agent Streak Badge — soulbound milestone NFT
/// @notice Free-mint milestone badges for Agent ID holders, earned through
///         the Agent Streak check-in contract:
///           tier 1 — first check-in completed
///           tier 2 — best streak of 7 days or more
///           tier 3 — best streak of 21 days or more
///         Minting is free (no payment, no approval), one badge per
///         (holder, tier), and badges are SOULBOUND: every transfer and
///         approval function reverts. A badge is a proof of repeated
///         attendance, not a financial asset; it cannot be sold or moved.
/// @dev Owner powers are limited to ONE thing: setting the metadata
///      base URI (setBaseURI). There is no admin mint, no withdraw, no
///      pause, no fee, and the contract never holds funds.
contract AgentStreakBadge is AgentGate {
    string public name = "Agent Streak Badge";
    string public symbol = "ASTRK";

    uint8 public constant TIER_COUNT = 3;
    uint64 public constant TIER1_MIN_CHECKINS = 1;
    uint32 public constant TIER2_MIN_BEST_STREAK = 7;
    uint32 public constant TIER3_MIN_BEST_STREAK = 21;

    ICheckInStats public immutable checkIn;
    address public owner;
    string public baseURI;

    uint256 private _nextId = 1;
    mapping(uint256 => address) private _ownerOfToken;
    mapping(uint256 => uint8) public tierOf;
    mapping(address => mapping(uint8 => bool)) public hasTier;
    mapping(address => uint256) private _balances;

    event BadgeMinted(address indexed holder, uint8 indexed tier, uint256 tokenId);
    event BaseURISet(string baseURI);

    error Soulbound();
    error NotOwner();
    error InvalidTier(uint8 tier);
    error AlreadyClaimed(address holder, uint8 tier);
    error MilestoneNotReached(address holder, uint8 tier);
    error NonexistentToken(uint256 tokenId);

    constructor(address agentId_, address checkIn_, address owner_, string memory baseURI_)
        AgentGate(agentId_)
    {
        checkIn = ICheckInStats(checkIn_);
        owner = owner_;
        baseURI = baseURI_;
    }

    /// @notice True if `who` has reached the milestone for `tier`
    ///         (regardless of whether the badge was already claimed).
    function eligible(address who, uint8 tier) public view returns (bool) {
        if (tier == 1) return checkIn.totalCheckInsOf(who) >= TIER1_MIN_CHECKINS;
        if (tier == 2) return checkIn.bestStreakOf(who) >= TIER2_MIN_BEST_STREAK;
        if (tier == 3) return checkIn.bestStreakOf(who) >= TIER3_MIN_BEST_STREAK;
        return false;
    }

    /// @notice Claim the badge for a reached milestone tier. Free.
    ///         Agent ID holders only; one per (holder, tier).
    function mint(uint8 tier) external onlyAgent returns (uint256 id) {
        if (tier < 1 || tier > TIER_COUNT) revert InvalidTier(tier);
        if (hasTier[msg.sender][tier]) revert AlreadyClaimed(msg.sender, tier);
        if (!eligible(msg.sender, tier)) revert MilestoneNotReached(msg.sender, tier);
        hasTier[msg.sender][tier] = true;
        id = _nextId++;
        _ownerOfToken[id] = msg.sender;
        tierOf[id] = tier;
        _balances[msg.sender] += 1;
        emit BadgeMinted(msg.sender, tier, id);
    }

    /// @notice The ONLY owner power: point token metadata at its host.
    function setBaseURI(string calldata uri) external {
        if (msg.sender != owner) revert NotOwner();
        baseURI = uri;
        emit BaseURISet(uri);
    }

    // --- ERC-721 reads ---

    function balanceOf(address who) external view returns (uint256) {
        return _balances[who];
    }

    function ownerOf(uint256 id) external view returns (address) {
        address o = _ownerOfToken[id];
        if (o == address(0)) revert NonexistentToken(id);
        return o;
    }

    /// @notice Metadata is per-tier: baseURI + "<tier>.json"
    ///         (e.g. https://…/metadata/1.json). All badges of a tier share
    ///         one metadata file describing that milestone.
    function tokenURI(uint256 id) external view returns (string memory) {
        if (_ownerOfToken[id] == address(0)) revert NonexistentToken(id);
        if (bytes(baseURI).length == 0) return "";
        return string(abi.encodePacked(baseURI, _toString(tierOf[id]), ".json"));
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd || id == 0x5b5e139f || id == 0x01ffc9a7;
    }

    // --- soulbound: every transfer / approval path reverts ---

    function transferFrom(address, address, uint256) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address, address, uint256) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address, address, uint256, bytes calldata) external pure {
        revert Soulbound();
    }

    function approve(address, uint256) external pure {
        revert Soulbound();
    }

    function setApprovalForAll(address, bool) external pure {
        revert Soulbound();
    }

    function getApproved(uint256) external pure returns (address) {
        return address(0);
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return false;
    }

    function _toString(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 t = v;
        uint256 d;
        while (t != 0) {
            d++;
            t /= 10;
        }
        bytes memory b = new bytes(d);
        while (v != 0) {
            b[--d] = bytes1(uint8(48 + (v % 10)));
            v /= 10;
        }
        return string(b);
    }
}

