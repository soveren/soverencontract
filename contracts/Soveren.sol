// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/payment/PullPayment.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "hardhat/console.sol"; //TODO check what log removed for production https://hardhat.org/plugins/hardhat-log-remover.html

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
        uint256 reserve;          // how many tokens reserve (do not sell)
        uint8[] bulkDiscounts;    // discounts array for amount of 10,100,1000 etc.
        uint8 affiliateInterest;  // how many percents will receive promoter (0-99)
        uint8 donation;           // per product donation (percents, 0-99)
    }

    // Mapping to products
    mapping(uint256 => Product) private _products;

    // Mapping from token ID to offers
    mapping (uint256 => mapping(address => Offer)) private _offers;

    string constant  _DO_NOT_HAVE_SUCH_TOKEN     = "SOVEREN: You do not have such token";
    string constant  _TOKEN_IS_NOT_OFFERED       = "SOVEREN: Token is not offered";
    string constant  _PERCENTS_MUST_BE_LESS_100  = "SOVEREN: Percents must be less 100";
    string constant  _ONLY_OWNER_CAN_TRANSFER    = "SOVEREN: Only owner can transfer";

    event buySingle(address payable seller, uint256 id, uint256 amount, address payable affiliate);

    address payable addressForDonations;

    constructor() ERC1155("") {
        addressForDonations = msg.sender;
    }

    function makeOffer(uint256 id, uint256 price, uint256 reserve, uint8[] memory bulkDiscounts, uint8 affiliateInterest, uint8 donation ) external virtual {
        require( balanceOf(msg.sender, id)>0, _DO_NOT_HAVE_SUCH_TOKEN);
        require( affiliateInterest<100, _PERCENTS_MUST_BE_LESS_100);
        require( donation<100, _PERCENTS_MUST_BE_LESS_100);

        uint8 lastDiscount=0;
        for(uint i=0; i<bulkDiscounts.length;i++) {
            uint8 discount = bulkDiscounts[i];
            require( discount<100, _PERCENTS_MUST_BE_LESS_100);
            require( discount>lastDiscount, "SOVEREN: Each next discount must be higher");
            lastDiscount=discount;
        }

        _offers[id][msg.sender] = Offer({
            price: price, reserve: reserve, bulkDiscounts: bulkDiscounts,
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
        Offer memory offer = _offers[id][seller];
        uint256 basePrice = offer.price;
        require( basePrice > 0, _TOKEN_IS_NOT_OFFERED );

        uint8[] memory bulkDiscounts = offer.bulkDiscounts;
        uint8 discount = 0;
        uint256 discountAmount = 10;

        for(uint i=0; i<bulkDiscounts.length; i++) {
            if (amount>=discountAmount) discount=bulkDiscounts[i];
            else break;
            discountAmount*=10;
        }

        uint256 discountedPrice = basePrice.mul(100-discount).div(100);
        uint256 totalPrice = discountedPrice.mul(amount);
        return totalPrice;
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return true; // for now we approve transfers from all accounts for buy method below
    }

    function getOfferedAmount(address payable seller, uint256 id) public view virtual returns (uint256){
        uint256 balance = balanceOf(seller, id);
        uint256 reserve = _offers[id][seller].reserve;
        if (balance > reserve) return balance.sub(reserve);
        else return 0;
    }

    function buy(address payable seller, uint256 id, uint256 amount, address payable affiliate) external payable virtual {
        Offer storage offer = _offers[id][seller];
        require( offer.price>0, _TOKEN_IS_NOT_OFFERED);
        require( getOfferedAmount(seller, id)>=amount, "SOVEREN: amount exceeds supply");
        uint256 price = getPriceForAmount(seller, id, amount);
        require( msg.value == price, "SOVEREN: value is not equal to amount price");

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
        if (affiliateProfit>0) _asyncTransfer( affiliate, affiliateProfit);
        if (donationProfit>0)  _asyncTransfer( addressForDonations, donationProfit);

        // Transfer tokens to buyer
        super.safeTransferFrom( seller, msg.sender, id, amount, msg.data);
        emit buySingle(seller, id, amount, affiliate);
    }


    function uri(uint256 id) external view virtual override returns (string memory) {
        return _products[id].uri;
    }

    function privateUri(uint256 id) external view virtual returns (string memory) {
        require(balanceOf(msg.sender, id)>0, "SOVEREN: You do not have such token");
        return _products[id].privateUri;
    }

    function mint(uint256 id, uint256 amount, string memory uri_, string memory privateUri_, bool canMintMore)
    public virtual {
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

    function mintMore(uint256 id, uint256 amount) external virtual {
        require( _products[id].creator == msg.sender, "SOVEREN: Mint more can token creator only");
        require( _products[id].canMintMore, "SOVEREN: mintMore disabled");

        _mint(msg.sender, id, amount, msg.data);
    }


    function burn(uint256 id, uint256 amount) external virtual {
        _burn(msg.sender, id, amount);
    }

    function safeTransferFrom( address from, address to, uint256 id, uint256 amount, bytes memory data)
    public virtual override
    {
        require(from == msg.sender, _ONLY_OWNER_CAN_TRANSFER );
        super.safeTransferFrom( msg.sender, to, id, amount, data);
    }

    function safeBatchTransferFrom( address from, address to, uint256[] memory ids,
        uint256[] memory amounts, bytes memory data
    ) public virtual override
    {
        require(from == msg.sender, _ONLY_OWNER_CAN_TRANSFER );
        super.safeBatchTransferFrom(msg.sender, to, ids, amounts, data);
    }
    



}