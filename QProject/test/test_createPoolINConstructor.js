const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

describe("Test createPoolFromConstructor function", async function () {
  let deployer, forwarder, devAddress, dxnBuyAndBurn, QPayment, QERC20;
  beforeEach("Set enviroment", async () => {
    [deployer, forwarder, devAddress, dxnBuyAndBurn] =
      await ethers.getSigners();

    const qERC20 = await ethers.getContractFactory("ERC20TokenTest");
    QERC20 = await qERC20.deploy();
    await QERC20.deployed();
  });

  it.skip("Test mint function", async () => {
    console.log(await QERC20.totalSupply());
    console.log(await QERC20.balanceOf(QERC20.address));
  });
});
