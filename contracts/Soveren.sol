// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/payment/PullPayment.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
//import "hardhat/console.sol"; //TODO check what log removed for production https://hardhat.org/plugins/hardhat-log-remover.html

contract Soveren is ERC1155, PullPayment, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMath for uint32;

    struct Vote {
        string comment;
        uint8 rating;
    }

    struct Product {
        address payable creator;  // product creator
        string uri;               // metadata uri
        string privateUri;        // simple DRM for digital products
        bool canMintMore;         // is it possible to mint more tokens of this type?
        uint32 votesCount;
        uint256 accumulatedRating;
        mapping (address => Vote) votes;
        mapping (uint32 => address) votesIndex;
    }

    struct Offer {
        uint256 price;            // base price ETH
        uint256 reserve;          // how many tokens reserve (do not sell)
        uint8[] bulkDiscounts;    // discounts array for amount of 10,100,1000 etc.
        uint8 affiliateInterest;  // how many percents will receive promoter (0-99)
        uint8 donation;           // per product donation (percents, 0-99)
    }

    // Mapping to products
    mapping (uint256 => Product) private _products;

    // Mapping from token ID to offers
    mapping (uint256 => mapping(address => Offer)) private _offers;

    bytes4 private constant  _INTERFACE_ID_SOVEREN = 0x5356524E; // 'SVRN'

    string private constant _DO_NOT_HAVE_SUCH_TOKEN     = "SOVEREN: You do not have such token";
    string private constant _TOKEN_IS_NOT_OFFERED       = "SOVEREN: Token is not offered";
    string private constant _PERCENTS_MUST_BE_LESS_100  = "SOVEREN: Percents must be less 100";
    string private constant _ONLY_OWNER_CAN_TRANSFER    = "SOVEREN: Only owner can transfer";

    event buySingle(address payable seller, uint256 id, uint256 amount, address payable affiliate);

    address payable addressForDonations;

    constructor() ERC1155("") {
        addressForDonations = msg.sender;
        // register the supported interfaces to conform to ERC1155 via ERC165
        _registerInterface(_INTERFACE_ID_SOVEREN);
    }

    function vote(uint256 id, uint8 rating, string memory comment) external virtual {
        require( bytes(comment).length<=140, "SOVEREN: comment length must not more 140 bytes");
        require(rating>0, "SOVEREN: rating must not be 0");

        Product storage product = _products[id];
        require( product.creator != address(0), "SOVEREN: Token not found");

        Vote storage vote = product.votes[msg.sender];
        bool ratedBefore = vote.rating > 0;

        if (ratedBefore)
            product.accumulatedRating.sub(vote.rating); // decrease old value first
        else {
            product.votesIndex[product.votesCount] = msg.sender;
            product.votesCount.add(1);
        }

        vote.rating = rating;
        vote.comment = comment;
        product.accumulatedRating.add(rating);
    }

    function getRating(uint256 id) public view virtual returns (uint8) {
        Product storage product = _products[id];
        if (product.votesCount==0) return 0;
        else return uint8(product.accumulatedRating.div(product.votesCount));
    }

    function getVotesCount(uint256 id) public view virtual returns (uint32) {
        return _products[id].votesCount;
    }

    /**
     * @dev Returns last count votes, skipping skip items
     */
    function getVotes(uint256 id, uint32 skip, uint32 count) public view virtual returns (Vote[] memory) {
        require(count<=100, "SOVEREN: count must be not more 100");

        Product storage product = _products[id];
        Vote[] memory votes = new Vote[](count);

        for (uint32 i=1; i<=count; i++ ) {
            address voter = product.votesIndex[product.votesCount-i];
            votes[i] = product.votes[ voter ];
        }

        return votes;
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

    function buy(address payable seller, uint256 id, uint256 amount, address payable affiliate)
    external payable virtual nonReentrant {
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
    public virtual nonReentrant {
        require( _products[id].creator == address(0), "SOVEREN: Token already exists");

        address payable creator = msg.sender;
        Product storage product = _products[id];
        product.creator = creator;
        product.uri = uri_;
        product.privateUri = privateUri_;
        product.canMintMore = canMintMore;

        _mint(creator, id, amount, msg.data);
    }

    function mintMore(uint256 id, uint256 amount) external virtual nonReentrant {
        require( _products[id].creator == msg.sender, "SOVEREN: Mint more can token creator only");
        require( _products[id].canMintMore, "SOVEREN: mintMore disabled");

        _mint(msg.sender, id, amount, msg.data);
    }


    function burn(uint256 id, uint256 amount) external virtual nonReentrant {
        _burn(msg.sender, id, amount);
    }

    function safeTransferFrom( address from, address to, uint256 id, uint256 amount, bytes memory data)
    public nonReentrant virtual override
    {
        require(from == msg.sender, _ONLY_OWNER_CAN_TRANSFER );
        super.safeTransferFrom( msg.sender, to, id, amount, data);
    }

    function safeBatchTransferFrom( address from, address to, uint256[] memory ids,
        uint256[] memory amounts, bytes memory data
    ) public nonReentrant virtual override
    {
        require(from == msg.sender, _ONLY_OWNER_CAN_TRANSFER );
        super.safeBatchTransferFrom(msg.sender, to, ids, amounts, data);
    }
    



}