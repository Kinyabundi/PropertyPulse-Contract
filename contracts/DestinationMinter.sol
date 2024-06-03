// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {PropertyPulseToken} from "./PropertyPulseToken.sol"; 

contract DestinationMinter is CCIPReceiver {
    PropertyPulseToken pulseToken;

    event MintCallSuccessful(uint256 indexed tokenId);

    constructor(address router, address pulseTokenAddress) CCIPReceiver(router) {
        pulseToken = PropertyPulseToken(pulseTokenAddress);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        // Assuming the message.data contains encoded parameters for minting:
        // (address to, uint256 id, uint256 amount, bytes memory data)
        (address to, uint256 id, uint256 value, bytes memory data) = abi.decode(message.data, (address, uint256, uint256, bytes));

        // Minting the token
        bool success = pulseToken.mint(to, id, value, data);
        require(success, "Mint operation failed");

        // Emitting the event
        emit MintCallSuccessful(id);
    }
}
