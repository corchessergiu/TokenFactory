const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { commify } = require("ethers/lib/utils");
const { ethers } = require("hardhat");

describe("Test reward distribution functionality", async function () {
  let QContract, QViewContract;
  let forwarder,
    devAddress,
    dxnBuyAndBurn,
    qBuyAndBurn,
    ai,
    deployer,
    ai2,
    user1;
  beforeEach("Set enviroment", async () => {
    [
      deployer,
      user1,
      forwarder,
      devAddress,
      dxnBuyAndBurn,
      qBuyAndBurn,
      ai,
      ai2,

    ] = await ethers.getSigners();

    const qContract = await ethers.getContractFactory("Q");
    QContract = await qContract.deploy(
      forwarder.address,
      devAddress.address,
      dxnBuyAndBurn.address,
      qBuyAndBurn.address
      [ai.address, ai2.address]
    );
    await QContract.deployed();

    const qViewContract = await ethers.getContractFactory("QViews");
    QViewContract = await qViewContract.deploy(QContract.address);
    await QViewContract.deployed();
  });

  it.skip("Reward distribution for a single ai", async () => {
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
    let firstCycleReward = await QContract.currentCycleReward();
    await hre.ethers.provider.send("evm_increaseTime", [60 * 60 * 24]);
    await hre.ethers.provider.send("evm_mine");

    let userExpectedReward = await QViewContract.getUnclaimedRewards(
      deployer.address
    );

    let ninetyFivePercent = BigNumber.from("95")
      .mul(firstCycleReward)
      .div(BigNumber.from("100"));

    expect(ninetyFivePercent).to.equal(userExpectedReward);
    let aiExpectedReward = await QViewContract.getUnclaimedRewards(ai.address);
    let fivePercentForAI = BigNumber.from("5")
      .mul(firstCycleReward)
      .div(BigNumber.from("100"));

    expect(aiExpectedReward).to.equal(fivePercentForAI);
  });

  it.skip("Reward distribution for multiple ai", async () => {
    //2 interaction, 1 user1 and 1 deployer => 95% poll will be split between user1 and deployer and 5% will be for ai
    let protocolFee = ethers.utils.parseEther("1");
    await QContract.enterCycle(ai.address, 100, {
      value: protocolFee,
    });
    let protocolFee2 = (0.01 * 1 * 100 * (100 + 1)) / 100;
    await QContract.connect(user1).enterCycle(ai.address, 100, {
      value: ethers.utils.parseEther(protocolFee2.toString()),
    });
    let firstCycleReward = await QContract.currentCycleReward();
    await hre.ethers.provider.send("evm_increaseTime", [60 * 60 * 24]);
    await hre.ethers.provider.send("evm_mine");

    let deployerExpectedReward = await QViewContract.getUnclaimedRewards(
      deployer.address
    );

    let user1ExpectedReward = await QViewContract.getUnclaimedRewards(
      user1.address
    );

    let aiExpectedReward = await QViewContract.getUnclaimedRewards(ai.address);

    let aiPercent = BigNumber.from("5")
      .mul(firstCycleReward)
      .div(BigNumber.from("100"));

    let ninetyFivePercent = BigNumber.from("95")
      .mul(firstCycleReward)
      .div(BigNumber.from("100"));

    const oneEtherInWei = BigNumber.from("1000000000000000000");
    let deployerPercent = ninetyFivePercent
      .mul(firstCycleReward)
      .div(BigNumber.from("10000"))
      .div(BigNumber.from("2"))
      .div(oneEtherInWei);

    let userPercent = ninetyFivePercent
      .mul(firstCycleReward)
      .div(BigNumber.from("10000"))
      .div(BigNumber.from("2"))
      .div(oneEtherInWei);

    expect(aiExpectedReward.toString()).to.equal(aiPercent);
    expect(deployerExpectedReward).to.equal(deployerPercent.toString());
    expect(user1ExpectedReward).to.equal(userPercent.toString());
  });
});
