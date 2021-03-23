const { ethers } = require("hardhat");
const { expect } = require("chai");


let soveren, ownerSig, sig1, sig2, a1, a2;
const uri1 = 'uri1'

before(async function () {
  const Soveren = await ethers.getContractFactory("Soveren");
  soveren = await Soveren.deploy();
  await soveren.deployed();

  [ownerSig, sig1, sig2] = await ethers.getSigners();
  a1 = sig1.getAddress()
  a2 = sig1.getAddress()
})

describe("Soveren", function() {

  it("Should be 0 before mint", async function() {
    expect(await soveren.balanceOf(a1, 1)).to.equal(0);
  });

  it("Should mint new product", async function() {
    await soveren.connect(sig1).mint(1, 1000, uri1)
    expect(await soveren.balanceOf(a1, 1)).to.equal(1000);
  });

  it("Should mint more", async function() {
    await soveren.connect(sig1).mint(1, 100, uri1)
    expect(await soveren.balanceOf(a1, 1)).to.equal(1100);
  });


});
