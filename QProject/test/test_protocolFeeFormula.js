const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { commify } = require("ethers/lib/utils");
const { ethers } = require("hardhat");

describe("Test reward distribution functionality", async function () {
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

  it.skip("Using ai only one time", async () => {
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

    let protocolFee = ethers.utils.parseEther("1");

    await QContract.enterCycle(ai.address, 100, {
      value: protocolFee,
    });

    let fivePercent = BigNumber.from("5")
      .mul(BigNumber.from(protocolFee.toString()))
      .div(BigNumber.from("100"));

    expect(await ethers.provider.getBalance(QContract.address)).to.equal(
      ethers.utils.parseEther("0.5")
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

    let fee = (0.01 * 100 * (1 + 100)) / 100;
    let protocolFee2 = ethers.utils.parseEther(fee.toString());

    await QContract.enterCycle(ai.address, 100, {
      value: protocolFee2,
    });

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

    ////Third contribute in this cycle
    let devBalanceAfterSecondTransaction = await ethers.provider.getBalance(
      devAddress.address
    );

    let dxnBuyAndBurnBalanceAfterSecondTransaction =
      await ethers.provider.getBalance(dxnBuyAndBurn.address);

    let qBuyAndBurnAfterSecondTransaction = await ethers.provider.getBalance(
      qBuyAndBurn.address
    );

    let contractBalanceAfterSecondTransaction =
      await ethers.provider.getBalance(QContract.address);

    let fee2 = (0.01 * 75 * (2 + 100)) / 100;
    let protocolFee3 = ethers.utils.parseEther(fee2.toString());

    await QContract.enterCycle(ai.address, 75, {
      value: protocolFee3,
    });

    let fiftyPercent2 = BigNumber.from("50")
      .mul(BigNumber.from(protocolFee3.toString()))
      .div(BigNumber.from("100"));

    let fivePercent3 = BigNumber.from("5")
      .mul(BigNumber.from(protocolFee3.toString()))
      .div(BigNumber.from("100"));

    expect(await ethers.provider.getBalance(QContract.address)).to.equal(
      BigNumber.from(contractBalanceAfterSecondTransaction.toString()).add(
        BigNumber.from(fiftyPercent2.toString())
      )
    );

    expect(await ethers.provider.getBalance(devAddress.address)).to.equal(
      BigNumber.from(devBalanceAfterSecondTransaction.toString()).add(
        BigNumber.from(fivePercent3.toString())
      )
    );

    expect(await ethers.provider.getBalance(dxnBuyAndBurn.address)).to.equal(
      BigNumber.from(dxnBuyAndBurnBalanceAfterSecondTransaction.toString()).add(
        BigNumber.from(fivePercent3.toString())
      )
    );

    let fourtyPercent3 = BigNumber.from("40")
      .mul(BigNumber.from(protocolFee3.toString()))
      .div(BigNumber.from("100"));

    expect(await ethers.provider.getBalance(qBuyAndBurn.address)).to.equal(
      BigNumber.from(qBuyAndBurnAfterSecondTransaction.toString()).add(
        BigNumber.from(fourtyPercent3.toString())
      )
    );
  });

  it.skip("Test protocol fee formula", async () => {
    let protocolFee = ethers.utils.parseEther("1");
    let contractBalance = await ethers.provider.getBalance(QContract.address);
    await QContract.enterCycle(ai.address, 100, {
      value: protocolFee,
    });

    let fiftyPercent = BigNumber.from("50")
      .mul(BigNumber.from(protocolFee.toString()))
      .div(BigNumber.from("100"));

    expect(await ethers.provider.getBalance(QContract.address)).to.equal(
      BigNumber.from(contractBalance).add(BigNumber.from(fiftyPercent))
    );

    let fee = (0.01 * 1 * 75 * (100 + 1)) / 100;
    let protocolFee2 = ethers.utils.parseEther(fee.toString());
    let contractBalance2 = await ethers.provider.getBalance(QContract.address);
    await QContract.enterCycle(ai.address, 75, {
      value: protocolFee2,
    });

    let fiftyPercent2 = BigNumber.from("50")
      .mul(BigNumber.from(protocolFee2.toString()))
      .div(BigNumber.from("100"));

    expect(await ethers.provider.getBalance(QContract.address)).to.equal(
      BigNumber.from(contractBalance2).add(BigNumber.from(fiftyPercent2))
    );
    let fee2 = (0.01 * 55 * (2 + 100)) / 100;
    let protocolFee3 = ethers.utils.parseEther(fee2.toString());
    let contractBalance3 = await ethers.provider.getBalance(QContract.address);
    await QContract.enterCycle(ai.address, 55, {
      value: protocolFee3,
    });

    let fiftyPercent3 = BigNumber.from("50")
      .mul(BigNumber.from(protocolFee3.toString()))
      .div(BigNumber.from("100"));

    expect(await ethers.provider.getBalance(QContract.address)).to.equal(
      BigNumber.from(contractBalance3).add(BigNumber.from(fiftyPercent3))
    );
  });

  it.skip("Test protocol fee formula in for loop", async () => {
    let protocolFee = ethers.utils.parseEther("1");
    let contractBalance = await ethers.provider.getBalance(QContract.address);
    await QContract.enterCycle(ai.address, 100, {
      value: protocolFee,
    });

    let fiftyPercent = BigNumber.from("50")
      .mul(BigNumber.from(protocolFee.toString()))
      .div(BigNumber.from("100"));

    expect(await ethers.provider.getBalance(QContract.address)).to.equal(
      BigNumber.from(contractBalance).add(BigNumber.from(fiftyPercent))
    );

    let entryMultiplier = 50;
    for (let i = 1; i <= 5; i++) {
      let fee =
        (ethers.utils.parseEther("0.01") * entryMultiplier * (i + 100)) /
        100;
      let contractBalance2 = await ethers.provider.getBalance(
        QContract.address
      );
      await QContract.enterCycle(ai.address, entryMultiplier, {
        value: BigNumber.from(fee.toString()),
      });

      let fiftyPercent2 = BigNumber.from("50")
        .mul(BigNumber.from(fee.toString()))
        .div(BigNumber.from("100"));

      expect(await ethers.provider.getBalance(QContract.address)).to.equal(
        BigNumber.from(contractBalance2).add(BigNumber.from(fiftyPercent2))
      );
      entryMultiplier += 5;
    }
  });
});
