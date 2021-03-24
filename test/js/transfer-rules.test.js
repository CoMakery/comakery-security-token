const truffleAssert = require('truffle-assertions');
var RestrictedToken = artifacts.require("RestrictedToken");
var TransferRules = artifacts.require("TransferRules");

contract("Transfer rules", function (accounts) {
  var contractAdmin
  var reserveAdmin
  var unprivileged
  var token
  var transferAdmin

  beforeEach(async function () {
    contractAdmin = accounts[0]
    transferAdmin = accounts[1]
    walletsAdmin = accounts[2]
    reserveAdmin = accounts[3]

    unprivileged = accounts[5]
    alice = accounts[6]
    bob = accounts[7]

    let rules = await TransferRules.new()
    token = await RestrictedToken.new(rules.address, contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100, 1e6)

    await token.grantTransferAdmin(transferAdmin, {
      from: contractAdmin
    })

    await token.grantWalletsAdmin(walletsAdmin, {
      from: contractAdmin
    })

    await token.mint(alice, 40, {
        from: reserveAdmin
    });
  })

  it('contract contractAdmin is not the same address as treasury admin', async () => {
    assert.equal(await token.balanceOf(contractAdmin), 0, 'allocates no balance to the contractAdmin')
    assert.equal(await token.balanceOf(reserveAdmin), 100, 'allocates all tokens to the token reserve admin')
  })

  it('cannot exceed the max balance of an address', async () => {
    await token.setMaxBalance(unprivileged, 2, {
      from: walletsAdmin
    })
    await token.setAllowGroupTransfer(0, 0, 1, {
      from: transferAdmin
    })

    await truffleAssert.passes(token.transfer(unprivileged, 1, {
      from: reserveAdmin
    }))

    await truffleAssert.reverts(token.transfer(unprivileged, 2, {
      from: reserveAdmin
    }), "GREATER THAN RECIPIENT MAX BALANCE")

    assert.equal(await token.balanceOf(unprivileged), 1)

    await truffleAssert.passes(token.transfer(unprivileged, 1, {
      from: reserveAdmin
    }))

    assert.equal(await token.balanceOf(unprivileged), 2)
  })

  it('cannot transfer from a frozen address', async () => {
    await token.freeze(alice, true, {
        from: walletsAdmin
    })

    await truffleAssert.reverts(token.transfer(bob, 5, {
      from: alice
    }), "SENDER ADDRESS IS FROZEN")
  })

  it('cannot transfer to a frozen address', async () => {
    await token.freeze(bob, true, {
        from: walletsAdmin
    })

    await truffleAssert.reverts(token.transfer(bob, 5, {
      from: alice
    }), "RECEIVER ADDRESS IS FROZEN")
  })
})
