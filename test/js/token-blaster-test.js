const truffleAssert = require('truffle-assertions');
const RestrictedToken = artifacts.require("RestrictedToken");
const TransferRules = artifacts.require("TransferRules");
const TokenBlaster = require('../../src/token-blaster.js')

contract("TokenBlaster", function (accounts) {
    var sendWallet
    var alice
    var bob
    var token
    var blaster

    beforeEach(async function () {
        sendWallet = accounts[0]
        alice = accounts[1]
        bob = accounts[2]
        charlie = accounts[3]

        defaultGroup = 0

        let rules = await TransferRules.new()
        token = await RestrictedToken.new(rules.address, sendWallet, sendWallet, "xyz", "Ex Why Zee", 6, 100, 1e6)

        await token.grantTransferAdmin(sendWallet, {
            from: sendWallet
        })

        await token.setAllowGroupTransfer(defaultGroup, defaultGroup, 1, {
            from: sendWallet
        })

        await token.setAllowGroupTransfer(defaultGroup, 1, 1, {
            from: sendWallet
        })

        await token.setAddressPermissions(bob, defaultGroup, 1, 200, false, {
            from: sendWallet
        })

        blaster = await TokenBlaster.init(token.address, sendWallet)

    })

    it('can do a simple transfer', async () => {
        let tx = await blaster.transfer(bob, 50)
        assert.equal(await token.balanceOf.call(bob), 50)

        truffleAssert.eventEmitted(tx, 'Transfer', (ev) => {
            assert.equal(ev.from, sendWallet)
            assert.equal(ev.to, bob)
            assert.equal(ev.value, 50)
            return true
        })
    })

    it('can do a transfer and set the transfer group of the recipient address', async () => {
        let txns = await blaster.setGroupAndTransfer({
            address: bob,
            amount: 50,
            transferGroupId: 1,
            frozen: "false",
            maxBalance: "10000",
            timeLockUntil: "0",
            transferGroupId: '1'
        })

        assert.equal(await token.balanceOf.call(bob), 50)
        assert.equal(await token.getTransferGroup(bob), 1)

        truffleAssert.eventEmitted(txns[0], 'AddressTransferGroup', (ev) => {
            assert.equal(ev.admin, sendWallet)
            assert.equal(ev.addr, bob)
            assert.equal(ev.value, 1)
            return true
        })

        truffleAssert.eventEmitted(txns[1], 'Transfer', (ev) => {
            assert.equal(ev.from, sendWallet)
            assert.equal(ev.to, bob)
            assert.equal(ev.value, 50)
            return true
        })
    })

    it('can do a simple multiTransfer', async () => {
        let txns = await blaster.multiTransfer([
            [bob, 23],
            [bob, 27]
        ])
        assert.equal(await token.balanceOf.call(bob), 50)

        truffleAssert.eventEmitted(txns[0], 'Transfer', (ev) => {
            assert.equal(ev.from, sendWallet)
            assert.equal(ev.to, bob)
            assert.equal(ev.value, 23)
            return true
        })

        truffleAssert.eventEmitted(txns[1], 'Transfer', (ev) => {
            assert.equal(ev.from, sendWallet)
            assert.equal(ev.to, bob)
            assert.equal(ev.value, 27)
            return true
        })
    })

    it('can do a simple multiSetGroupAndTransfer', async () => {
        let txns = await blaster.multiSetGroupAndTransfer([{
                address: bob,
                amount: 23,
                transferGroupId: 1,
                frozen: "false",
                maxBalance: "10000",
                timeLockUntil: "0",
                transferGroupId: '1'
            },
            {
                address: alice,
                amount: 19,
                transferGroupId: 1,
                frozen: "false",
                maxBalance: "10000",
                timeLockUntil: "0",
                transferGroupId: '1'
            }
        ])
        assert.equal(await token.balanceOf.call(bob), 23)

        truffleAssert.eventEmitted(txns[0][0], 'AddressTransferGroup', (ev) => {
            assert.equal(ev.admin, sendWallet)
            assert.equal(ev.addr, bob)
            assert.equal(ev.value, 1)
            return true
        })

        truffleAssert.eventEmitted(txns[0][1], 'Transfer', (ev) => {
            assert.equal(ev.from, sendWallet)
            assert.equal(ev.to, bob)
            assert.equal(ev.value, 23)
            return true
        })
        truffleAssert.eventEmitted(txns[1][0], 'AddressTransferGroup', (ev) => {
            assert.equal(ev.admin, sendWallet)
            assert.equal(ev.addr, alice)
            assert.equal(ev.value, 1)
            return true
        })

        truffleAssert.eventEmitted(txns[1][1], 'Transfer', (ev) => {
            assert.equal(ev.from, sendWallet)
            assert.equal(ev.to, alice)
            assert.equal(ev.value, 19)
            return true
        })
    })

    it('can parse a csv file in preparation for transfers', async () => {
        await blaster.getTransfers('./test/test_data/test-transfers.csv')
        assert.deepEqual(blaster.pendingTransfers, [{
                address: '0x57ea4caa7c61c2f48ce26cd5149ee641a75f5f6f',
                amount: '150',
                frozen: "false",
                maxBalance: "10000",
                timeLockUntil: "0",
                transferGroupId: '1'
            },
            {
                address: '0x45d245d054a9cab4c8e74dc131c289207db1ace4',
                amount: '999',
                frozen: "false",
                maxBalance: "10000",
                timeLockUntil: "0",
                transferGroupId: '1'
            }
        ])
    })
})