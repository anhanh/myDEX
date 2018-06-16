var TuanAnhToken = artifacts.require("./TuanAnhToken.sol");
var Exchange = artifacts.require("./Exchange.sol");

module.exports = function(deployer) {
  deployer.deploy(TuanAnhToken);
  deployer.deploy(Exchange);
};
