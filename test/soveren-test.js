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

describe("Mint & Burn", function() {

  it("Should be 0 before mint", async function() {
    expect(await soveren.balanceOf(a1, 1)).to.equal(0);
  });

  it("Should mint new product", async function() {
    await soveren.connect(sig1).mint(1, 1000, uri1)
    expect(await soveren.balanceOf(a1, 1)).to.equal(1000);
  });

  it("Product should have specified uri", async function() {
    expect(await soveren.uri(1)).to.equal(uri1);
  });

  it("Should mint more", async function() {
    await soveren.connect(sig1).mintMore(1, 100)
    expect(await soveren.balanceOf(a1, 1)).to.equal(1100);
  });

  it("Should not mint from another address", async function() {
    await expect(soveren.connect(sig2).mint(1, 100, uri1)).to.be.revertedWith('SOVEREN: Token already exists')
  });

  it("Should not mint more from another address", async function() {
    await expect(soveren.connect(sig2).mintMore(1, 100)).to.be.revertedWith('SOVEREN: Mint more can token creator only')
  });

  it("Should burn", async function() {
    await soveren.connect(sig1).burn(1, 100)
    expect(await soveren.balanceOf(a1, 1)).to.equal(1000);
  });

  it("Should not burn exceed", async function() {
    await expect( soveren.connect(sig1).burn(1, 99999)).to.be.revertedWith('ERC1155: burn amount exceeds balance')
  });


  it("Should not burn exceed sig2", async function() {
    await expect( soveren.connect(sig2).burn(1, 100)).to.be.revertedWith('ERC1155: burn amount exceeds balance')
  });

});

describe("Buy", function() {

});
