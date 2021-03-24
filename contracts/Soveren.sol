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
        uint256 price;            // base price ETH
        uint8[] bulkDiscounts;    // discounts array for amount of 10,100,1000 etc
        uint8 affiliateInterest;  // how many percents will receive promoter (0-99)
        uint8 donation;           // per product donation (percents, 0-99)
        string privateUri;        // simple DRM for digital products
    }

    mapping(uint256 => Product) private _products;

    constructor() ERC1155("") {
    }

    function uri(uint256 id) external view virtual override returns (string memory) {
        return _products[id].uri;
    }


    function mint(uint256 id, uint256 amount, string memory uri_) public virtual {
        require( _products[id].creator == address(0), "SOVEREN: Token already exists");

        address payable creator = msg.sender;
        _products[id].creator = creator;
        _products[id].uri = uri_;
        super._mint(creator, id, amount, msg.data);
    }

    function mintMore(uint256 id, uint256 amount) public virtual {
        require( _products[id].creator == msg.sender, "SOVEREN: Mint more can token creator only");

        super._mint(msg.sender, id, amount, msg.data);
    }


    function burn(uint256 id, uint256 amount) public virtual {
        super._burn(msg.sender, id, amount);
    }



}