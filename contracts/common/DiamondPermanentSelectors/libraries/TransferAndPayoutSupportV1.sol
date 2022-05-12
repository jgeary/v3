// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibMeta} from "../libraries/LibMeta.sol";

/// @title OutgoingTransferSupportV1
/// @author tbtstl <t@zora.co>
/// @notice This contract extension supports paying out funds to an external recipient
contract TransferAndPayoutSupportV1 {
    using SafeERC20 for IERC20;

    /// @notice Handle an outgoing funds transfer
    /// @dev Wraps ETH in WETH if the receiver cannot receive ETH, noop if the funds to be sent are 0 or recipient is invalid
    /// @param _dest The destination for the funds
    /// @param _amount The amount to be sent
    /// @param _currency The currency to send funds in, or address(0) for ETH
    /// @param _gasLimit The gas limit to use when attempting a payment (if 0, gasleft() is used)
    function _handleOutgoingTransfer(
        address _dest,
        uint256 _amount,
        address _currency,
        uint256 _gasLimit
    ) internal {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (_amount == 0 || _dest == address(0)) {
            return;
        }

        // Handle ETH payment
        if (_currency == address(0)) {
            require(address(this).balance >= _amount, "_handleOutgoingTransfer insolvent");

            // If no gas limit was provided or provided gas limit greater than gas left, just use the remaining gas.
            uint256 gas = (_gasLimit == 0 || _gasLimit > gasleft()) ? gasleft() : _gasLimit;
            (bool success, ) = _dest.call{value: _amount, gas: gas}("");
            // If the ETH transfer fails (sigh), wrap the ETH and try send it as WETH.
            if (!success) {
                ds.weth.deposit{value: _amount}();
                IERC20(address(ds.weth)).safeTransfer(_dest, _amount);
            }
        } else {
            IERC20(_currency).safeTransfer(_dest, _amount);
        }
    }

    /// @notice Handle an incoming funds transfer, ensuring the sent amount is valid and the sender is solvent
    /// @param _amount The amount to be received
    /// @param _currency The currency to receive funds in, or address(0) for ETH
    function _handleIncomingTransfer(uint256 _amount, address _currency) internal {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (_currency == address(0)) {
            require(msg.value >= _amount, "_handleIncomingTransfer msg value less than expected amount");
        } else {
            // We must check the balance that was actually transferred to this contract,
            // as some tokens impose a transfer fee and would not actually transfer the
            // full amount to the market, resulting in potentally locked funds
            IERC20 token = IERC20(_currency);
            uint256 beforeBalance = token.balanceOf(address(this));
            ds.erc20TransferHelper.safeTransferFrom(_currency, LibMeta.msgSender(), address(this), _amount);
            uint256 afterBalance = token.balanceOf(address(this));
            require(beforeBalance + _amount == afterBalance, "_handleIncomingTransfer token transfer call did not transfer expected amount");
        }
    }

    event RoyaltyPayout(address indexed tokenContract, uint256 indexed tokenId, address recipient, uint256 amount);

    /// @notice Pays out the protocol fee to its fee recipient
    /// @param _amount The sale amount
    /// @param _payoutCurrency The currency to pay the fee
    /// @return The remaining funds after paying the protocol fee
    function _handleProtocolFeePayout(uint256 _amount, address _payoutCurrency) internal returns (uint256) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        // Get fee for this module
        uint256 protocolFee = ds.zoraProtocolFeeSettings.getFeeAmount(address(this), _amount);

        // If no fee, return initial amount
        if (protocolFee == 0) return _amount;

        // Get fee recipient
        (, address feeRecipient) = ds.zoraProtocolFeeSettings.moduleFeeSetting(address(this));

        // Payout protocol fee
        _handleOutgoingTransfer(feeRecipient, protocolFee, _payoutCurrency, 50000);

        // Return remaining amount
        return _amount - protocolFee;
    }

    /// @notice Pays out royalties for NFTs based on the information returned by the royalty engine
    /// @dev This method is external to enable setting a gas limit when called - see `_handleRoyaltyPayout`.
    /// @param _tokenContract The NFT Contract to get royalty information from
    /// @param _tokenId, The Token ID to get royalty information from
    /// @param _amount The total sale amount
    /// @param _payoutCurrency The ERC-20 token address to payout royalties in, or address(0) for ETH
    /// @return The remaining funds after paying out royalties
    function _handleRoyaltyEnginePayout(
        address _tokenContract,
        uint256 _tokenId,
        uint256 _amount,
        address _payoutCurrency
    ) external payable returns (uint256) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        // Ensure the caller is the contract
        require(LibMeta.msgSender() == address(this), "_handleRoyaltyEnginePayout only self callable");

        // Get the royalty recipients and their associated amounts
        (address payable[] memory recipients, uint256[] memory amounts) = ds.royaltyEngine.getRoyalty(_tokenContract, _tokenId, _amount);

        // Store the number of recipients
        uint256 numRecipients = recipients.length;

        // If there are no royalties, return the initial amount
        if (numRecipients == 0) return _amount;

        // Store the initial amount
        uint256 amountRemaining = _amount;

        // Store the variables that cache each recipient and amount
        address recipient;
        uint256 amount;

        // Payout each royalty
        for (uint256 i = 0; i < numRecipients; ) {
            // Cache the recipient and amount
            recipient = recipients[i];
            amount = amounts[i];

            // Ensure that we aren't somehow paying out more than we have
            require(amountRemaining >= amount, "insolvent");

            // Transfer to the recipient
            _handleOutgoingTransfer(recipient, amount, _payoutCurrency, 50000);

            emit RoyaltyPayout(_tokenContract, _tokenId, recipient, amount);

            // Cannot underflow as remaining amount is ensured to be greater than or equal to royalty amount
            unchecked {
                amountRemaining -= amount;
                ++i;
            }
        }

        return amountRemaining;
    }

    /// @notice Pays out royalties for given NFTs
    /// @param _tokenContract The NFT contract address to get royalty information from
    /// @param _tokenId, The Token ID to get royalty information from
    /// @param _amount The total sale amount
    /// @param _payoutCurrency The ERC-20 token address to payout royalties in, or address(0) for ETH
    /// @param _gasLimit The gas limit to use when attempting to payout royalties. Uses gasleft() if not provided.
    /// @return The remaining funds after paying out royalties
    function _handleRoyaltyPayout(
        address _tokenContract,
        uint256 _tokenId,
        uint256 _amount,
        address _payoutCurrency,
        uint256 _gasLimit
    ) internal returns (uint256, bool) {
        // If no gas limit was provided or provided gas limit greater than gas left, just pass the remaining gas.
        uint256 gas = (_gasLimit == 0 || _gasLimit > gasleft()) ? gasleft() : _gasLimit;

        // External call ensuring contract doesn't run out of gas paying royalties
        try this._handleRoyaltyEnginePayout{gas: gas}(_tokenContract, _tokenId, _amount, _payoutCurrency) returns (uint256 remainingFunds) {
            // Return remaining amount if royalties payout succeeded
            return (remainingFunds, true);
        } catch {
            // Return initial amount if royalties payout failed
            return (_amount, false);
        }
    }
}
