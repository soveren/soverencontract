// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";
//import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
//import "@openzeppelin/contracts/utils/math/Math.sol";
//import "hardhat/console.sol";

/// @title Contract for free and sovereign market
/// @author Slavik V Bogdanov
/// @dev This contract utilized at the soverenjs library and Soveren Vue app.
/// @dev `solidity-docgen` comment tag @param do not work for some reason for now, so @dev used for now.
contract Soveren is ERC1155, PullPayment/*, ReentrancyGuard*/ {
    using SafeMath for uint256;
    using SafeMath for uint32;
    using Address for address;

    uint256 private constant MAX_UINT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff; // max uint256

    string private constant _TOKEN_NOT_FOUND   = "SV: id not found";
    string private constant _ACCESS_DENIED     = "SV: Access denied";
    string private constant _WRONG_PARAM_VALUE = "SV: Wrong param";

    struct Vote {
        uint8 rating;
        uint32 revision; //TODO
        string comment;
    }

    struct Revision {
        string uri;               // metadata uri
        string privateUri;        // simple DRM for digital products
    }

    struct Product {
        bool published;
        address payable creator;  // product creator
        Revision[] revisions;
        string uri;               // metadata uri
        string privateUri;        // simple DRM for digital products
        uint256 price;            // base price ETH
        uint8 affiliateInterest;  // how many percents will receive promoter (0-99)
        uint8 donation;           // per product donation (percents from clear profit, 0-99)

        uint32 votesCount;
        uint256 accumulatedRating;
        mapping (address => Vote) votes;
        mapping (uint32 => address) votesIndex;
    }

    struct Profile {
        string uri;               // profile metadata uri
        uint256[] productsIndex;
        uint256[] purchasedIndex;
    }

    // Mapping to profiles
    mapping (address => Profile) private _profiles;

    // Mapping to products
    mapping (uint256 => Product) private _products;

    address private temporaryApprovedAccount;
    address private temporaryApprovedOperator;

    modifier temporaryApproveSenderForSeller(address seller) {
        temporaryApprovedAccount = seller;
        temporaryApprovedOperator = msg.sender;
        _;
        temporaryApprovedAccount = address(0);
        temporaryApprovedOperator = address(0);
    }


    event Bought(address payable seller, uint256 id, uint256 price, address payable affiliate, uint256 affiliateProfit, uint256 donationProfit);
    event NewProduct(uint256 id, string uri, uint256 price, uint8 affiliateInterest, uint8 donation);
    event NewRevision(uint256 id, string uri);

    address payable addressForDonations;

    constructor(address _addressForDonations) ERC1155("") {
        addressForDonations = payable(_addressForDonations);
    }

    // MINTING, BURNING, TRANSFER

    /// @dev Creates `amount` tokens of new token type `id`, and assigns them to sender.
    /// @dev When you mints more all
    /// @param id Token id
    /// @param _uri metadata uri https://eips.ethereum.org/EIPS/eip-1155#metadata
    /// @param _privateUri uri of paid file (accessed to token holders only)
    function mint(
        uint256 id,
        string memory _uri,
        string memory _privateUri,
        uint256 _price,
        uint8 _affiliateInterest,
        uint8 _donation )
    public virtual /*nonReentrant*/ {
        require( _affiliateInterest<100, _WRONG_PARAM_VALUE);
        require( _donation<100, _WRONG_PARAM_VALUE);


        if (_products[id].creator == address(0)) { // new token

            address payable creator = payable(msg.sender);
            Product storage product = _products[id];
            product.creator = creator;
            product.published = true;
            product.price = _price;
            product.affiliateInterest = _affiliateInterest;
            product.donation = _donation;
            product.uri = _uri;
            product.privateUri = _privateUri;

            _mint(creator, id, MAX_UINT, msg.data);

            Profile storage profile = _profiles[msg.sender];
            profile.productsIndex.push(id);

            emit NewProduct( id, _uri, _price, _affiliateInterest, _donation );

        }
    }

    function updateProduct(
        uint256 id,
        string memory _uri,
        string memory _privateUri,
        uint256 _price,
        uint8 _affiliateInterest,
        uint8 _donation
    ) public virtual  {
        require(_products[id].creator == msg.sender, _ACCESS_DENIED);

        Product storage product = _products[id];
        Revision memory rev;
        rev.uri = product.uri;
        rev.privateUri = product.privateUri;

        _products[id].revisions.push(rev);

        product.price = _price;
        product.affiliateInterest = _affiliateInterest;
        product.donation = _donation;
        product.uri = _uri;
        product.privateUri = _privateUri;

        emit NewRevision( id, _uri );

    }


    /// @dev Returns `creator` address for token `id`
    function getCreator(uint256 id) external view virtual returns (address payable){
        return _products[id].creator;
    }


    // OFFERS, BUYING


    /// @dev See {IERC1155-isApprovedForAll}.
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return account==temporaryApprovedAccount && operator==temporaryApprovedOperator; // for now we approve transfers from all accounts for buy method below
    }

    /// @dev Process purchase from `seller` of token type `id`.
    /// @dev You must send `getPriceForAmount` ethers in transaction.
    /// @dev Amount must be not more than `getOfferedAmount`.
    /// @dev `affiliate` will earn `affiliateInterest` percents from value
    /// @dev `seller` also automatically donate `donation` percents from profit (value-affiliate interest)
    function buy(address payable seller, uint256 id, address payable affiliate)
    external payable virtual temporaryApproveSenderForSeller(seller) /*nonReentrant*/ {
        Product storage product = _products[id];
        require( product.price>0, _TOKEN_NOT_FOUND);
        uint256 price = product.price;
        require( msg.value == price, _WRONG_PARAM_VALUE);

        uint256 affiliateProfit = 0;
        uint256 donationProfit = 0;

        if ((affiliate!=address(0)) && (product.affiliateInterest>0)) {
            affiliateProfit = price.mul(product.affiliateInterest).div(100);
        }

        if ((product.donation>0) && (addressForDonations!=address(0))) {
            donationProfit = price.sub(affiliateProfit).mul(product.donation).div(100);
        }

        uint256 sellerProfit = price.sub(affiliateProfit).sub(donationProfit);

        // Transfer ETH to the beneficiaries
        _asyncTransfer( seller, sellerProfit);
        if (affiliateProfit>0) _asyncTransfer( affiliate, affiliateProfit);
        if (donationProfit>0)  _asyncTransfer( addressForDonations, donationProfit);

        // Transfer token to buyer
        super.safeTransferFrom( seller, msg.sender, id, 1, msg.data);
        _profiles[msg.sender].purchasedIndex.push(id);

        emit Bought(seller, id, price, affiliate, affiliateProfit, donationProfit);
    }

    /// @dev Returns metadata uri for token type `id`.
    function uri(uint256 id) public view virtual override returns (string memory) {
        Product storage p = _products[id];
        return p.revisions[p.revisions.length-1].uri;
    }

    /// @dev Returns `privateUri` for token type `id`. Sender must own token of this type.
    function privateUri(uint256 id) external view virtual returns (string memory) {
        require(balanceOf(msg.sender, id)>0, _TOKEN_NOT_FOUND);
        Product storage p = _products[id];
        return p.revisions[p.revisions.length-1].privateUri;
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

        Vote storage v = product.votes[msg.sender];
        bool ratedBefore = v.rating > 0;

        if (ratedBefore)
            product.accumulatedRating = product.accumulatedRating.sub(v.rating); // decrease old value first
        else {
            product.votesIndex[product.votesCount] = msg.sender;
            product.votesCount += 1;
            require(product.votesCount>0);
        }

        v.rating = rating;
        v.comment = comment;
        product.accumulatedRating = product.accumulatedRating.add(rating);
    }

    /// @dev Returns your previous vote for token `id`.
    function getVote(uint256 id) public view virtual returns (Vote memory) {
        return _products[id].votes[msg.sender];
    }

    /// @dev Returns average rating (accumulated rating divided by votes count) for token `id`
    function getRating(uint256 id) public view virtual returns (int8) {
        Product storage product = _products[id];
        if (product.votesCount==0) return -1; //for not rated products
        else return int8(product.accumulatedRating.div(product.votesCount));
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
            Vote memory v = product.votes[ voter ];
            votes[i] = v;
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
    function getPurchased()
    external view virtual returns (uint256[] memory) {
        return _profiles[msg.sender].purchasedIndex;
    }

    /// @dev Returns array of ids of products offered for sale
    /// @dev Check what offer price greater 0 and offered amount greater 0, because there may be old (not actual) offers.
    function getProducts(address payable seller)
    external view virtual returns (uint256[] memory) {
        return _profiles[seller].productsIndex;
    }

}
