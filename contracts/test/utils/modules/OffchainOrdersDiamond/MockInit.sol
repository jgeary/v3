// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {MockStorage} from "./MockStorage.sol";

contract MockInit {
    MockStorage internal s;

    function init() external {
        s.foo = true;
        s.bar = 2;
    }
}
