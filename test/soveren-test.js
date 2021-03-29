const { ethers } = require("hardhat");
const { expect } = require("chai");
require("hardhat-typechain");
const BN = ethers.BigNumber.from;


let soveren, sigOwner, adrOwner, adrContract,
    sig1, sig2, sig3,
    adr1, adr2, adr3;

// noinspection JSUnresolvedVariable
const AddressZero = ethers.constants.AddressZero
const uri1 = 'uri1'
const uri2 = 'uri2'

const private1 = 'private1'
const private2 = 'private2'

before(async function () {
  const Soveren = await ethers.getContractFactory("Soveren")
  soveren = await Soveren.deploy()
  await soveren.deployed();

  adrContract = soveren.address;

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
    await expect(soveren.connect(sig2).mint(1, 100, uri1, private1, true))
        .to.be.revertedWith('SOVEREN: Token already exists')
  });

  it("Should not mint more from another address", async function() {
    await expect(soveren.connect(sig2).mintMore(1, 100))
        .to.be.revertedWith('SOVEREN: Mint more can token creator only')
  });

  it("Should not burn exceed", async function() {
    await expect( soveren.connect(sig1).burn(1, 99999))
        .to.be.revertedWith('ERC1155: burn amount exceeds balance')
  });

  it("Should burn", async function() {
    await soveren.connect(sig1).burn(1, 1100)
    expect(await soveren.balanceOf(adr1, 1)).to.equal(0);
  });

  it("Should not burn exceed sig2", async function() {
    await expect( soveren.connect(sig2).burn(1, 50))
        .to.be.revertedWith('ERC1155: burn amount exceeds balance')
  });

  it("Should mint new product sig2", async function() {
    await soveren.connect(sig2).mint(2, 500, uri2, private2, false)
    expect(await soveren.balanceOf(adr2, 2)).to.equal(500);
  });

  it("Should not mint more", async function() {
    await expect(  soveren.connect(sig2).mintMore(2, 100))
        .to.be.revertedWith('SOVEREN: mintMore disabled')
  });


  it("Should burn", async function() {
    await soveren.connect(sig2).burn(2, 500)
    expect(await soveren.balanceOf(adr2, 2)).to.equal(0);
  });

})

describe("Offers", function() {

  it("Should not create offer", async function() {
    await expect(  soveren.connect(sig1).makeOffer(3, 1000, 0,[], 20, 5 ))
        .to.be.revertedWith('SOVEREN: You do not have such token')
  });

  it("Should create offer", async function() {
    await soveren.connect(sig1).mint(3, 100, uri1, private1, true)
    expect(await soveren.balanceOf(adr1, 3)).to.equal(100);
    await soveren.connect(sig1).makeOffer(3, 100, 110, [1,2,3,4,5], 20, 5 )
    expect(await soveren.getOffer(adr1, 3)).to.deep.equal(
        [BN(100), BN(110), [1,2,3,4,5], 20, 5 ]
    );
  });

  it("Offered amount must be 0 (minted 100, reserved 110)", async function() {
    expect(await soveren.getOfferedAmount(adr1, 3)).to.equal(0);
  });

  it("Should not create offer (affiliateInterest too high)", async function() {
    await expect(  soveren.connect(sig1).makeOffer(3, 1000, 0,[], 100, 5 ))
        .to.be.revertedWith('SOVEREN: Percents must be less 100')
  });

  it("Should not create offer (donation too high)", async function() {
    await expect(  soveren.connect(sig1).makeOffer(3, 1000, 0, [], 10, 100 ))
        .to.be.revertedWith('SOVEREN: Percents must be less 100')
  });

  it("Should not create offer (wrong discounts order)", async function() {
    await expect(  soveren.connect(sig1).makeOffer(3, 1000, 0, [1,2,3,4,1,5], 10, 1 ))
        .to.be.revertedWith('SOVEREN: Each next discount must be higher')
  });

  it("Should not create offer (discount too high)", async function() {
    await expect(  soveren.connect(sig1).makeOffer(3, 1000, 0,[1,2,3,4,100,5], 10, 1 ))
        .to.be.revertedWith('SOVEREN: Percents must be less 100')
  });

  it("Should remove offer", async function() {
    await soveren.connect(sig1).removeOffer(3)
    expect(await soveren.getOffer(adr1, 3)).to.deep.equal(
        [BN(0), BN(0), [], 0, 0 ]
    );
  });

  it("Should create offer", async function() {
    await soveren.connect(sig1).makeOffer(3, 1000, 0, [1,2,3,4,5], 20, 5 )
    expect(await soveren.getOffer(adr1, 3)).to.deep.equal(
        [BN(1000), BN(0), [1,2,3,4,5], 20, 5 ]
    );
  });

  it("Should not getPriceForAmount", async function() {
    await expect( soveren.getPriceForAmount(adr1, 99999, 1))
      .to.be.revertedWith('SOVEREN: Token is not offered')
  });

  it("Should getPriceForAmount", async function() {
    expect(await soveren.getPriceForAmount(adr1, 3, 1)).to.equal( 1000);
  });

  it("Should getPriceForAmount x5", async function() {
    expect(await soveren.getPriceForAmount(adr1, 3, 5)).to.equal( 5000);
  });

  it("Should getPriceForAmount x10", async function() {
    expect(await soveren.getPriceForAmount(adr1, 3, 10)).to.equal( 9900);
  });

  it("Should getPriceForAmount x100", async function() {
    expect(await soveren.getPriceForAmount(adr1, 3, 100)).to.equal( 98000);
  });

  it("Should getPriceForAmount x1000", async function() {
    expect(await soveren.getPriceForAmount(adr1, 3, 1000)).to.equal( 970000);
  });

  it("Should getPriceForAmount x100000", async function() {
    expect(await soveren.getPriceForAmount(adr1, 3, 100000)).to.equal( 95000000);
  });

})

describe("Buy", function() {
  it("Should not buy not offered token", async function () {
    await expect(  soveren.connect(sig2).buy(adr1, 4, 1, AddressZero, {value:100}))
        .to.be.revertedWith('SOVEREN: Token is not offered')
  })

  it("Should create offer", async function () {
    await soveren.connect(sig1).mint(4, 500, uri1, private1, true)
    expect(await soveren.balanceOf(adr1, 4)).to.equal(500);
    await soveren.connect(sig1).makeOffer(4, 100, 400, [1, 2, 3, 4, 5], 20, 5)
    expect(await soveren.getOffer(adr1, 4)).to.deep.equal(
        // 20% - affiliate interest, 5% donation
        [BN(100), BN(400), [1, 2, 3, 4, 5], 20, 5]
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

  it("Should not buy (amount exceeds amount offered)", async function () {
    await expect(  soveren.connect(sig2).buy(adr1, 4, 101, adr3, {value:1}))
        .to.be.revertedWith('SOVEREN: amount exceeds supply')
  })

  it("Should buy 1 with affiliate", async function () {
    await expect(() => soveren.connect(sig2).buy(adr1, 4, 1, adr3, {value:100}))
        .to.changeEtherBalance(sig2, -100);
    expect(await soveren.balanceOf(adr1, 4)).to.equal(499);
    expect(await soveren.balanceOf(adr2, 4)).to.equal(1);
    // affiliate profit 20% = 20, donation 5% from 80 = 4, seller profit = (100-(80+4)) = 76
    // expect(await ethers.provider.getBalance(soveren.address)).to.equal(100);
    // expect(await ethers.provider.getBalance(adr2)).to.equal(100);
    expect(await soveren.payments(adr1)).to.equal(76);
    expect(await soveren.payments(adr3)).to.equal(20);
    expect(await soveren.payments(adrOwner)).to.equal(4);
  })

  it("Should get privateUri", async function () {
      expect( await soveren.connect(sig2).privateUri(4)).to.equal("private1");
  })

  it("Should buy 1 w/o affiliate", async function () {
    await expect(() => soveren.connect(sig2).buy(adr1, 4, 1, AddressZero, {value:100}))
        .to.changeEtherBalance(sig2, -100);
    expect(await soveren.balanceOf(adr1, 4)).to.equal(498);
    expect(await soveren.balanceOf(adr2, 4)).to.equal(2);
    // affiliate profit 0, donation 5% from 100 = 5, seller profit = (100-5) = 95
    expect(await soveren.payments(adr1)).to.equal(76+95);
    expect(await soveren.payments(adrOwner)).to.equal(4+5);
  })

  it("Should buy 5 with affiliate", async function () {
    await expect(() => soveren.connect(sig2).buy(adr1, 4, 5, adr3, {value:100*5}))
        .to.changeEtherBalance(sig2, -100*5);
    expect(await soveren.balanceOf(adr1, 4)).to.equal(498-5);
    expect(await soveren.balanceOf(adr2, 4)).to.equal(2+5);
    // affiliate profit 20% = 20*5, donation 5% from 80 = 4*5, seller profit = (100-(80+4)) = 76*5 = 380
    expect(await soveren.payments(adr1)).to.equal(76+95+380);
    expect(await soveren.payments(adr3)).to.equal(20+20*5);
    expect(await soveren.payments(adrOwner)).to.equal(4+5+4*5);
  })

  it("Should create offer w/o affiliate & donation", async function () {
    await soveren.connect(sig1).makeOffer(4, 100, 0, [1, 2, 3, 4, 5], 0, 0)
    expect(await soveren.getOffer(adr1, 4)).to.deep.equal(
        // 0% - affiliate interest, 0% donation
        [BN(100), BN(0), [1, 2, 3, 4, 5], 0, 0]
    )
  })

  it("Should buy 1 w/o affiliate & donation", async function () {
    await expect(() => soveren.connect(sig2).buy(adr1, 4, 1, AddressZero, {value:100}))
        .to.changeEtherBalance(sig2, -100);
    expect(await soveren.balanceOf(adr1, 4)).to.equal(498-5-1);
    expect(await soveren.balanceOf(adr2, 4)).to.equal(2+5+1);
    // affiliate profit 0, donation 0, seller profit = (100-(0+0)) = 100
    expect(await soveren.payments(adr1)).to.equal(76+95+380+100);
  })

  it("Should buy 100 with discount 3%", async function () {
    await expect(() => soveren.connect(sig2).buy(adr1, 4, 100, AddressZero, {value:9800}))
        .to.changeEtherBalance(sig2, -9800);
    expect(await soveren.balanceOf(adr1, 4)).to.equal(498-5-1-100);
    expect(await soveren.balanceOf(adr2, 4)).to.equal(2+5+1+100);
    // affiliate profit 0, donation 0, seller profit = (100-(0+0)) = 100
    expect(await soveren.payments(adr1)).to.equal(76+95+380+100+9800);
  })

  it("Should withdraw payments seller", async function () {
    await expect(() => soveren.connect(sig1).withdrawPayments(adr1))
        .to.changeEtherBalance(sig1, 76+95+380+100+9800)
    expect(await soveren.payments(adr1)).to.equal(0);
  })

  it("Should withdraw payments affiliate", async function () {
    await expect(() => soveren.connect(sig3).withdrawPayments(adr3))
        .to.changeEtherBalance(sig3, 20+20*5);
    expect(await soveren.payments(adr3)).to.equal(0);
  })

  it("Should withdraw donations owner", async function () {
    await expect(() => soveren.connect(sigOwner).withdrawPayments(adrOwner))
        .to.changeEtherBalance(sigOwner, 4+5+4*5);
    expect(await soveren.payments(adrOwner)).to.equal(0);
  })


  it("Should not transfer (only owner can transfer)", async function () {
    await expect( soveren.connect(sig3)
        .safeTransferFrom(adr2, adr3, 4, 1, 0x0 ))
        .to.be.revertedWith('SOVEREN: Only owner can transfer')
  })

  it("Should not batch transfer (only owner can transfer)", async function () {
    await expect( soveren.connect(sig3)
        .safeBatchTransferFrom(adr2, adr3, [4], [1], 0x0 ))
        .to.be.revertedWith('SOVEREN: Only owner can transfer')
  })

  it("Should not transfer (insufficient balance)", async function () {
    await expect( soveren.connect(sig2)
        .safeTransferFrom(adr2, adr3, 4, 99999, 0x0 ))
        .to.be.revertedWith('ERC1155: insufficient balance for transfer')
  })

  it("Should transfer ", async function () {
    const bal2 = await soveren.balanceOf(adr2, 4)
    const bal3 = await soveren.balanceOf(adr3, 4)
    await soveren.connect(sig2).transfer(adr3, 4, 10 )
    expect(await soveren.balanceOf(adr2, 4)-bal2).to.equal(-10);
    expect(await soveren.balanceOf(adr3, 4)-bal3).to.equal(+10);
  })

  it("Should batch transfer ", async function () {
    await soveren.connect(sig2).mint(5, 1000, 'uri5', 'private5', true)
    await soveren.connect(sig2).mint(6, 1000, 'uri6', 'private6', true)
    const bal2_5 = await soveren.balanceOf(adr2, 5)
    const bal2_6 = await soveren.balanceOf(adr2, 6)
    const bal3_5 = await soveren.balanceOf(adr3, 5)
    const bal3_6 = await soveren.balanceOf(adr3, 6)
    await soveren.connect(sig2).batchTransfer(adr3, [5,6], [50,6]  )
    expect(await soveren.balanceOf(adr2, 5)-bal2_5).to.equal(-50);
    expect(await soveren.balanceOf(adr2, 6)-bal2_6).to.equal(-6);
    expect(await soveren.balanceOf(adr3, 5)-bal3_5).to.equal(+50);
    expect(await soveren.balanceOf(adr3, 6)-bal3_6).to.equal(+6);
  })

})

describe("Rating", function() {

  it("Should not vote (wrong token)", async function () {
    await expect(soveren.connect(sig2).vote(7, 1, 'comment'))
      .to.be.revertedWith('SOVEREN: Token not found')
  })

  it("Should not vote (rating 0)", async function () {
    await expect(soveren.connect(sig2).vote(7, 0, 'comment'))
      .to.be.revertedWith('SOVEREN: rating must not be 0')
  })

  it("Should not vote (comment loo long)", async function () {
    await expect(soveren.connect(sig2).vote(7, 1, 'comment'.repeat(100)))
      .to.be.revertedWith('SOVEREN: comment length must not exceed 140 bytes')
  })

  it("Should getRating 0", async function () {
    await soveren.connect(sig1).mint(7,1000, uri1, private1, true)
    expect( await soveren.getRating(7))
      .to.equal(0)
  })

  it("Should getVotesCount 0", async function () {
    expect( await soveren.getVotesCount(7))
      .to.equal(0)
  })

  it("Should vote ", async function () {
    await soveren.connect(sig1).vote(7, 50, 'comment')
    expect( await soveren.connect(sig1).getVote(7))
      .to.be.deep.equal([50, 'comment'])
  })

  it("Should getVotesCount 1", async function () {
    expect( await soveren.getVotesCount(7))
        .to.equal(1)
  })

  it("Should getRating 50", async function () {
    expect( await soveren.getRating(7))
        .to.equal(50)
  })

  it("Should vote again", async function () {
    await soveren.connect(sig1).vote(7, 100, 'comment 2')
    expect( await soveren.connect(sig1).getVote(7))
      .to.be.deep.equal([100, 'comment 2'])
  })

  it("Should getVotesCount 1", async function () {
    expect( await soveren.getVotesCount(7))
        .to.equal(1)
  })

  it("Should getRating 100", async function () {
    expect( await soveren.getRating(7))
        .to.equal(100)
  })

  it("Should vote sig2", async function () {
    await soveren.connect(sig2).vote(7, 200, 'comment sig 2')
    expect( await soveren.connect(sig2).getVote(7))
        .to.be.deep.equal([200, 'comment sig 2'])
  })

  it("Should getVotesCount 2", async function () {
    expect( await soveren.getVotesCount(7))
        .to.equal(2)
  })

  it("Should getRating 100", async function () {
    expect( await soveren.getRating(7))
        .to.equal(150)
  })


  // it("Should create offer", async function () {
  //   await soveren.connect(sig1).mint(4, 500, uri1, private1, true)
  //   expect(await soveren.balanceOf(adr1, 4)).to.equal(500);
  //   await soveren.connect(sig1).makeOffer(4, 100, 400, [1, 2, 3, 4, 5], 20, 5)
  //   expect(await soveren.getOffer(adr1, 4)).to.deep.equal(
  //       // 20% - affiliate interest, 5% donation
  //       [BN(100), BN(400), [1, 2, 3, 4, 5], 20, 5]
  //   )
  // })
})
