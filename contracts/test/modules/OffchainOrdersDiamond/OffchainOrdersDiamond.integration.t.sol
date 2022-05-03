// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {DSTest} from "ds-test/test.sol";

import {Diamond} from "../../../common/DiamondPermanentSelectors/Diamond.sol";
import {IDiamondCut} from "../../../common/DiamondPermanentSelectors/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../../../common/DiamondPermanentSelectors/interfaces/IDiamondLoupe.sol";
import {MockFacet, IMockFacet} from "../../utils/modules/OffchainOrdersDiamond/MockFacet.sol";
import {MockInit} from "../../utils/modules/OffchainOrdersDiamond/MockInit.sol";

import {TestERC721} from "../../utils/tokens/TestERC721.sol";
import {WETH} from "../../utils/tokens/WETH.sol";
import {VM} from "../../utils/VM.sol";

/// @title AsksV1_1IntegrationTest
/// @notice Integration Tests for Asks v1.1
contract OffchainOrdersDiamondTest is DSTest {
    VM internal vm;

    Diamond internal diamond;
    MockFacet internal facet;
    MockInit internal init;

    event DataSet(bool foo, uint8 bar);

    function setUp() public {
        // Cheatcodes
        vm = VM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        // Deploy diamond with a mock facet
        diamond = new Diamond(address(this));
        facet = new MockFacet();
        init = new MockInit();

        // Cut mock facet
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = MockFacet.setData.selector;
        selectors[1] = MockFacet.getData.selector;
        cut[0] = IDiamondCut.FacetCut(address(facet), IDiamondCut.FacetCutAction.Add, selectors);

        IDiamondCut(address(diamond)).diamondCut(cut, address(init), abi.encodeWithSelector(MockInit.init.selector, bytes("")));
    }
    
    // test Replace is not allowed, Remove is allowed but cannot Add again
    function test_LibDiamond() public {
        require(IDiamondLoupe(address(diamond)).facetFunctionSelectors(address(facet)).length == 2);

        MockFacet otherFacet = new MockFacet();
        MockInit otherInit = new MockInit();

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.setData.selector;
        cut[0] = IDiamondCut.FacetCut(address(otherFacet), IDiamondCut.FacetCutAction.Replace, selectors);

        vm.expectRevert("LibDiamondCut: Incorrect FacetCutAction");
        IDiamondCut(address(diamond)).diamondCut(cut, address(otherInit), abi.encodeWithSelector(MockInit.init.selector, bytes("")));
        
        cut[0] = IDiamondCut.FacetCut(address(0), IDiamondCut.FacetCutAction.Remove, selectors);
        IDiamondCut(address(diamond)).diamondCut(cut, address(otherInit), abi.encodeWithSelector(MockInit.init.selector, bytes("")));
        require(IDiamondLoupe(address(diamond)).facetFunctionSelectors(address(facet)).length == 1);

        cut[0] = IDiamondCut.FacetCut(address(otherFacet), IDiamondCut.FacetCutAction.Add, selectors);
        vm.expectRevert("DiamondPermanentSelectors: Can't add selector that was previously removed");
        IDiamondCut(address(diamond)).diamondCut(cut, address(otherInit), abi.encodeWithSelector(MockInit.init.selector, bytes("")));

        vm.expectRevert("Diamond: Function does not exist");
        IMockFacet(address(diamond)).setData(true, 0);
    }

    function test_Init() public {
        (bool foo, uint8 bar) = IMockFacet(address(diamond)).getData();
        require(foo == true);
        require(bar == 2);
    }

    function test_SetGetData() public {
        vm.expectEmit(true, true, false, false);
        emit DataSet(false, 1);
        IMockFacet(address(diamond)).setData(false, 1);
        (bool foo, uint8 bar) = IMockFacet(address(diamond)).getData();
        require(foo == false);
        require(bar == 1);
    }
}
