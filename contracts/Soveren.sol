// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/payment/PullPayment.sol";
//import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
//import "hardhat/console.sol";

/// @title Contract for free and sovereign market
/// @author Slavik V Bogdanov
/// @dev This contract utilized at the soverenjs library and Soveren Vue app.
/// @dev `solidity-docgen` comment tag @param do not work for some reason for now, so @dev used for now.
contract Soveren is ERC1155, PullPayment/*, ReentrancyGuard*/ {
    using SafeMath for uint256;
    using SafeMath for uint32;

    struct Vote {
        uint8 rating;
        string comment;
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

    struct Profile {
        string uri;               // profile metadata uri
        uint32 productsCount;
        uint32 offersCount;
        mapping (uint32 => uint256) productsIndex;
        mapping (uint32 => uint256) offersIndex;
    }

    // Mapping to profiles
    mapping (address => Profile) private _profiles;

    // Mapping to products
    mapping (uint256 => Product) private _products;

    // Mapping from token ID to offers
    mapping (uint256 => mapping(address => Offer)) private _offers;

    bytes4 private constant  _INTERFACE_ID_SOVEREN = 0x5356524E; // 'SVRN'

    string private constant _TOKEN_NOT_FOUND            = "SV: id not found";
    string private constant _ACCESS_DENIED              = "SV: Access denied";
    string private constant _WRONG_PARAM_VALUE          = "SV: Wrong param";

    event buySingle(address payable seller, uint256 id, uint256 amount, address payable affiliate);
    event offer(uint256 id, uint256 price, uint256 reserve, uint8[] bulkDiscounts, uint8 affiliateInterest, uint8 donation);

    address payable addressForDonations;

    constructor() ERC1155("") {
        addressForDonations = msg.sender;
        // register the supported interfaces to conform to SOVEREN via ERC165
        _registerInterface(_INTERFACE_ID_SOVEREN);
    }

    // MINTING, BURNING, TRANSFER

    /// @dev Creates `amount` tokens of new token type `id`, and assigns them to sender.
    /// @dev When you mints more all
    /// @param id Token id
    /// @param amount how many pieces to mint
    /// @param uri_ metadata uri https://eips.ethereum.org/EIPS/eip-1155#metadata
    /// @param privateUri_ uri of paid file (accessed to token holders only)
    /// @param canMintMore set to `true` to enable additional minting
    function mint(uint256 id, uint256 amount, string memory uri_, string memory privateUri_, bool canMintMore)
    public virtual /*nonReentrant*/ {
        if (_products[id].creator == address(0)) { // new token

            address payable creator = msg.sender;
            Product storage product = _products[id];
            product.creator = creator;
            product.uri = uri_;
            product.privateUri = privateUri_;
            product.canMintMore = canMintMore;

            _mint(creator, id, amount, msg.data);

            Profile storage profile = _profiles[msg.sender];
            for (uint32 i=0; i<profile.productsCount; i++ ) {
                if (profile.productsIndex[i]==id) return; // check id already in index
            }
            profile.productsIndex[profile.productsCount] = id;
            profile.productsCount++;
            require( profile.productsCount>0 );

        } else {

            require( _products[id].creator == msg.sender && _products[id].canMintMore, _ACCESS_DENIED);
            _mint(msg.sender, id, amount, msg.data);

        }
    }

    /// @dev Returns `creator` address for token `id`
    function getCreator(uint256 id) external view virtual returns (address payable){
        return _products[id].creator;
    }

    /// @dev Creates `amount` tokens of existing token type `id`, and assigns them to sender
//    function mintMore(uint256 id, uint256 amount) external virtual /*nonReentrant*/ {
//        require( _products[id].creator == msg.sender, "SV: Mint more can token creator only");
//        require( _products[id].canMintMore, "SV: mintMore disabled");
//
//        _mint(msg.sender, id, amount, msg.data);
//    }

    /// @dev Burns `amount` tokens of token type `id`
    function burn(uint256 id, uint256 amount) external virtual /*nonReentrant*/ {
        _burn(msg.sender, id, amount);
    }

    function safeTransferFrom( address from, address to, uint256 id, uint256 amount, bytes memory data)
    public /*nonReentrant*/ virtual override
    {
        require(from == msg.sender, _ACCESS_DENIED );
        super.safeTransferFrom( from, to, id, amount, data);
    }

//    /// @dev Transfers `to` address `amount` tokens of token type `id`
//    function transfer( address to, uint256 id, uint256 amount) public virtual
//    {
//        safeTransferFrom( msg.sender, to, id, amount, msg.data);
//    }

    function safeBatchTransferFrom( address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
    public /*nonReentrant*/ virtual override
    {
        require(from == msg.sender, _ACCESS_DENIED );
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

//    /// @dev Transfers `to` address `amounts` tokens of token types `ids`
//    function batchTransfer( address to, uint256[] memory ids, uint256[] memory amounts)
//    public virtual
//    {
//        safeBatchTransferFrom(msg.sender, to, ids, amounts, msg.data);
//    }

    // OFFERS, BUYING

    /// @dev Creates sale offer of token type `id`.
    /// @dev `price` price for 1 token in wei. Set to 0 to 'remove' offer.
    /// @dev `reserve` Amount of tokens to reserve (do not offer it for sale).
    /// @dev `bulkDiscounts` You can specify bulk discounts at this array for 10+, 100+, 1000+ etc pieces. For example if you set `bulkDiscounts` to `[5,10,20,50]`, then it means what you give 5% discount for 10 and more pieces, 10% for 100+, 20% for 1000+, and 50% discount for 10000 pieces and more.
    /// @dev `affiliateInterest` How many percents from purchase will earn your affiliate. An affiliate program is a great way to motivate other people to promote your tokens.
    /// @dev `donation` How many percents from clear profit you want to automatically donate to support the service.
    function makeOffer(uint256 id, uint256 price, uint256 reserve, uint8[] memory bulkDiscounts, uint8 affiliateInterest, uint8 donation ) external virtual {
        require( balanceOf(msg.sender, id)>0, _TOKEN_NOT_FOUND);
        require( affiliateInterest<100, _WRONG_PARAM_VALUE);
        require( donation<100, _WRONG_PARAM_VALUE);

        uint8 lastDiscount=0;
        for(uint i=0; i<bulkDiscounts.length;i++) {
            uint8 discount = bulkDiscounts[i];
            require( discount<100 && discount>lastDiscount, _WRONG_PARAM_VALUE);
            lastDiscount=discount;
        }

        _offers[id][msg.sender] = Offer({
            price: price, reserve: reserve, bulkDiscounts: bulkDiscounts,
            affiliateInterest: affiliateInterest, donation:donation
        });

        emit offer( id, price, reserve, bulkDiscounts, affiliateInterest, donation );

        Profile storage profile = _profiles[msg.sender];
        for (uint32 i=0; i<profile.offersCount; i++ ) {
            if (profile.offersIndex[i]==id) return; // check id already in index
        }
        profile.offersIndex[profile.offersCount] = id;
        profile.offersCount++;
        require( profile.offersCount>0 ); // overflow check

    }

    /// @dev Removes sale offer of token type `id`
//    function removeOffer(uint256 id) external virtual {
//        delete _offers[id][msg.sender];
//    }

    /// @dev Returns `seller`s sale offer of token type `id`
    function getOffer(address payable seller, uint256 id) external view virtual returns (Offer memory){
        return _offers[id][seller];
    }

    /// @dev See {IERC1155-isApprovedForAll}.
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return true; // for now we approve transfers from all accounts for buy method below
    }

    /// @dev Returns `seller`s offered amount of token type `id`
    function getOfferedAmount(address payable seller, uint256 id) public view virtual returns (uint256){
        if (_offers[id][seller].price==0) return 0; // if price 0 then
        uint256 balance = balanceOf(seller, id);
        uint256 reserve = _offers[id][seller].reserve;
        if (balance > reserve) return balance.sub(reserve);
        else return 0;
    }

    /// @dev Returns total `seller` price in wei for specified `amount` of token type `id` (`bulkDiscounts` applied)
    function getPriceForAmount(address payable seller, uint256 id, uint256 amount) public view virtual returns (uint256) {
        Offer memory offer = _offers[id][seller];
        uint256 basePrice = offer.price;
        require( basePrice > 0, _TOKEN_NOT_FOUND );

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

    /// @dev Process purchase from `seller` of token type `id`.
    /// @dev You must send `getPriceForAmount` ethers in transaction.
    /// @dev Amount must be not more than `getOfferedAmount`.
    /// @dev `affiliate` will earn `affiliateInterest` percents from value
    /// @dev `seller` also automatically donate `donation` percents from profit (value-affiliate interest)
    function buy(address payable seller, uint256 id, uint256 amount, address payable affiliate)
    external payable virtual /*nonReentrant*/ {
        Offer storage offer = _offers[id][seller];
        require( offer.price>0, _TOKEN_NOT_FOUND);
        require( getOfferedAmount(seller, id)>=amount, _WRONG_PARAM_VALUE);
        uint256 price = getPriceForAmount(seller, id, amount);
        require( msg.value == price, _WRONG_PARAM_VALUE);

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

    /// @dev Returns metadata uri for token type `id`.
    function uri(uint256 id) external view virtual override returns (string memory) {
        return _products[id].uri;
    }

    /// @dev Returns `privateUri` for token type `id`. Sender must own token of this type.
    function privateUri(uint256 id) external view virtual returns (string memory) {
        require(balanceOf(msg.sender, id)>0, _TOKEN_NOT_FOUND);
        return _products[id].privateUri;
    }

    // VOTING

    /// @dev Place vote for token with `id`. When you call it again for same `id` then only last `rating` used to calculate average rating.
    /// @dev `rating` 1-255.
    /// @dev comment your comment about token (product). 140 bytes max.
    function vote(uint256 id, uint8 rating, string memory comment) external virtual {
        require( bytes(comment).length<=140, _WRONG_PARAM_VALUE);
        require(rating>0, _WRONG_PARAM_VALUE);

        Product storage product = _products[id];
        require( product.creator != address(0), _TOKEN_NOT_FOUND);

        Vote storage vote = product.votes[msg.sender];
        bool ratedBefore = vote.rating > 0;

        if (ratedBefore)
            product.accumulatedRating = product.accumulatedRating.sub(vote.rating); // decrease old value first
        else {
            product.votesIndex[product.votesCount] = msg.sender;
            product.votesCount += 1;
            require(product.votesCount>0);
        }

        vote.rating = rating;
        vote.comment = comment;
        product.accumulatedRating = product.accumulatedRating.add(rating);
    }

    /// @dev Returns your previous vote for token `id`.
    function getVote(uint256 id) public view virtual returns (Vote memory) {
        return _products[id].votes[msg.sender];
    }

    /// @dev Returns average rating (accumulated rating divided by votes count) for token `id`
    function getRating(uint256 id) public view virtual returns (uint8) {
        Product storage product = _products[id];
        if (product.votesCount==0) return 0;
        else return uint8(product.accumulatedRating.div(product.votesCount));
    }

    /// @dev Returns total votes count for token `id`
    function getVotesCount(uint256 id) public view virtual returns (uint32) {
        return _products[id].votesCount;
    }

    /// @dev Returns last `count` votes, skipping `skip` items for token `id`
    /// @dev count must be less or equal 100.
    /// @dev Useful for getting comments / stars feed
    function getVotes(uint256 id, uint32 skip, uint32 count) public view virtual returns (Vote[] memory) {
        require(count<=100, _WRONG_PARAM_VALUE);

        Product storage product = _products[id];
        uint itemsCount;
        if (product.votesCount<=skip) itemsCount = 0;
        else {
            uint maxCount = product.votesCount-skip;
            itemsCount = maxCount<count ? maxCount : count;
        }

        Vote[] memory votes = new Vote[](itemsCount);

        if (itemsCount==0) return votes;

        uint32 offset = uint32(product.votesCount.sub(skip).sub(1));
        for (uint32 i=0; i<itemsCount; i++ ) {
            address voter = product.votesIndex[offset-i];
            Vote memory vote = product.votes[ voter ];
            votes[i] = vote;
        }

        return votes;
    }

    // PROFILE

    /// @dev Sets your profile metadata uri
    function setProfileUri(string memory uri_)
    public virtual {
        _profiles[msg.sender].uri  = uri_;
    }

    /// @dev Gets profile with adr metadata uri
    function getProfileUri(address payable adr)
    external view virtual returns (string memory) {
        return _profiles[adr].uri;
    }

    /// @dev Returns array of ids of your products
    function getInventory()
    external view virtual returns (uint256[] memory) {
        Profile storage profile = _profiles[msg.sender];
        uint256[] memory products = new uint256[](profile.productsCount-1);

        for (uint32 i=0; i<profile.productsCount; i++ ) {
            products[i] = profile.productsIndex[i];
        }

        return products;
    }

    /// @dev Returns array of ids of products offered for sale
    /// @dev Check what offer price greater 0 and offered amount greater 0, because there may be old (not actual) offers.
    function getOfferedProducts(address payable adr)
    external view virtual returns (uint256[] memory) {
        Profile storage profile = _profiles[adr];
        uint256[] memory offers = new uint256[](profile.offersCount-1);

        for (uint32 i=0; i<profile.offersCount; i++ ) {
            offers[i] = profile.offersIndex[i];
        }

        return offers;
    }

}