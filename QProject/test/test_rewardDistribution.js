const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

describe("Test claim fee functionality", async function () {
  let QContract;
  let forwarder, devAddress, dxnBuyAndBurn, qBuyAndBurn, ai, deployer, ai2;
  beforeEach("Set enviroment", async () => {
    [deployer, forwarder, devAddress, dxnBuyAndBurn, qBuyAndBurn, ai, ai2] =
      await ethers.getSigners();

    const qContract = await ethers.getContractFactory("Q");
    QContract = await qContract.deploy(
      forwarder.address,
      devAddress.address,
      dxnBuyAndBurn.address,
      qBuyAndBurn.address,
      [ai.address, ai2.address]
    );

    await QContract.deployed();
  });

  it.skip("Contribute", async () => {
    await QContract.enterCycle(ai.address, 100, {
      value: ethers.utils.parseEther("100"),
    });
    expect(
      ethers.utils.formatEther(
        await QContract.accCycleEntries(deployer.address)
      )
    ).to.equal("95.0");
    expect(
      ethers.utils.formatEther(await QContract.accCycleEntries(ai.address))
    ).to.equal("5.0");

    let actualNumberOfInteraction = await QContract.cycleInteraction(
      await QContract.getCurrentCycle()
    );

    let protocolFee =
      (0.01 * 100 * (Number(actualNumberOfInteraction) + 100)) / 100;

    await QContract.enterCycle(ai.address, 100, {
      value: ethers.utils.parseEther(protocolFee.toString()),
    });

    expect(
      ethers.utils.formatEther(
        await QContract.accCycleEntries(deployer.address)
      )
    ).to.equal("190.0");
    expect(
      ethers.utils.formatEther(await QContract.accCycleEntries(ai.address))
    ).to.equal("10.0");

    await hre.ethers.provider.send("evm_increaseTime", [60 * 60 * 24]);
    await hre.ethers.provider.send("evm_mine");

    await QContract.enterCycle(ai.address, 100, {
      value: ethers.utils.parseEther("100"),
    });
    expect(await QContract.accRewards(deployer.address)).to.equal(
      ethers.utils.parseEther("9500")
    );

    await QContract.connect(ai).enterCycle(ai2.address, 100, {
      value: ethers.utils.parseEther(protocolFee.toString()),
    });

    expect(await QContract.accRewards(ai.address)).to.equal(
      ethers.utils.parseEther("500")
    );
  });

  it.skip("Using ai multiple times", async () => {
    expect(await ethers.provider.getBalance(QContract.address)).to.equal(
      ethers.utils.parseEther("0")
    );
    let initialDevBalance = await ethers.provider.getBalance(
      devAddress.address
    );

    let initialDxnBuyAndBurn = await ethers.provider.getBalance(
      dxnBuyAndBurn.address
    );

    let initialQBuyAndBurn = await ethers.provider.getBalance(
      qBuyAndBurn.address
    );

    let protocolFee = ethers.utils.parseEther("0.5");

    await QContract.enterCycle(ai.address, 50, {
      value: protocolFee,
    });

    let fivePercent = BigNumber.from("5")
      .mul(BigNumber.from(protocolFee.toString()))
      .div(BigNumber.from("100"));

    expect(await ethers.provider.getBalance(QContract.address)).to.equal(
      ethers.utils.parseEther("0.25")
    );

    expect(await ethers.provider.getBalance(devAddress.address)).to.equal(
      BigNumber.from(initialDevBalance.toString()).add(
        BigNumber.from(fivePercent.toString())
      )
    );

    expect(await ethers.provider.getBalance(dxnBuyAndBurn.address)).to.equal(
      BigNumber.from(initialDxnBuyAndBurn.toString()).add(
        BigNumber.from(fivePercent.toString())
      )
    );

    let fouryPercent = BigNumber.from("40")
      .mul(BigNumber.from(protocolFee.toString()))
      .div(BigNumber.from("100"));

    expect(await ethers.provider.getBalance(qBuyAndBurn.address)).to.equal(
      BigNumber.from(initialQBuyAndBurn.toString()).add(
        BigNumber.from(fouryPercent.toString())
      )
    );

    await hre.ethers.provider.send("evm_increaseTime", [60 * 60 * 24]);
    await hre.ethers.provider.send("evm_mine");
    //Second contribute in this cycle
    let devBalanceAfterFirstTransaction = await ethers.provider.getBalance(
      devAddress.address
    );

    let dxnBuyAndBurnBalanceAfterFirstTransaction =
      await ethers.provider.getBalance(dxnBuyAndBurn.address);

    let qBuyAndBurnAfterFirstTransaction = await ethers.provider.getBalance(
      qBuyAndBurn.address
    );

    let contractBalanceAfterFirstTransaction = await ethers.provider.getBalance(
      QContract.address
    );

    let fee = 0.01 * 100;
    let protocolFee2 = ethers.utils.parseEther(fee.toString());

    await QContract.enterCycle(ai.address, 100, {
      value: protocolFee2,
    });

    expect(await QContract.accRewards(deployer.address)).to.equal(
      ethers.utils.parseEther("9500")
    );

    let fiftyPercent = BigNumber.from("50")
      .mul(BigNumber.from(protocolFee2.toString()))
      .div(BigNumber.from("100"));

    let fivePercent2 = BigNumber.from("5")
      .mul(BigNumber.from(protocolFee2.toString()))
      .div(BigNumber.from("100"));

    expect(await ethers.provider.getBalance(QContract.address)).to.equal(
      BigNumber.from(contractBalanceAfterFirstTransaction.toString()).add(
        BigNumber.from(fiftyPercent.toString())
      )
    );

    expect(await ethers.provider.getBalance(devAddress.address)).to.equal(
      BigNumber.from(devBalanceAfterFirstTransaction.toString()).add(
        BigNumber.from(fivePercent2.toString())
      )
    );

    expect(await ethers.provider.getBalance(dxnBuyAndBurn.address)).to.equal(
      BigNumber.from(dxnBuyAndBurnBalanceAfterFirstTransaction.toString()).add(
        BigNumber.from(fivePercent2.toString())
      )
    );

    let fourtyPercent2 = BigNumber.from("40")
      .mul(BigNumber.from(protocolFee2.toString()))
      .div(BigNumber.from("100"));

    expect(await ethers.provider.getBalance(qBuyAndBurn.address)).to.equal(
      BigNumber.from(qBuyAndBurnAfterFirstTransaction.toString()).add(
        BigNumber.from(fourtyPercent2.toString())
      )
    );
  });
});
