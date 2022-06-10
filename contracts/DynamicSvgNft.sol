// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "base64-sol/base64.sol";

error DynamicSvgNft__TokenIdNotFound();

contract DynamicSvgNft is ERC721, Ownable {
    uint256 private tokenCounter;
    string private lowImageURI;
    string private highImageURI;

    mapping(uint256 => int256) private tokenIdToHighValues;
    AggregatorV3Interface internal immutable priceFeed;
    string private constant BASE_IMAGE_URI = "data:image/svg+xml;base64,";
    string private constant BASE_JSON_URI = "data:application/json;base64,";

    event CreatedNft(uint256 indexed tokenId, int256 highValue);

    constructor(
        address _priceFeedAddress,
        string memory lowSvg,
        string memory highSvg
    ) ERC721("Dynamic SVG NFT", "DSN") {
        tokenCounter = 0;
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
        lowImageURI = svgToImageURI(lowSvg);
        highImageURI = svgToImageURI(highSvg);
    }

    function svgToImageURI(string memory svg) private pure returns (string memory) {
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(svg))));
        return string(abi.encodePacked(BASE_IMAGE_URI, svgBase64Encoded));
    }

    function mintNft(int256 highValue) public {
        tokenIdToHighValues[tokenCounter] = highValue;
        emit CreatedNft(tokenCounter, highValue);
        _safeMint(msg.sender, tokenCounter);
        tokenCounter += 1;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) {
            revert DynamicSvgNft__TokenIdNotFound();
        }
        (, int256 price, , , ) = priceFeed.latestRoundData();
        string memory imageURI = lowImageURI;
        if (price >= tokenIdToHighValues[tokenId]) {
            imageURI = highImageURI;
        }
        return
            string(
                abi.encodePacked(
                    BASE_JSON_URI,
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                name(), // You can add whatever name here
                                '", "description":"An NFT that changes based on the Chainlink Feed", ',
                                '"attributes": [{"trait_type": "coolness", "value": 100}], "image":"',
                                imageURI,
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    function getLowSVG() public view returns (string memory) {
        return lowImageURI;
    }

    function getHighSVG() public view returns (string memory) {
        return highImageURI;
    }

    function getPriceFeed() public view returns (AggregatorV3Interface) {
        return priceFeed;
    }

    function getTokenCounter() public view returns (uint256) {
        return tokenCounter;
    }
}
