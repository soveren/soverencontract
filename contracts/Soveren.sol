// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/payment/PullPayment.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "hardhat/console.sol";

contract Soveren is ERC1155, PullPayment {
    using SafeMath for uint256;
    using Address for address;

    struct Product {
        address payable creator;  // product creator
        string uri;               // metadata uri
        string privateUri;        // simple DRM for digital products
        bool canMintMore;         // is it possible to mint more tokens of this type?
    }

    struct Offer {
        uint256 price;            // base price ETH
        uint8[] bulkDiscounts;    // discounts array for amount of 10,100,1000 etc.
        uint8 affiliateInterest;  // how many percents will receive promoter (0-99)
        uint8 donation;           // per product donation (percents, 0-99)
    }

    // Mapping to products
    mapping(uint256 => Product) private _products;

    // Mapping from token ID to offers
    mapping (uint256 => mapping(address => Offer)) private _offers;

    string constant  _DO_NOT_HAVE_SUCH_TOKEN = "SOVEREN: You do not have such token";

    address payable addressForDonations;

    constructor() ERC1155("") {
        addressForDonations = msg.sender;
    }

    function makeOffer(uint256 id, uint256 price, uint8[] memory bulkDiscounts, uint8 affiliateInterest, uint8 donation ) external virtual {
        require(balanceOf(msg.sender, id)>0, _DO_NOT_HAVE_SUCH_TOKEN);
        // TODO check all fields
        // donation, affiliate, discounts: 0-99
        // every next discount must be bigger
        _offers[id][msg.sender] = Offer({
            price: price, bulkDiscounts: bulkDiscounts,
            affiliateInterest: affiliateInterest, donation:donation
        });
    }

    function removeOffer(uint256 id) external virtual {
        delete _offers[id][msg.sender];
    }

    function getOffer(address payable seller, uint256 id) external view virtual returns (Offer memory){
        return _offers[id][seller];
    }


    function getPriceForAmount(address payable seller, uint256 id, uint256 amount) public view virtual returns (uint256) {
        // TODO calc bulk prices
        uint256 basePrice = _offers[id][seller].price;
        require( basePrice > 0, "SOVEREN: Token is not offered" );
        uint totalPrice = basePrice.mul(amount);
        return totalPrice;
    }

    function buy(address payable seller, uint256 id, uint256 amount, address payable affiliate) external payable virtual {
        require( balanceOf(seller, id)>=amount, "SOVEREN: amount exceeds supply");
        uint256 price = getPriceForAmount(seller, id, amount);
        require( msg.value == price, "SOVEREN: value is not equal to amount price");

        Offer storage offer = _offers[id][seller];
        uint256 affiliateProfit = 0;
        uint256 donationProfit = 0;

        if ((affiliate!=address(0)) && (offer.affiliateInterest>0)) {
            affiliateProfit = price.mul(offer.affiliateInterest).div(100);
        }

        if ((offer.donation>0) && (addressForDonations!=address(0))) {
            donationProfit = price.sub(affiliateProfit).mul(offer.donation).div(100);
        }

        uint256 sellerProfit = price.sub(affiliateProfit).sub(donationProfit);

        // Transfer ETH to the beneficiaries
        _asyncTransfer( seller, sellerProfit);
        _asyncTransfer( affiliate, affiliateProfit);
        _asyncTransfer( addressForDonations, donationProfit);

        // Transfer tokens to buyers
        safeTransferFrom( seller, msg.sender, id, amount, msg.data);
    }


    function uri(uint256 id) external view virtual override returns (string memory) {
        return _products[id].uri;
    }

    function privateUri(uint256 id) external view virtual returns (string memory) {
        require(balanceOf(msg.sender, id)>0, "SOVEREN: You do not have such token");
        return _products[id].privateUri;
    }

    function mint(uint256 id, uint256 amount, string memory uri_, string memory privateUri_, bool canMintMore) public virtual {
        require( _products[id].creator == address(0), "SOVEREN: Token already exists");

        address payable creator = msg.sender;
        _products[id] = Product({
            creator:creator,
            uri:uri_,
            privateUri:privateUri_,
            canMintMore:canMintMore
        });

        _mint(creator, id, amount, msg.data);
    }

    function mintMore(uint256 id, uint256 amount) public virtual {
        require( _products[id].creator == msg.sender, "SOVEREN: Mint more can token creator only");
        require( _products[id].canMintMore, "SOVEREN: mintMore disabled");

        _mint(msg.sender, id, amount, msg.data);
    }


    function burn(uint256 id, uint256 amount) public virtual {
        _burn(msg.sender, id, amount);
    }



}