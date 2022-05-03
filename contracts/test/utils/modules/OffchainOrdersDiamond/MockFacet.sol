// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {LibDiamond} from "../../../../common/DiamondPermanentSelectors/libraries/LibDiamond.sol";
import {MockStorage} from "./MockStorage.sol";

interface IMockFacet {
    function setData(bool _foo, uint8 _bar) external;

    function getData() external view returns (bool, uint8);
}

contract MockFacet {
    MockStorage internal s;

    event DataSet(bool foo, uint8 bar);

    function setData(bool _foo, uint8 _bar) external {
        LibDiamond.enforceIsContractOwner();
        s.foo = _foo;
        s.bar = _bar;
        emit DataSet(_foo, _bar);
    }

    function getData() external view returns (bool, uint8) {
        return (s.foo, s.bar);
    }
}
