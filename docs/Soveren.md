## `Soveren`

This contract utilized at the soverenjs library and Soveren Vue app.


`solidity-docgen` comment tag @param do not work for some reason for now, so @notice used for now.


### `mint(uint256 id, uint256 amount, string uri_, string privateUri_, bool canMintMore)` (public)

Creates `amount` tokens of new token type `id`, and assigns them to sender.




### `getCreator(uint256 id) → address payable` (external)

Returns `creator` address for token `id`



### `mintMore(uint256 id, uint256 amount)` (external)

Creates `amount` tokens of existing token type `id`, and assigns them to sender



### `burn(uint256 id, uint256 amount)` (external)

Burns `amount` tokens of token type `id`



### `safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes data)` (public)





### `transfer(address to, uint256 id, uint256 amount)` (public)

Transfers `to` address `amount` tokens of token type `id`



### `safeBatchTransferFrom(address from, address to, uint256[] ids, uint256[] amounts, bytes data)` (public)





### `batchTransfer(address to, uint256[] ids, uint256[] amounts)` (public)

Transfers `to` address `amounts` tokens of token types `ids`



### `makeOffer(uint256 id, uint256 price, uint256 reserve, uint8[] bulkDiscounts, uint8 affiliateInterest, uint8 donation)` (external)

Creates sale offer of token type `id`.
`price` price for 1 token in wei.
`reserve` Reserves tokens (do not offers it for sale).
`bulkDiscounts` You can specify bulk discounts at this array for 10+, 100+, 1000+ etc pieces. For example if you set `bulkDiscounts` to `[5,10,20,50]`, then it means what you give 5% discount for 10 and more pieces, 10% for 100+, 20% for 1000+, and 50% discount for 10000 pieces and more.
`affiliateInterest` How many percents from purchase will earn your affiliate. An affiliate program is a great way to motivate other people to promote your tokens.
`donation` How namy percents from clear profit you want to automatically donate to support the service.



### `removeOffer(uint256 id)` (external)

Removes sale offer of token type `id`



### `getOffer(address payable seller, uint256 id) → struct Soveren.Offer` (external)

Returns `seller`s sale offer of token type `id`



### `isApprovedForAll(address account, address operator) → bool` (public)



See {IERC1155-isApprovedForAll}.

### `getOfferedAmount(address payable seller, uint256 id) → uint256` (public)

Returns `seller`s offered amount of token type `id`



### `getPriceForAmount(address payable seller, uint256 id, uint256 amount) → uint256` (public)

Returns total `seller` price in wei for specified `amount` of token type `id` (`bulkDiscounts` applied)



### `buy(address payable seller, uint256 id, uint256 amount, address payable affiliate)` (external)

Process purchase from `seller` of token type `id`.
You must send `getPriceForAmount` ethers in transaction.
Amount must be not more than `getOfferedAmount`.
`affiliate` will earn `affiliateInterest` percents from value
`seller` also automatically donate `donation` percents from profit (value-affiliate interest)



### `uri(uint256 id) → string` (external)

Returns metadata uri for token type `id`.



### `privateUri(uint256 id) → string` (external)

Returns `privateUri` for token type `id`. Sender must own token of this type.



### `vote(uint256 id, uint8 rating, string comment)` (external)

Place vote for token with `id`. When you call it again for same `id` then only last `rating` used to calculate average rating.
`rating` 1-255.
comment your comment about token (product). 140 bytes max.



### `getVote(uint256 id) → struct Soveren.Vote` (public)

Returns your previous vote for token `id`.



### `getRating(uint256 id) → uint8` (public)

Returns average rating (accumulated rating divided by votes count) for token `id`



### `getVotesCount(uint256 id) → uint32` (public)

Returns total votes count for token `id`



### `getVotes(uint256 id, uint32 skip, uint32 count) → struct Soveren.Vote[]` (public)

Returns last `count` votes, skipping `skip` items for token `id`
Useful for getting comments / stars feed




### `buySingle(address payable seller, uint256 id, uint256 amount, address payable affiliate)`





