// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

interface IAsks {
    struct Signature {
        uint8 v; // The 129th byte and chain ID of the signature
        bytes32 r; // The first 64 bytes of the signature
        bytes32 s; // Bytes 64-128 of the signature
    }

    struct ModuleApprovalSig {
        Signature sig;
        uint256 deadline; // The deadline at which point the approval expires
    }

    struct SignedAsk {
        address seller; // The address of the seller
        address tokenContract; // The address of the NFT being sold
        uint256 tokenId;
        address currency;
        uint256 price;
        uint16 findersFeeBps;
        uint256 expiry; // The Unix timestamp that this order expires at
        uint256 nonce; // The ID to represent this order (for cancellations)
    }

    /// @notice Fills the given signed ask for an NFT
    /// @param _ask The signed ask to fill
    /// @param _v The 129th byte and chain ID of the signature
    /// @param _r The first 64 bytes of the signature
    /// @param _s Bytes 64-128 of the signature
    function fillAsk(
        IAsks.SignedAsk calldata _ask,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external payable;

    /// @notice Fills the given signed ask for an NFT with a signed module approval
    /// @param _ask The signed ask to fill
    /// @param _approvalSig The signed module approval
    /// @param _v The 129th byte and chain ID of the signature
    /// @param _r The first 64 bytes of the signature
    /// @param _s Bytes 64-128 of the signature
    function fillAsk(
        IAsks.SignedAsk calldata _ask,
        IAsks.ModuleApprovalSig calldata _approvalSig,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external payable;

    /// @notice Invalidates an off-chain order
    /// @param _ask The signed ask parameters to invalidate
    function cancelAsk(IAsks.SignedAsk calldata _ask) external;

    /// @notice Broadcasts an order on-chain to indexers
    /// @dev Intentionally a no-op, this can be picked up via EVM traces :)
    /// @param _ask The signed ask parameters to broadcast
    /// @param _v The 129th byte and chain ID of the signature
    /// @param _r The first 64 bytes of the signature
    /// @param _s Bytes 64-128 of the signature
    function broadcastAsk(
        IAsks.SignedAsk calldata _ask,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    /// @notice Checks if a given signature matches the signer of given ask
    /// @param _ask The signed ask parameters to validate
    /// @param _v The 129th byte and chain ID of the signature
    /// @param _r The first 64 bytes of the signature
    /// @param _s Bytes 64-128 of the signature
    /// @return If the given signature matches the ask signature
    function validateAskSig(
        IAsks.SignedAsk calldata _ask,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external view returns (bool);
}
