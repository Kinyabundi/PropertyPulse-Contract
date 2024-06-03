// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {FunctionsSource} from "./FunctionsSource.sol";
import "hardhat/console.sol";

contract PropertyPulseToken is ERC1155, Ownable, FunctionsClient {

    using FunctionsRequest for FunctionsRequest.Request;
    // string constant TOKEN_URI = "https://ipfs.io/ipfs/QmYuKY45Aq87LeL1R5dhb1hqHLp6ZFbJaCP8jxqKM1MX6y/babe_ruth_1.json";
    string _baseTokenURI;

        struct PriceDetails {
        uint80 listPrice;
        uint80 originalListPrice;
        uint80 taxAssessedValue;
    }

struct TokenData {
    string realEstateAddress;
    uint256 yearBuilt;
    uint256 lotSizeSquareFeet;
    string buildingName;
}

    uint256 constant BASE_SEPOLIA_CHAIN_ID = 84532;

    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    error OnlyOnBaseChain();
    error UnexpectedRequestID(bytes32 requestId);
    error LatestIssueInProgress();
    error RequestNotSent();

    event Response(
        bytes32 indexed requestId,
        string character,
        bytes response,
        bytes err
    );

    //Router Address
    address router = 0xf9B8fc078197181C841c296C876945aaa425B278;

     string public getTokenMetadata = "const { ethers } = await import('npm:ethers@6.10.0');"
        "const abiCoder = ethers.AbiCoder.defaultAbiCoder();" "const apiResponse = await Functions.makeHttpRequest({"
        "    url: `https://api.bridgedataoutput.com/api/v2/OData/test/Property('P_5dba1fb94aa4055b9f29696f')?access_token=6baca547742c6f96a6ff71b138424f21`,"
        "});" "const realEstateAddress = apiResponse.data.UnparsedAddress;"
        "const yearBuilt = Number(apiResponse.data.YearBuilt);"
        "const lotSizeSquareFeet = Number(apiResponse.data.LotSizeSquareFeet);"
        "const encoded = abiCoder.encode([`string`, `uint256`, `uint256`], [realEstateAddress, yearBuilt, lotSizeSquareFeet]);"
        "return ethers.getBytes(encoded);";


    //  //Callback gas limit
    // uint32 gasLimit = 500000;

    // //donID
    // bytes32 donID = 0x66756e2d626173652d7365706f6c69612d310000000000000000000000000000;

    // value(its a non-fungible token)
    uint256 value = 1;

    FunctionsSource internal immutable i_functionsSource;
    uint256 private _nextTokenId;
    mapping(uint256 => string) private _tokenURIs;
    mapping(bytes32 => address) internal s_issueTo;
    mapping(uint256 => PriceDetails) internal s_priceDetails;
    // bytes32 internal s_lastRequestId;
    mapping(uint256 => TokenData) private _tokenDataapp;
    uint256 private _tokenIdCounter;

    modifier onlyOnBaseChain() {
        require(block.chainid == BASE_SEPOLIA_CHAIN_ID, "OnlyOnBaseChain");
        _;
    }

   constructor(string memory baseURI)  ERC1155(baseURI) Ownable(msg.sender) FunctionsClient(router)  {
     _baseTokenURI = baseURI;
    i_functionsSource = new FunctionsSource();
   }

    function issue( uint64 subscriptionId, uint32 gasLimit, bytes32 donID)
        external
        onlyOwner
        onlyOnBaseChain
        returns (bytes32 requestId)
    {
        if (s_lastRequestId!= bytes32(0)) revert LatestIssueInProgress();

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(getTokenMetadata);
        requestId = _sendRequest(req.encodeCBOR(), subscriptionId, gasLimit, donID);
          return requestId;
    }

    function mint(address to, uint256 id, uint256 value, bytes memory data) public returns (bool) {
        _mint(to, id, value, data);

        return true;
    }

    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        // Construct the full URI for the token ID
        string memory baseUri = super.uri(tokenId); 
        return string(abi.encodePacked(baseUri, ".json"));
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        if (s_lastRequestId == requestId) {
            (string memory realEstateAddress, uint256 yearBuilt, uint256 lotSizeSquareFeet, string memory buildingName) =
                abi.decode(response, (string, uint256, uint256, string));
                
            uint256 tokenId = _nextTokenId++;

            string memory uri = Base64.encode(
                bytes(
                    string(
                        abi.encodePacked(
                            '{"name": "Cross Chain Tokenized Real Estate",'
                            '"description": "Cross Chain Tokenized Real Estate",',
                            '"image": "",' '"attributes": [',
                            '{"trait_type": "realEstateAddress",',
                            '"value": ',
                            realEstateAddress,
                            "}",
                            ',{"trait_type": "yearBuilt",',
                            '"value": ',
                            yearBuilt,
                            "}",
                            ',{"trait_type": "lotSizeSquareFeet",',
                            '"value": ',
                            lotSizeSquareFeet,
                            "}",
                             ',{"trait_type": "buildingName",',
                            '"value": ',
                            buildingName,
                            "}",
                            "]}"
                        )
                    )
                )
            );
            string memory finalTokenURI = string(abi.encodePacked("data:application/json;base64,", uri));

            _mint(s_issueTo[requestId], tokenId, value, "");

        } else {
            (uint256 tokenId, uint256 listPrice, uint256 originalListPrice, uint256 taxAssessedValue) =
                abi.decode(response, (uint256, uint256, uint256, uint256));

            s_priceDetails[tokenId] = PriceDetails({
                listPrice: uint80(listPrice),
                originalListPrice: uint80(originalListPrice),
                taxAssessedValue: uint80(taxAssessedValue)
            });
        }
    }

      
   
}
