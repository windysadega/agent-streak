// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

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
