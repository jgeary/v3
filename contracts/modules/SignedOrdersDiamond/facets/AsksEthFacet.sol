// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {LibDiamond} from "../../../common/DiamondPermanentSelectors/libraries/LibDiamond.sol";
import {AppStorage, Modifiers} from "../libraries/LibAppStorage.sol";

contract AsksEthFacet is Modifiers {
    AppStorage internal s;

    /// @notice Recovers the signer of the ask
    /// @param _ask The signed gasless ask
    /// @param _v The 129th byte and chain ID of the signature
    /// @param _r The first 64 bytes of the signature
    /// @param _s Bytes 64-128 of the signature
    function _recoverAddress(
        IAsksGaslessEth.GaslessAsk calldata _ask,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) private view returns (address) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                s.signedAsksEth.EIP_712_DOMAIN_SEPARATOR,
                keccak256(abi.encode(s.signedAsksEth.SIGNED_ASK_TYPEHASH, _ask.tokenContract, _ask.tokenId, _ask.expiry, _ask.nonce, _ask.price))
            )
        );

        return ecrecover(digest, _v, _r, _s);
    }

    ///                                                          ///
    ///                         FILL ASK                         ///
    ///                                                          ///

    /// @notice Emitted when a signed ask is filled
    /// @param ask The metadata of the ask
    /// @param buyer The address of the buyer
    event AskFilled(IAsksGaslessEth.GaslessAsk ask, address buyer);

    /// @notice Fills the given signed ask for an NFT
    /// @param _ask The signed ask to fill
    /// @param _v The 129th byte and chain ID of the signature
    /// @param _r The first 64 bytes of the signature
    /// @param _s Bytes 64-128 of the signature
    function fillAsk(
        IAsksGaslessEth.GaslessAsk calldata _ask,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external payable nonReentrant {
        // Ensure the ask has not expired
        require(_ask.expiry == 0 || _ask.expiry >= block.timestamp, "EXPIRED_ASK");

        // Recover the signer address
        address recoveredAddress = _recoverAddress(_ask, _v, _r, _s);

        // Cache the seller address
        address seller = _ask.seller;

        // Ensure the recovered signer matches the seller
        require(recoveredAddress == seller, "INVALID_SIG");

        // Cache the token contract
        address tokenContract = _ask.tokenContract;

        // Cache the token id
        uint256 tokenId = _ask.tokenId;

        // Ensure the ask nonce matches the token nonce
        require(_ask.nonce == s.signedAsksEth.nonce[tokenContract][tokenId], "INVALID_ASK");

        // Ensure the attached ETH matches the price
        require(msg.value == _ask.price, "MUST_MATCH_PRICE");

        // Payout associated token royalties, if any
        (uint256 remainingProfit, ) = _handleRoyaltyPayout(tokenContract, tokenId, _ask.price, address(0), 300000);

        // Payout the module fee, if configured
        remainingProfit = _handleProtocolFeePayout(remainingProfit, address(0));

        // Transfer the remaining profit to the seller
        _handleOutgoingTransfer(seller, remainingProfit, address(0), 50000);

        // Transfer the NFT to the buyer
        // Reverts if the seller did not approve the ERC721TransferHelper or no longer owns the token
        s.erc721TransferHelper.transferFrom(tokenContract, seller, msg.sender, tokenId);

        emit AskFilled(_ask, msg.sender);

        // Increment the nonce for the associated token
        // Cannot realistically overflow
        unchecked {
            ++s.signedAsksEth.nonce[tokenContract][tokenId];
        }
    }

    /// @notice Fills the given signed ask for an NFT with a signed module approval
    /// @param _ask The signed ask to fill
    /// @param _approvalSig The signed module approval
    /// @param _v The 129th byte and chain ID of the signature
    /// @param _r The first 64 bytes of the signature
    /// @param _s Bytes 64-128 of the signature
    function fillAsk(
        IAsksGaslessEth.GaslessAsk calldata _ask,
        IAsksGaslessEth.ModuleApprovalSig calldata _approvalSig,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external payable nonReentrant {
        // Ensure the ask has not expired
        require(_ask.expiry == 0 || _ask.expiry >= block.timestamp, "EXPIRED_ASK");

        // Recover the signer address
        address recoveredAddress = _recoverAddress(_ask, _v, _r, _s);

        // Cache the seller address
        address seller = _ask.seller;

        // Ensure the recovered signer matches the seller
        require(recoveredAddress == seller, "INVALID_SIG");

        // Cache the token contract
        address tokenContract = _ask.tokenContract;

        // Cache the token id
        uint256 tokenId = _ask.tokenId;

        // Ensure the ask nonce matches the token nonce
        require(_ask.nonce == s.signedAsksEth.nonce[tokenContract][tokenId], "INVALID_ASK");

        // Ensure the attached ETH matches the price
        require(msg.value == _ask.price, "MUST_MATCH_PRICE");

        // If the seller has not approved this module in the ZORA Module Manager,
        if (!s.ZMM.isModuleApproved(seller, address(this))) {
            // Approve the module on behalf of the seller
            s.ZMM.setApprovalForModuleBySig(address(this), seller, true, _approvalSig.deadline, _approvalSig.v, _approvalSig.r, _approvalSig.s);
        }

        // TODO: diamond friendly payouts
        // Payout associated token royalties, if any
        // (uint256 remainingProfit, ) = _handleRoyaltyPayout(tokenContract, tokenId, _ask.price, address(0), 300000);
        // Payout the module fee, if configured
        // remainingProfit = _handleProtocolFeePayout(remainingProfit, address(0));

        // Transfer the remaining profit to the seller
        _handleOutgoingTransfer(seller, _ask.price, address(0), 50000);

        // Transfer the NFT to the buyer
        // Reverts if the seller did not approve the ERC721TransferHelper or no longer owns the token
        s.erc721TransferHelper.transferFrom(tokenContract, seller, msg.sender, tokenId);

        emit AskFilled(_ask, msg.sender);

        // Increment the nonce for the associated token
        // Cannot realistically overflow
        unchecked {
            ++s.signedAsksEth.nonce[tokenContract][tokenId];
        }
    }

    ///                                                          ///
    ///                        CANCEL ASK                        ///
    ///                                                          ///

    /// @notice Emitted when an ask is canceled
    /// @param ask The metadata of the ask
    event AskCanceled(IAsksGaslessEth.GaslessAsk ask);

    /// @notice Invalidates an off-chain order
    /// @param _ask The signed ask parameters to invalidate
    function cancelAsk(IAsksGaslessEth.GaslessAsk calldata _ask) external nonReentrant {
        // Ensure the caller is the seller
        require(msg.sender == _ask.seller, "ONLY_SIGNER");

        // Increment the nonce for the associated token
        // Cannot realistically overflow
        unchecked {
            ++s.signedAsksEth.nonce[_ask.tokenContract][_ask.tokenId];
        }

        emit AskCanceled(_ask);
    }

    ///                                                          ///
    ///                       BROADCAST ASK                      ///
    ///                                                          ///

    /// @notice Broadcasts an order on-chain to indexers
    /// @dev Intentionally a no-op, this can be picked up via EVM traces :)
    /// @param _ask The signed ask parameters to broadcast
    /// @param _v The 129th byte and chain ID of the signature
    /// @param _r The first 64 bytes of the signature
    /// @param _s Bytes 64-128 of the signature
    function broadcastAsk(
        IAsksGaslessEth.GaslessAsk calldata _ask,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        // noop :)
    }

    ///                                                          ///
    ///                       VALIDATE ASK                       ///
    ///                                                          ///

    /// @notice Checks if a given signature matches the signer of given ask
    /// @param _ask The signed ask parameters to validate
    /// @param _v The 129th byte and chain ID of the signature
    /// @param _r The first 64 bytes of the signature
    /// @param _s Bytes 64-128 of the signature
    /// @return If the given signature matches the ask signature
    function validateAskSig(
        IAsksGaslessEth.GaslessAsk calldata _ask,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external view returns (bool) {
        return _recoverAddress(_ask, _v, _r, _s) == _ask.seller;
    }
}
