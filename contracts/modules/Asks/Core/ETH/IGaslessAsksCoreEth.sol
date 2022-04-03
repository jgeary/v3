// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {ModuleApprovalSig} from "../../../../ZoraModuleManager.sol";

interface IGaslessAsksCoreEth {
    struct GaslessAsk {
        address from; // The address of the seller
        address tokenAddress; // The address of the NFT being sold
        uint256 tokenId; // The ID of the NFT being sold
        uint256 expiry; // The Unix timestamp that this order expires at
        uint256 nonce; // Nonce to represent this order (for cancellations)
        uint256 amount; // The amount of ETH to sell the NFT for
        ModuleApprovalSig approvalSig; // The user's approval to use this module (optional, empty if already set)
    }

    function executeAsk(
        GaslessAsk calldata _ask,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external payable;

    function storeAsk(
        GaslessAsk calldata _ask,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    function broadcastAsk(
        GaslessAsk calldata _ask,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    function cancelAsk(GaslessAsk calldata _ask) external;

    function validateAskSig(
        GaslessAsk calldata _ask,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external view returns (bool);
}