// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {IRoyaltyEngineV1} from "@manifoldxyz/royalty-registry-solidity/contracts/IRoyaltyEngineV1.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC173} from "../../common/DiamondPermanentSelectors/interfaces/IERC173.sol";
import {IWETH} from "../../common/OutgoingTransferSupport/V1/IWETH.sol";
import {Diamond} from "../../common/DiamondPermanentSelectors/Diamond.sol";
import {IDiamondCut} from "../../common/DiamondPermanentSelectors/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../../common/DiamondPermanentSelectors/interfaces/IDiamondLoupe.sol";
import {LibDiamond} from "../../common/DiamondPermanentSelectors/libraries/LibDiamond.sol";
import {LibAppStorage} from "./libraries/LibAppStorage.sol";
import {ERC721TransferHelper} from "../../transferHelpers/ERC721TransferHelper.sol";
import {ERC20TransferHelper} from "../../transferHelpers/ERC20TransferHelper.sol";
import {ZoraModuleManager} from "../../ZoraModuleManager.sol";
import {ZoraProtocolFeeSettings} from "../../auxiliary/ZoraProtocolFeeSettings/ZoraProtocolFeeSettings.sol";

contract InitDiamond {
    function _chainID() private view returns (uint256 id) {
        assembly {
            id := chainid()
        }
    }

    function init(
        ERC20TransferHelper erc20TransferHelper,
        ERC721TransferHelper erc721TransferHelper,
        ZoraModuleManager zoraModuleManager,
        ZoraProtocolFeeSettings zoraProtocolFeeSettings,
        address registrar,
        IWETH weth,
        IRoyaltyEngineV1 royaltyEngine
    ) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();

        ds.erc20TransferHelper = erc20TransferHelper;
        ds.erc721TransferHelper = erc721TransferHelper;
        ds.zoraModuleManager = zoraModuleManager;
        ds.zoraProtocolFeeSettings = zoraProtocolFeeSettings;
        ds.SIGNED_MODULE_APPROVAL_TYPEHASH = 0xe85f51623d2a2c6a227a03b74ae96521390f212006fafcabd7bf959916eec097;
        ds.registrar = registrar;
        ds.weth = weth;
        ds.royaltyEngine = royaltyEngine;

        s.EIP_712_DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("ZORA:SignedOrders")),
                keccak256(bytes("1")),
                _chainID(),
                address(this)
            )
        );
        /// @dev keccak256("SignedAsk(address tokenContract,uint256 tokenId,address currency,uint256 price,uint16 findersFeeBps,uint256 expiry,uint256 nonce)");
        s.SIGNED_ASK_TYPEHASH = 0x3d92ea1e0245be345ace4d062e201d48cfbfc360ee4527eb281d55dbbd3ba627;

        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
    }
}
