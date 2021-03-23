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
        address payable creator; // product creator
        string uri;              // per-product uri
    }

    mapping(uint256 => Product) private _products;

    constructor() ERC1155("") {

    }

    function uri(uint256 id) external view virtual override returns (string memory) {
        return _products[id].uri;
    }

    function mint(uint256 id, uint256 amount, string memory uri_) public virtual {
        _mint(msg.sender, id, amount, msg.data, uri_);
    }

    function _mint(address payable account, uint256 id, uint256 amount, bytes memory data, string memory uri_) internal virtual {
        if (_products[id].creator == address(0)) {
            _products[id].creator = account;
            _products[id].uri = uri_;
        } else {
            require( _products[id].creator == account, "SOVEREN: Mint more can token creator only");
        }
        super._mint( account, id, amount, data);
    }


}