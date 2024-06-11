const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

describe("Test AIRegister function", async function () {
  let deployer, forwarder, devAddress, dxnBuyAndBurn, QPayment;
  beforeEach("Set enviroment", async () => {
    [
      deployer,
      forwarder,
      devAddress,
      dxnBuyAndBurn,
      maintenanceAddress,
      marketingAddress,
    ] = await ethers.getSigners();

    const qPayment = await ethers.getContractFactory("QPayment");
    QPayment = await qPayment.deploy(marketingAddress.address,maintenanceAddress.address);
    await QPayment.deployed();
  });

  it.skip("AIRegister function", async () => {
    console.log(QPayment.address);
  });

});
