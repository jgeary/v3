// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {LibDiamond} from "../../../common/DiamondPermanentSelectors/libraries/LibDiamond.sol";

library LibAppStorage {
    bytes32 constant APP_STORAGE_POSITION = keccak256("zora.diamond.storage.signed.orders");
    uint256 constant USE_ALL_GAS_FLAG = 0;

    struct AppStorage {
        // signed orders
        bytes32 EIP_712_DOMAIN_SEPARATOR;
        // asks
        bytes32 SIGNED_ASK_TYPEHASH;
        mapping(address => mapping(address => mapping(uint256 => uint256))) SIGNED_ASKS_nonce;
        // WARNING: never rearrange, delete or insert a line above. append only below.
    }

    function appStorage() internal pure returns (AppStorage storage ds) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}
