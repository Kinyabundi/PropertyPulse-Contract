// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// // import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
// import { Client } from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
// // import "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
// // import "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
// import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
// import "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
// import "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
// import "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
// import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver";
// // import {Oracle} from "@chainlink/contracts/src/v0.8/vrf/interfaces/Oracle.sol";
// import "./FunctionsSource.sol";
// // import { FunctionsClient } from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";


// contract PropertyPulseToken is ERC1155, Ownable, OwnerIsCreator {
//     using FunctionsRequest for FunctionsRequest.Request;
//     // using SafeERC20 for IERC20;

//     enum PayFeesIn {
//         Native,
//         LINK
//     }

//     error InvalidRouter(address router);
//     error OnlyOnBaseChain();
//     error NotEnoughBalanceForFees(uint256 currentBalance, uint256 calculatedFees);
//     error FailedToWithdrawEth(address owner, address target, uint256 value);
//     error LatestIssueInProgress();

//     struct PPTDetails {
//         address PPTAddress;
//         bytes ccipExtraArgsBytes;
//     }

//     struct PriceDetails {
//         uint80 listPrice;
//         uint80 originalListPrice;
//         uint80 taxAssessedValue;
//     }

//     uint256 constant BASE_SEPOLIA_CHAIN_ID = 84532;

//     FunctionsSource internal immutable i_functionsSource;
//     IRouterClient internal immutable i_ccipRouter;
//     LinkTokenInterface internal immutable i_linkToken;
//     uint64 private immutable i_currentChainSelector;
//     bytes32 internal s_lastRequestId;
//     address internal s_automationForwarderAddress;

//     uint256 private _nextTokenId;

//     mapping(uint64 => PPTDetails) public s_chains;
//     mapping(bytes32 => address) internal s_issueTo;
//     mapping(uint256 => PriceDetails) internal s_priceDetails;
//     mapping(uint256 => uint256) private _tokenBalances; // Track balances for each token ID
//     mapping(address => mapping(uint256 => uint256)) private _ownershipPercentages; // Track ownership percentages for each user and token ID

//     event ChainEnabled(uint64 chainSelector, address PPTAddress, bytes ccipExtraArgs);
//     event ChainDisabled(uint64 chainSelector);
//     event CrossChainSent(
//         address from,
//         address to,
//         uint256 tokenId,
//         uint256 amount,
//         uint64 sourceChainSelector,
//         uint64 destinationChainSelector
//     );
//     event CrossChainReceived(
//         address from,
//         address to,
//         uint256 tokenId,
//         uint256 amount,
//         uint64 sourceChainSelector,
//         uint64 destinationChainSelector
//     );

//     modifier onlyRouter() {
//         require(msg.sender == address(i_ccipRouter), "InvalidRouter");
//         _;
//     }

//     modifier onlyAutomationForwarder() {
//         require(msg.sender == s_automationForwarderAddress, "OnlyAutomationForwarderCanCall");
//         _;
//     }

//     modifier onlyEnabledChain(uint64 _chainSelector) {
//         require(s_chains[_chainSelector].PPTAddress!= address(0), "ChainNotEnabled");
//         _;
//     }

//     modifier onlyEnabledSender(uint64 _chainSelector, address _sender) {
//         require(s_chains[_chainSelector].PPTAddress == _sender, "SenderNotEnabled");
//         _;
//     }

//     modifier onlyOtherChains(uint64 _chainSelector) {
//         require(_chainSelector!= i_currentChainSelector, "OperationNotAllowedOnCurrentChain");
//         _;
//     }

//     modifier onlyOnBaseChain() {
//         require(block.chainid == BASE_SEPOLIA_CHAIN_ID, "OnlyOnBaseChain");
//         _;
//     }

//     constructor(
//         address functionsRouterAddress,
//         address ccipRouterAddress,
//         address linkTokenAddress,
//         uint64 currentChainSelector,
//         address _router
//     ) is CCIPReceiver(router) ERC1155("") FunctionsClient(functionsRouterAddress) {
//         if (ccipRouterAddress == address(0)) revert InvalidRouter(address(0));
//         i_functionsSource = new FunctionsSource();
//         i_ccipRouter = IRouterClient(ccipRouterAddress);
//         i_linkToken = LinkTokenInterface(linkTokenAddress);
//         i_currentChainSelector = currentChainSelector;
//     }

//     function issue(address to, uint64 subscriptionId, uint32 gasLimit, bytes32 donID)
//         external
//         onlyOwner
//         onlyOnBaseChain
//         returns (bytes32 requestId)
//     {
//         if (s_lastRequestId!= bytes32(0)) revert LatestIssueInProgress();

//         FunctionsRequest.Request memory req;
//         req.initializeRequestForInlineJavaScript(i_functionsSource.getPropertyMetadata());
//         requestId = _sendRequest(req.encodeCBOR(), subscriptionId, gasLimit, donID);

//         s_issueTo[requestId] = to;
//     }

//     function enableChain(uint64 chainSelector, address PPTAddress, bytes memory ccipExtraArgs)
//         external
//         onlyOwner
//         onlyOtherChains(chainSelector)
//     {
//         s_chains[chainSelector] = PPTDetails({ PPTAddress: PPTAddress, ccipExtraArgsBytes: ccipExtraArgs });

//         emit ChainEnabled(chainSelector, PPTAddress, ccipExtraArgs);
//     }

//     function disableChain(uint64 chainSelector) external onlyOwner onlyOnBaseChain {
//         delete s_chains[chainSelector];

//         emit ChainDisabled(chainSelector);
//     }

//     function crossChainTransferFrom(
//         address from,
//         address to,
//         uint256 amount,
//         uint64 destinationChainSelector,
//         PayFeesIn payFeesIn
//     ) external  onlyEnabledChain(destinationChainSelector) returns (bytes32 messageId) {
//         // Fractionalize tokens based on the amount
//         uint256 tokenId = fractionalizeTokens(from, amount);
//         string memory tokenUri = tokenURI(tokenId);

//         // Burn fractional tokens from sender
//         _burn(tokenId);

//         // Construct message for cross-chain transfer
//         Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
//             receiver: abi.encode(s_chains[destinationChainSelector].PPTAddress),
//             data: abi.encode(from, to, tokenId, amount, tokenUri),
//             tokenAmounts: new Client.EVMTokenAmount,
//             extraArgs: s_chains[destinationChainSelector].ccipExtraArgsBytes,
//             feeToken: payFeesIn == PayFeesIn.LINK? address(i_linkToken) : address(0)
//         });

//         // Get the fee required to send the CCIP message
//         uint256 fees = i_ccipRouter.getFee(destinationChainSelector, message);

//         if (payFeesIn == PayFeesIn.LINK) {
//             if (fees > i_linkToken.balanceOf(address(this))) {
//                 revert NotEnoughBalanceForFees(i_linkToken.balanceOf(address(this)), fees);
//             }

//             // Approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
//             i_linkToken.approve(address(i_ccipRouter), fees);

//             // Send the message through the router and store the returned message ID
//             messageId = i_ccipRouter.ccipSend(destinationChainSelector, message);
//         } else {
//             if (fees > address(this).balance) {
//                 revert NotEnoughBalanceForFees(address(this).balance, fees);
//             }

//             // Send the message through the router and store the returned message ID
//             messageId = i_ccipRouter.ccipSend{value: fees}(destinationChainSelector, message);
//         }

//         emit CrossChainSent(from, to, tokenId, i_currentChainSelector, destinationChainSelector);
//     }

//     function fractionalizeTokens(address owner, uint256 amount) internal returns (uint256 tokenId) {
//         tokenId = _nextTokenId++;
//         _mint(owner, tokenId, amount);

//         // Generate a unique URI for the token
//         string memory tokenUri = generateUniqueTokenURI(tokenId); 

//         // Store the URI in the token metadata
//         _setTokenURI(tokenId, tokenUri);

//         // Calculate ownership percentage
//         uint256 totalSupply = totalSupply();
//         uint256 newBalance = _tokenBalances[tokenId] + amount;
//         uint256 newOwnershipPercentage = (newBalance * 10000) / totalSupply;

//         // Update ownership percentage
//         _ownershipPercentages[owner][tokenId] = newOwnershipPercentage;

//         return tokenId;
//     }

//     function ccipReceive(struct Client.Any2EVMMessage  message)
//         external
//         virtual
//         override
//         onlyRouter
//         nonReentrant
//         onlyEnabledChain(message.sourceChainSelector)
//         onlyEnabledSender(message.sourceChainSelector, abi.decode(message.sender, (address)))
//     {
//         uint64 sourceChainSelector = message.sourceChainSelector;
//         (address from, address to, uint256 tokenId, string memory tokenUri) = abi.decode(message.data, (address, address, uint256, string));

//         _safeMint(to, tokenId);

//         emit CrossChainReceived(from, to, tokenId, sourceChainSelector, i_currentChainSelector);
//     }

//     function setAutomationForwarder(address automationForwarderAddress) external onlyOwner {
//         s_automationForwarderAddress = automationForwarderAddress;
//     }

//     function updatePriceDetails(uint256 tokenId, uint64 subscriptionId, uint32 gasLimit, bytes32 donID)
//         external
//         onlyAutomationForwarder
//         returns (bytes32 requestId)
//     {
//         FunctionsRequest.Request memory req;
//         req.initializeRequestForInlineJavaScript(i_functionsSource.getPrices());

//         string[] memory args = new string[](1);
//         args[0] = string(abi.encode(tokenId));

//         requestId = _sendRequest(req.encodeCBOR(), subscriptionId, gasLimit, donID);
//     }

//      function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
//         if (s_lastRequestId == requestId) {
//             (string memory realEstateAddress, uint256 yearBuilt, uint256 lotSizeSquareFeet) =
//                 abi.decode(response, (string, uint256, uint256));

//             uint256 tokenId = _nextTokenId++;

//             string memory uri = Base64.encode(
//                 bytes(
//                     string(
//                         abi.encodePacked(
//                             '{"name": "Cross Chain Tokenized Real Estate",'
//                             '"description": "Cross Chain Tokenized Real Estate",',
//                             '"image": "",' '"attributes": [',
//                             '{"trait_type": "realEstateAddress",',
//                             '"value": ',
//                             realEstateAddress,
//                             "}",
//                             ',{"trait_type": "yearBuilt",',
//                             '"value": ',
//                             yearBuilt,
//                             "}",
//                             ',{"trait_type": "lotSizeSquareFeet",',
//                             '"value": ',
//                             lotSizeSquareFeet,
//                             "}",
//                             "]}"
//                         )
//                     )
//                 )
//             );
//             string memory finalTokenURI = string(abi.encodePacked("data:application/json;base64,", uri));

//             _safeMint(s_issueTo[requestId], tokenId);

//         } else {
//             (uint256 tokenId, uint256 listPrice, uint256 originalListPrice, uint256 taxAssessedValue) =
//                 abi.decode(response, (uint256, uint256, uint256, uint256));

//             s_priceDetails[tokenId] = PriceDetails({
//                 listPrice: uint80(listPrice),
//                 originalListPrice: uint80(originalListPrice),
//                 taxAssessedValue: uint80(taxAssessedValue)
//             });
//         }
//     }

//     function getPriceDetails(uint256 tokenId) external view returns (PriceDetails memory) {
//         return s_priceDetails[tokenId];
//     }

//     function getCCIPRouter() public view returns (address) {
//         return address(i_ccipRouter);
//     }

//     function generateUniqueTokenURI(uint256 tokenId) internal pure returns (string memory) {
//         return string(abi.encodePacked("https://example.com/tokens/", Strings.toString(tokenId)));
//     }

//     function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
//         return super.tokenURI(tokenId);
//     }
// }
