// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {ZoraModuleManager} from "../../../ZoraModuleManager.sol";
import {LibDiamond} from "../../../common/DiamondPermanentSelectors/libraries/LibDiamond.sol";
import {LibMeta} from "../../../common/DiamondPermanentSelectors/libraries/LibMeta.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {IAsks} from "../interfaces/IAsks.sol";
import {ReentrancyGuardDiamond} from "../../../common/DiamondPermanentSelectors/utils/ReentrancyGuardDiamond.sol";
import {TransferAndPayoutSupportV1} from "../../../common/DiamondPermanentSelectors/libraries/TransferAndPayoutSupportV1.sol";

contract AsksFacet is ReentrancyGuardDiamond, TransferAndPayoutSupportV1 {
    /// @notice Recovers the signer of the ask
    /// @param _ask The signed gasless ask
    /// @param _v The 129th byte and chain ID of the signature
    /// @param _r The first 64 bytes of the signature
    /// @param _s Bytes 64-128 of the signature
    function _recoverAddress(
        IAsks.SignedAsk calldata _ask,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) private view returns (address) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                s.EIP_712_DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        s.SIGNED_ASK_TYPEHASH,
                        _ask.tokenContract,
                        _ask.tokenId,
                        _ask.currency,
                        _ask.price,
                        _ask.findersFeeBps,
                        _ask.expiry,
                        _ask.nonce
                    )
                )
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
    event AskFilled(IAsks.SignedAsk ask, address buyer, address finder);

    /// @notice Fills the given signed ask for an NFT
    /// @param _ask The signed ask to fill
    /// @param _v The 129th byte and chain ID of the signature
    /// @param _r The first 64 bytes of the signature
    /// @param _s Bytes 64-128 of the signature
    function fillAsk(
        IAsks.SignedAsk calldata _ask,
        address _finder,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external payable nonReentrant {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();

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

        address currency = _ask.currency;

        uint256 price = _ask.price;

        // Ensure the ask nonce matches the token nonce
        require(_ask.nonce == s.SIGNED_ASKS_nonce[seller][tokenContract][tokenId], "INVALID_ASK");

        // Ensure the attached ETH matches the price
        if (currency == address(0)) {
            require(msg.value == price, "MUST_MATCH_PRICE");
        }

        // Ensure ETH/ERC-20 payment from buyer is valid and take custody
        _handleIncomingTransfer(price, currency);

        // Payout associated token royalties, if any
        (uint256 remainingProfit, ) = _handleRoyaltyPayout(tokenContract, tokenId, price, currency, 300000);

        // Payout the module fee, if configured
        remainingProfit = _handleProtocolFeePayout(remainingProfit, currency);

        // Payout optional finder fee
        if (_finder != address(0)) {
            uint256 findersFee = (remainingProfit * _ask.findersFeeBps) / 10000;
            _handleOutgoingTransfer(_finder, findersFee, currency, LibAppStorage.USE_ALL_GAS_FLAG);

            remainingProfit = remainingProfit - findersFee;
        }

        // Transfer the remaining profit to the seller
        _handleOutgoingTransfer(seller, remainingProfit, currency, 50000);

        // Transfer the NFT to the buyer
        // Reverts if the seller did not approve the ERC721TransferHelper or no longer owns the token
        ds.erc721TransferHelper.transferFrom(tokenContract, seller, LibMeta.msgSender(), tokenId);

        emit AskFilled(_ask, LibMeta.msgSender(), _finder);

        // Increment the nonce for the associated token
        // Cannot realistically overflow
        unchecked {
            ++s.SIGNED_ASKS_nonce[seller][tokenContract][tokenId];
        }
    }

    ///                                                          ///
    ///                        CANCEL ASK                        ///
    ///                                                          ///

    /// @notice Emitted when an ask is canceled
    /// @param seller The caller of cancelAsk
    /// @param tokenContract The token contract
    /// @param tokenId The token id
    /// @param oldNonce The previous nonce for that seller's token
    event AskCanceled(address seller, address tokenContract, uint256 tokenId, uint256 oldNonce);

    /// @notice Invalidates an off-chain order for a seller
    /// @param _tokenContract The token contract
    /// @param _tokenId The token id

    function cancelAsk(address _tokenContract, uint256 _tokenId) external nonReentrant {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        uint256 oldNonce;
        // Increment msg.sender's nonce for the associated token
        // Cannot realistically overflow
        unchecked {
            oldNonce = ++s.SIGNED_ASKS_nonce[LibMeta.msgSender()][_tokenContract][_tokenId];
        }

        emit AskCanceled(LibMeta.msgSender(), _tokenContract, _tokenId, oldNonce);
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
        IAsks.SignedAsk calldata _ask,
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
        IAsks.SignedAsk calldata _ask,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external view returns (bool) {
        return _recoverAddress(_ask, _v, _r, _s) == _ask.seller;
    }
}
