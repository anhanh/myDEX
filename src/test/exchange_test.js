var tuananh = artifacts.require("./TuanAnhToken.sol");
var myExchange = artifacts.require("./Exchange.sol");

contract('MyExchange', function(accounts) {

    it("should be possible to add tokens", function () {
        var token;
        var exchange;
        return tuananh.deployed().then(function (instance) {
            token = instance;
            return myExchange.deployed();
        }).then(function (instance) {
            exchange = instance;
            return exchange.addToken("TuanAnh", token.address);
        }).then(function () {
            return exchange.hasToken("TuanAnh");
        }).then(function (hasToken) {
            assert.equal(hasToken, true, "The Token was not added");
        });
    });

    it("should be possible to Deposit Token", function () {
        var exchange;
        var token;
        return tuananh.deployed().then(function (instance) {
            token = instance;
            return myExchange.deployed();
        }).then(function (instance) {
            exchange = instance;
            return token.approve(exchange.address, 2000);
        }).then(function() {
            return exchange.depositToken("TuanAnh", 2000);
        }).then(function() {
            return exchange.getBalance("TuanAnh");
        }).then(function(balanceToken) {
            assert.equal(balanceToken, 2000, "There should be 2000 tokens for the address");
        });
    });

    it("should be possible to Withdraw Token", function () {
        var exchange;
        var token;
        return tuananh.deployed().then(function (instance) {
            token = instance;
            return myExchange.deployed();
        }).then(function (instance) {
            exchange = instance;
            return exchange.withdrawToken("TuanAnh", 1000);
        }).then(function() {
            return exchange.getBalance("TuanAnh");
        }).then(function(balanceToken) {
            assert.equal(balanceToken, 1000, "There should be 0 tokens for the address");
        });
    });

});