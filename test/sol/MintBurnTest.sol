// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;

import "truffle/Assert.sol";
import "../../contracts/RestrictedToken.sol";
import "../../contracts/TransferRules.sol";

contract MintBurnTest {
    RestrictedToken public token;
    address alice = address(0x1);

    function beforeEach() public {
        TransferRules rules = new TransferRules();
        token = new RestrictedToken(address(rules), address(this), address(this), "xyz", "Ex Why Zee", 0, 100, 1e6);
    }

    function testCannotMintMoreThanMaxUintValue() public {
        (bool success, ) = address(token).call(abi.encodeWithSignature("mint(address,uint256)", alice, token.MAX_UINT256()));
        Assert.isFalse(success, "should fail because it exceeds the max uint256 value");
    }
}
