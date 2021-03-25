const { ethers } = require("hardhat");
const { expect } = require("chai");
require("hardhat-typechain");


let soveren, sigOwner, adrOwner, sigContract, adrContract,
    sig1, sig2, sig3,
    adr1, adr2, adr3;

const AddressZero = ethers.constants.AddressZero
const uri1 = 'uri1'
const uri2 = 'uri2'

const private1 = 'private1'
const private2 = 'private2'

before(async function () {
  const Soveren = await ethers.getContractFactory("Soveren")
  soveren = await Soveren.deploy()
  await soveren.deployed();

  sigContract = soveren.signer;
  adrContract = soveren.signer.getAddress();

  [sigOwner, sig1, sig2, sig3] = await ethers.getSigners();
  adrOwner = await sigOwner.getAddress()
  adr1 = await sig1.getAddress()
  adr2 = await sig2.getAddress()
  adr3 = await sig3.getAddress()

})

describe("Mint & Burn", function() {

  it("Should be 0 before mint", async function() {
    expect(await soveren.balanceOf(adr1, 1)).to.equal(0);
  });

  it("Should mint new product", async function() {
    await soveren.connect(sig1).mint(1, 1000, uri1, private1, true)
    expect(await soveren.balanceOf(adr1, 1)).to.equal(1000);
  });

  it("Product should have specified uri", async function() {
    expect(await soveren.uri(1)).to.equal(uri1);
  });

  it("Should mint more", async function() {
    await soveren.connect(sig1).mintMore(1, 100)
    expect(await soveren.balanceOf(adr1, 1)).to.equal(1100);
  });

  it("Should not mint from another address", async function() {
    await expect(soveren.connect(sig2).mint(1, 100, uri1, private1, true)).to.be.revertedWith('SOVEREN: Token already exists')
  });

  it("Should not mint more from another address", async function() {
    await expect(soveren.connect(sig2).mintMore(1, 100)).to.be.revertedWith('SOVEREN: Mint more can token creator only')
  });

  it("Should not burn exceed", async function() {
    await expect( soveren.connect(sig1).burn(1, 99999)).to.be.revertedWith('ERC1155: burn amount exceeds balance')
  });

  it("Should burn", async function() {
    await soveren.connect(sig1).burn(1, 1100)
    expect(await soveren.balanceOf(adr1, 1)).to.equal(0);
  });

  it("Should not burn exceed sig2", async function() {
    await expect( soveren.connect(sig2).burn(1, 50)).to.be.revertedWith('ERC1155: burn amount exceeds balance')
  });

  it("Should mint new product sig2", async function() {
    await soveren.connect(sig2).mint(2, 500, uri2, private2, false)
    expect(await soveren.balanceOf(adr2, 2)).to.equal(500);
  });

  it("Should not mint more", async function() {
    await expect(  soveren.connect(sig2).mintMore(2, 100)).to.be.revertedWith('SOVEREN: mintMore disabled')
  });


  it("Should burn", async function() {
    await soveren.connect(sig2).burn(2, 500)
    expect(await soveren.balanceOf(adr2, 2)).to.equal(0);
  });

})

describe("Offers", function() {

  it("Should not create offer", async function() {
    await expect(  soveren.connect(sig1).makeOffer(3, 1000, [], 20, 5 ))
        .to.be.revertedWith('SOVEREN: You do not have such token')
  });

  it("Should create offer", async function() {
    await soveren.connect(sig1).mint(3, 100, uri1, private1, true)
    expect(await soveren.balanceOf(adr1, 3)).to.equal(100);
    await soveren.connect(sig1).makeOffer(3, 100, [1,2,3,4,5], 20, 5 )
    expect(await soveren.getOffer(adr1, 3)).to.deep.equal(
        [ethers.BigNumber.from(100), [1,2,3,4,5], 20, 5 ]
    );
  });

  it("Should remove offer", async function() {
    await soveren.connect(sig1).removeOffer(3)
    expect(await soveren.getOffer(adr1, 3)).to.deep.equal(
        [ethers.BigNumber.from(0), [], 0, 0 ]
    );
  });

  it("Should create offer", async function() {
    await soveren.connect(sig1).makeOffer(3, 1000, [1,2,3,4,5], 20, 5 )
    expect(await soveren.getOffer(adr1, 3)).to.deep.equal(
        [ethers.BigNumber.from(1000), [1,2,3,4,5], 20, 5 ]
    );
  });

  it("Should getPriceForAmount", async function() {
    expect(await soveren.getPriceForAmount(adr1, 3, 1)).to.equal( 1000);
  });

  it("Should getPriceForAmount x5", async function() {
    expect(await soveren.getPriceForAmount(adr1, 3, 5)).to.equal( 5000);
  });

  // TODO check bulk prices

})

describe.only("Buy", function() {
  it("Should not buy not offered token", async function () {
    await expect(  soveren.connect(sig2).buy(adr1, 4, 1, AddressZero, {value:100}))
        .to.be.revertedWith('SOVEREN: token is not offered')

  })

  it("Should create offer", async function () {
    await soveren.connect(sig1).mint(4, 500, uri1, private1, true)
    expect(await soveren.balanceOf(adr1, 4)).to.equal(500);
    await soveren.connect(sig1).makeOffer(4, 100, [1, 2, 3, 4, 5], 20, 5)
    expect(await soveren.getOffer(adr1, 4)).to.deep.equal(
        // 20% - affiliate interest, 5% donation
        [ethers.BigNumber.from(100), [1, 2, 3, 4, 5], 20, 5]
    )
  })

  it("Should not get privateUri", async function () {
    await expect(  soveren.connect(sig2).privateUri(4))
        .to.be.revertedWith('SOVEREN: You do not have such token')
  })

  it("Should not buy (wrong value)", async function () {
    await expect(  soveren.connect(sig2).buy(adr1, 4, 1, adr3, {value:1}))
        .to.be.revertedWith('SOVEREN: value is not equal to amount price')
  })

  it("Should not buy (amount exceeds supply)", async function () {
    await expect(  soveren.connect(sig2).buy(adr1, 4, 999999, adr3, {value:1}))
        .to.be.revertedWith('SOVEREN: amount exceeds supply')
  })

  it("Should buy 1 with affiliate", async function () {
    await expect(() => soveren.connect(sig2).buy(adr1, 4, 1, adr3, {value:100}))
        .to.changeEtherBalances([sig2, sigContract], [-100,0]) //TODO -100,100
    expect(await soveren.balanceOf(adr1, 4)).to.equal(499);
    expect(await soveren.balanceOf(adr2, 4)).to.equal(1);
    // affiliate profit 20% = 20, donation 5% from 80 = 4, seller profit = (100-(80+4)) = 76
    expect(await soveren.payments(adr1)).to.equal(76);
    expect(await soveren.payments(adr3)).to.equal(20);
    expect(await soveren.payments(adrOwner)).to.equal(4);
  })

  it("Should get privateUri", async function () {
    expect( await soveren.connect(sig2).privateUri(4)).to.equal("private1");
  })

  it("Should buy 1 w/o affiliate", async function () {
    await expect(() => soveren.connect(sig2).buy(adr1, 4, 1, AddressZero, {value:100}))
        .to.changeEtherBalances([sig2, sigContract], [-100,0]) //TODO -100,100
    expect(await soveren.balanceOf(adr1, 4)).to.equal(498);
    expect(await soveren.balanceOf(adr2, 4)).to.equal(2);
    // affiliate profit 0, donation 5% from 100 = 5, seller profit = (100-5) = 95
    expect(await soveren.payments(adr1)).to.equal(76+95);
    expect(await soveren.payments(adrOwner)).to.equal(4+5);
  })

  it("Should buy 5 with affiliate", async function () {
    await expect(() => soveren.connect(sig2).buy(adr1, 4, 5, adr3, {value:100*5}))
        .to.changeEtherBalances([sig2, sigContract], [-100*5,0]) //TODO -100,100
    expect(await soveren.balanceOf(adr1, 4)).to.equal(498-5);
    expect(await soveren.balanceOf(adr2, 4)).to.equal(2+5);
    // affiliate profit 20% = 20*5, donation 5% from 80 = 4*5, seller profit = (100-(80+4)) = 76*5 = 380
    expect(await soveren.payments(adr1)).to.equal(76+95+380);
    expect(await soveren.payments(adr3)).to.equal(20+20*5);
    expect(await soveren.payments(adrOwner)).to.equal(4+5+4*5);
  })

  // TODO bulkPrices buy, withdrawals

})
