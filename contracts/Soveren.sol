// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "hardhat/console.sol";

contract Soveren is ERC1155 {
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
        uint8[] bulkDiscounts;    // discounts array for amount of 10,100,1000 etc
        uint8 affiliateInterest;  // how many percents will receive promoter (0-99)
        uint8 donation;           // per product donation (percents, 0-99)
    }

    mapping(uint256 => Product) private _products;

    constructor() ERC1155("") {
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