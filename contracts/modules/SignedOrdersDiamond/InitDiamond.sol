// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC173} from "../../common/DiamondPermanentSelectors/interfaces/IERC173.sol";
import {Diamond} from "../../common/DiamondPermanentSelectors/Diamond.sol";
import {IDiamondCut} from "../../common/DiamondPermanentSelectors/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../../common/DiamondPermanentSelectors/interfaces/IDiamondLoupe.sol";
import {LibDiamond} from "../../common/DiamondPermanentSelectors/libraries/LibDiamond.sol";

contract InitDiamond {
    AppStorage internal s;

    function _chainID() private view returns (uint256 id) {
        assembly {
            id := chainid()
        }
    }

    function init(
        address erc20TransferHelper,
        address erc721TransferHelper,
        address zmm
    ) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        s.erc20TransferHelper = erc20TransferHelper;
        s.erc721TransferHelper = erc721TransferHelper;
        s.ZMM = zmm;
        s.SIGNED_MODULE_APPROVAL_TYPEHASH = 0xe85f51623d2a2c6a227a03b74ae96521390f212006fafcabd7bf959916eec097;

        /// @dev keccak256("SignedAskEth(address tokenContract,uint256 tokenId,uint256 expiry,uint256 nonce, uint256 price)");
        s.signedAsksEth.SIGNED_ASK_TYPEHASH = 0x3ddc460308a4e62163c2e10f57370a451b5ceb682ab364e6ebc24ab1633f536c;
        s.signedAsksEth.EIP_712_DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("ZORA:SignedAsksEth")),
                keccak256(bytes("1")),
                _chainID(),
                address(this)
            )
        );

        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
    }
}
