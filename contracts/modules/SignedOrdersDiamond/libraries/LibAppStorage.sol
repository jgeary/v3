// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {ERC721TransferHelper} from "../../../transferHelpers/ERC721TransferHelper.sol";
import {ERC20TransferHelper} from "../../../transferHelpers/ERC20TransferHelper.sol";
import {ZoraModuleManager} from "../../../ZoraModuleManager.sol";
import {LibDiamond} from "../../../common/DiamondPermanentSelectors/libraries/LibDiamond.sol";

struct SignedAsksEthStorage {
    bytes32 SIGNED_ASK_TYPEHASH;
    bytes32 EIP_712_DOMAIN_SEPARATOR;
    mapping(address => mapping(uint256 => uint256)) nonce;
}
struct AppStorage {
    ERC20TransferHelper eRC20TransferHelper;
    ERC721TransferHelper erc721TransferHelper;
    ZoraModuleManager ZMM;
    bytes32 SIGNED_MODULE_APPROVAL_TYPEHASH;
    SignedAsksEthStorage signedAsksEth;
}

library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}

contract Modifiers {
    AppStorage internal s;
}
