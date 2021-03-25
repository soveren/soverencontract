const { ethers } = require("hardhat");
const { expect } = require("chai");

// const chai = require("chai");
// const { solidity } = require("ethereum-waffle");
// chai.use(solidity);


let soveren, ownerSig, sig1, sig2, a1, a2;

const uri1 = 'uri1'
const uri2 = 'uri2'

const private1 = 'private1'
const private2 = 'private2'

before(async function () {
  const Soveren = await ethers.getContractFactory("Soveren");
  soveren = await Soveren.deploy();
  await soveren.deployed();

  [ownerSig, sig1, sig2] = await ethers.getSigners();
  a1 = sig1.getAddress()
  a2 = sig2.getAddress()
})

describe("Mint & Burn", function() {

  it("Should be 0 before mint", async function() {
    expect(await soveren.balanceOf(a1, 1)).to.equal(0);
  });

  it("Should mint new product", async function() {
    await soveren.connect(sig1).mint(1, 1000, uri1, private1, true)
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
    expect(await soveren.balanceOf(a1, 1)).to.equal(0);
  });

  it("Should not burn exceed sig2", async function() {
    await expect( soveren.connect(sig2).burn(1, 50)).to.be.revertedWith('ERC1155: burn amount exceeds balance')
  });

  it("Should mint new product sig2", async function() {
    await soveren.connect(sig2).mint(2, 500, uri2, private2, false)
    expect(await soveren.balanceOf(a2, 2)).to.equal(500);
  });

  it("Should not mint more", async function() {
    await expect(  soveren.connect(sig2).mintMore(2, 100)).to.be.revertedWith('SOVEREN: mintMore disabled')
  });


  it("Should burn", async function() {
    await soveren.connect(sig2).burn(2, 500)
    expect(await soveren.balanceOf(a2, 2)).to.equal(0);
  });

});

describe.only("Offers & Buy", function() {

  it("Should not create offer", async function() {
    await expect(  soveren.connect(sig1).makeOffer(3, 1000, [], 20, 5 ))
        .to.be.revertedWith('SOVEREN: You do not have such token')
  });

  it("Should create offer", async function() {
    await soveren.connect(sig1).mint(3, 100, uri1, private1, true)
    expect(await soveren.balanceOf(a1, 3)).to.equal(100);
    await soveren.connect(sig1).makeOffer(3, 1000, [1,2,3,4,5], 20, 5 )
    expect(await soveren.getOffer(a1, 3)).to.deep.equal(
        [ethers.BigNumber.from(1000), [1,2,3,4,5], 20, 5 ]
    );
  });

  it("Should remove offer", async function() {
    await soveren.connect(sig1).removeOffer(3)
    expect(await soveren.getOffer(a1, 3)).to.deep.equal(
        [ethers.BigNumber.from(0), [], 0, 0 ]
    );
  });


  it("Should create offer", async function() {
    await soveren.connect(sig1).makeOffer(3, 1000, [1,2,3,4,5], 20, 5 )
    expect(await soveren.getOffer(a1, 3)).to.deep.equal(
        [ethers.BigNumber.from(1000), [1,2,3,4,5], 20, 5 ]
    );
  });

  // TODO buy, check profits, privateUri, buy wrong value, buy a lot,
});
