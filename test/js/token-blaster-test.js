const truffleAssert = require('truffle-assertions');
var RestrictedToken = artifacts.require("RestrictedToken");
var TransferRules = artifacts.require("TransferRules");
// var blaster = require('token-blaster')

class TokenBlaster {
    constructor(token, tokenAddress, walletAddress) {
        this.token = token
        this.tokenAddress = tokenAddress
        this.walletAddress = walletAddress
        this.transfer = this.transfer.bind(this)
    }

    static async init(tokenAddress, walletAddress) {
        let token = await RestrictedToken.at(tokenAddress)
        return new TokenBlaster(token, tokenAddress, walletAddress)
    }

    async transfer(recipientAddress, amount) {
        return await this.token.transfer(recipientAddress, amount, {
            from: this.walletAddress
        })
    }

    async multiTransfer(recipientAddressAndAmountArray) {
        let promises = recipientAddressAndAmountArray.map(([recipientAddress, amount]) => {
            return this.transfer(recipientAddress, amount)
        })
        return Promise.all(promises)
    }
}

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

    it('can do a simple multiTransfer', async () => {
        let txns = await blaster.multiTransfer([
            [bob, 23],
            [bob, 27]
        ])
        assert.equal(await token.balanceOf.call(bob), 50)
        // var txns = await Promise.all(txnsP)

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
})