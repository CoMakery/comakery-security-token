pragma solidity ^ 0.5 .8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RestrictedToken.sol";
import "./support/UserProxy.sol";

contract MessagesForTransferRestrictionsTest {
    RestrictedToken token;
    address tokenContractOwner;
    address alice;
    address bob;

    uint256 groupA = 1;
    uint256 groupB = 2;
    uint256 transferTimeIsNow = now;
    uint maxTokens = 1000;
    uint restrictionCode;

    function beforeEach() public {
        tokenContractOwner = address(this);
        token = new RestrictedToken(tokenContractOwner, tokenContractOwner, "xyz", "Ex Why Zee", 6, 1234567);

        alice = address(0x1);
        bob = address(0x2);

        token.setAccountPermissions(alice, groupA, transferTimeIsNow, maxTokens);
        token.setAccountPermissions(bob, groupB, transferTimeIsNow, maxTokens);
    }

    function testMessageForTransferRestrictionSuccess() public {
        Assert.equal(token.messageForTransferRestriction(0), "SUCCESS", "wrong message");
        Assert.equal(token.messageForTransferRestriction(1), "GREATER THAN RECIPIENT MAX BALANCE", "wrong message");
        Assert.equal(token.messageForTransferRestriction(2), "SENDER TOKENS LOCKED", "wrong message");
        Assert.equal(token.messageForTransferRestriction(3), "DO NOT SEND TO TOKEN CONTRACT", "wrong message");
        Assert.equal(token.messageForTransferRestriction(4), "DO NOT SEND TO EMPTY ADDRESS", "wrong message");
        Assert.equal(token.messageForTransferRestriction(5), "SENDER ADDRESS IS FROZEN", "wrong message");
        Assert.equal(token.messageForTransferRestriction(6), "ALL TRANSFERS PAUSED", "wrong message");
        Assert.equal(token.messageForTransferRestriction(7), "TRANSFER GROUP NOT APPROVED", "wrong message");
        Assert.equal(token.messageForTransferRestriction(8), "TRANSFER GROUP NOT ALLOWED UNTIL LATER", "wrong message");
    }
}