// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;

// imports
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @notice Errors
 */
error NFTMarketplace__PriceMustBeAboveZero();
error NFTMarketplace__NotApprovedForMarketPlace();
error NFTMarketplace__AlreadyListed(address nftAddress, uint256 tokenId);
error NFTMarketplace__NotOwner();
error NFTMarketplace__NotListed(address nftAddress, uint256 tokenId);
error NFTMarketplace__NotEnoughFunds(address nftAddress, uint256 tokenId, uint256 price);
error NFTMarketplace__NoProceeds();
error NFTMarketplace__TransferFailed();

// 1. `listItem`: List NFTs on the marketplace
// 2. `buyItem`: Buy the NFTs
// 3. `cancelItem`: cancel a listing
// 4. `updateListing`: Update Price
// 5. `withdrawProceeds`: Withdraw payment for bought NFTs

contract NFTMarketplace is ReentrancyGuard {
    // structure for storing NFt details
    struct Listing {
        uint256 price;
        address seller;
    }

    // events
    event NFTListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event ItemCancelled(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

    // mappings
    mapping(address => mapping(uint256 => Listing)) private s_listing;
    mapping(address => uint256) private s_proceeds;

    // modifiers
    modifier notListed(
        uint256 tokenId,
        address owner,
        address nftAddress
    ) {
        Listing memory listing = s_listing[nftAddress][tokenId];
        if (listing.price > 0) {
            revert NFTMarketplace__AlreadyListed(nftAddress, tokenId);
        }
        _;
    }

    modifier isOwner(
        uint256 tokenId,
        address spender,
        address nftAddress
    ) {
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) {
            revert NFTMarketplace__NotOwner();
        }
        _;
    }

    modifier isListed(uint256 tokenId, address nftAddress) {
        Listing memory listing = s_listing[nftAddress][tokenId];
        if (listing.price <= 0) {
            revert NFTMarketplace__NotListed(nftAddress, tokenId);
        }
        _;
    }

    ///////////////////////////////////////////////////////////////////////////////
    //////////////////////////////// Main Functions //////////////////////////////
    /////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Method for listing NFT
     * @param nftAddress of NFT contract
     * @param tokenId  token Id of the NFT
     * @param price sale price for each item
     * @dev we could have the contract as escrow for the NFTs but this way people can still hold thier NFTs when listed
     */
    function listItem(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    ) external notListed(tokenId, msg.sender, nftAddress) isOwner(tokenId, msg.sender, nftAddress) {
        if (price <= 0) {
            revert NFTMarketplace__PriceMustBeAboveZero();
        }
        //  ways to list an nft
        // 1. send the nft to the contract. Transfer -> contract "hold" the NFT
        // 2. Owners can still hold thier NFT, and give the marketplace approval to sell the NFT for them
        IERC721 nft = IERC721(nftAddress);
        if (nft.getApproved(tokenId) != address(this)) {
            revert NFTMarketplace__NotApprovedForMarketPlace();
        }
        // use a mapping to store the NFTs
        s_listing[nftAddress][tokenId] = Listing(price, msg.sender);
        emit NFTListed(msg.sender, nftAddress, tokenId, price);
    }

    function buyItem(address nftAddress, uint256 tokenId)
        external
        payable
        nonReentrant
        isListed(tokenId, nftAddress)
    {
        Listing memory listedItem = s_listing[nftAddress][tokenId];
        if (msg.value < listedItem.price) {
            revert NFTMarketplace__NotEnoughFunds(nftAddress, tokenId, listedItem.price);
        }

        // update seller's balance
        s_proceeds[listedItem.seller] += msg.value;

        // delete item from list
        delete (s_listing[nftAddress][tokenId]);

        // transfer  NFT to buyer
        IERC721(nftAddress).safeTransferFrom(listedItem.seller, msg.sender, tokenId);
        emit ItemBought(msg.sender, nftAddress, tokenId, listedItem.price);
    }

    function cancelListing(address nftAddress, uint256 tokenId)
        external
        isListed(tokenId, nftAddress)
        isOwner(tokenId, msg.sender, nftAddress)
    {
        delete (s_listing[nftAddress][tokenId]);
        emit ItemCancelled(msg.sender, nftAddress, tokenId);
    }

    function updateListing(
        address nftAddress,
        uint256 tokenId,
        uint256 newPrice
    ) external isListed(tokenId, nftAddress) isOwner(tokenId, msg.sender, nftAddress) {
        s_listing[nftAddress][tokenId].price = newPrice;
        emit NFTListed(msg.sender, nftAddress, tokenId, newPrice);
    }

    function withdrawProceeds() external payable {
        uint256 proceeds = s_proceeds[msg.sender];
        if (proceeds <= 0) {
            revert NFTMarketplace__NoProceeds();
        }
        s_proceeds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: proceeds}("");
        if (!success) {
            revert NFTMarketplace__TransferFailed();
        }
    }

    ///////////////////////////////////////////////////////////////////////////////
    //////////////////////////////// Getter Functions ////////////////////////////
    /////////////////////////////////////////////////////////////////////////////

    function getListing(address nftAddress, uint256 tokenID)
        external
        view
        returns (Listing memory)
    {
        return s_listing[nftAddress][tokenID];
    }

    function getProceeds(address seller) external view returns(uint256){
        return s_proceeds[seller];
    }
}
