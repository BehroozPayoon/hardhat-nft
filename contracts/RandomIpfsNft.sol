// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error RandomIpfsNft__AlreadyInitialized();
error RandomIpfsNft__RangeOutOfBounds();
error RandomIpfsNft__NeedMoreEthSent();
error RandomIpfsNft__TransferFailed();

contract RandomIpfsNft is VRFConsumerBaseV2, ERC721URIStorage, Ownable {
    enum Breed {
        PUG,
        SHIBA_INU,
        ST_BERNARD
    }

    VRFCoordinatorV2Interface private immutable vrfCoordinator;
    uint64 private immutable subscriptionId;
    bytes32 private immutable gasLane;
    uint32 private immutable callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    mapping(uint256 => address) public requestIdToSender;
    uint256 public tokenCounter;
    uint256 internal constant MAX_CHANCE_VALUE = 100;
    string[] internal dogTokenUris;
    uint256 internal immutable mintFee;
    bool private initialized;

    event NftRequested(uint256 indexed requestId, address requester);
    event NftMinted(Breed breed, address minter);

    constructor(
        address _vrfCoordinatorV2,
        uint64 _subscriptionId,
        bytes32 _gasLane,
        uint32 _callbackGasLimit,
        string[3] memory _dogTokenUris,
        uint256 _mintFee
    ) VRFConsumerBaseV2(_vrfCoordinatorV2) ERC721("Random Ipfs NFT", "RIN") {
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinatorV2);
        subscriptionId = _subscriptionId;
        gasLane = _gasLane;
        callbackGasLimit = _callbackGasLimit;
        mintFee = _mintFee;
        _initializeContract(_dogTokenUris);
    }

    function _initializeContract(string[3] memory _dogTokenUris) private {
        if (initialized) {
            revert RandomIpfsNft__AlreadyInitialized();
        }
        dogTokenUris = _dogTokenUris;
        initialized = true;
    }

    function requestNft() public payable returns (uint256 requestId) {
        if (msg.value < mintFee) {
            revert RandomIpfsNft__NeedMoreEthSent();
        }
        requestId = vrfCoordinator.requestRandomWords(
            gasLane,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            callbackGasLimit,
            NUM_WORDS
        );
        requestIdToSender[requestId] = msg.sender;
        emit NftRequested(requestId, msg.sender);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        address nftOwner = requestIdToSender[requestId];
        uint256 newTokenId = tokenCounter;
        uint256 moddedRng = randomWords[0] % MAX_CHANCE_VALUE;
        Breed dogBreed = getBreedFromModdedRng(moddedRng);
        tokenCounter += 1;
        _safeMint(nftOwner, newTokenId);
        _setTokenURI(newTokenId, dogTokenUris[uint256(dogBreed)]);
        emit NftMinted(dogBreed, nftOwner);
    }

    function getBreedFromModdedRng(uint256 moddedRng) public pure returns (Breed) {
        uint256 cumulativeSum = 0;
        uint256[3] memory chanceArray = getChanceArray();
        for (uint256 i = 0; i < chanceArray.length; i++) {
            if (moddedRng >= cumulativeSum && moddedRng < cumulativeSum + chanceArray[i]) {
                return Breed(i);
            }
            cumulativeSum += chanceArray[i];
        }
        revert RandomIpfsNft__RangeOutOfBounds();
    }

    function getChanceArray() public pure returns (uint256[3] memory) {
        return [10, 30, MAX_CHANCE_VALUE];
    }

    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert RandomIpfsNft__TransferFailed();
        }
    }

    function getMintFee() public view returns (uint256) {
        return mintFee;
    }

    function getDogTokenUris(uint256 index) public view returns (string memory) {
        return dogTokenUris[index];
    }

    function getTokenCounter() public view returns (uint256) {
        return tokenCounter;
    }

    function getInitialized() public view returns (bool) {
        return initialized;
    }
}
