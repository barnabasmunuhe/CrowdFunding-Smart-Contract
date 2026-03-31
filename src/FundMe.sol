// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error FundMe__NotOwner();
error FundMe__SpendMoreEth();
error FundMe__WithdrawFailed();
error FundMe__NoFundsToWithdraw();

contract FundMe is Ownable {
    using PriceConverter for uint256;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    mapping(address funder => uint256 amount) private s_addressToAmountFunded;
    address payable[] private s_funders;

    uint256 public constant MINIMUM_USD = 5e18; // 5 dollars
    AggregatorV3Interface private s_priceFeed;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Funded(address indexed funder, uint256 amount);

    constructor(address priceFeed) Ownable(msg.sender) {
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    function fund() public payable {
        uint256 usdAmount = MINIMUM_USD.getConversionRate(s_priceFeed);
        if (usdAmount < MINIMUM_USD) {
            revert FundMe__SpendMoreEth();
        }
        if (s_addressToAmountFunded[msg.sender] == 0) {
            // 0 = funder has never funded before
            s_funders.push(payable(msg.sender));
        }
        s_addressToAmountFunded[msg.sender] += msg.value;

        emit Funded(msg.sender, msg.value);
    }

    function cheaperWithdraw() public onlyOwner {
        if (address(this).balance == 0) {
            revert FundMe__NoFundsToWithdraw();
        }

        uint256 fundersLength = s_funders.length;
        for (uint256 funderIndex = 0; funderIndex < fundersLength; funderIndex++) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        delete s_funders;

        (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
        if(!success){
            revert FundMe__WithdrawFailed();
        }
    }

    function withdraw() public onlyOwner {
        for (uint256 funderIndex = 0; funderIndex < s_funders.length; funderIndex++) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        delete s_funders;
        // // transfer
        // payable(msg.sender).transfer(address(this).balance);

        // // send
        // bool sendSuccess = payable(msg.sender).send(address(this).balance);
        // require(sendSuccess, "Send failed");

        // call
        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }

    // Explainer from: https://solidity-by-example.org/fallback/
    // Ether is sent to contract
    //      is msg.data empty?
    //          /   \
    //         yes  no
    //         /     \
    //    receive()?  fallback()
    //     /   \
    //   yes   no
    //  /        \
    //receive()  fallback()

    fallback() external payable {
        fund();
    }

    receive() external payable {
        fund();
    }

    /**
     * View / Pure functions (Getters)
     */
    function getVersion() public view returns (uint256) {
        return s_priceFeed.version();
    }

    function getAddressToAmountFunded(address fundingAddress) external view returns (uint256) {
        return s_addressToAmountFunded[fundingAddress];
    }

    function getFunder(uint256 index) external view returns (address) {
        return s_funders[index];
    }

    function getOwner() external view returns (address) {
        return msg.sender;
    }
}

// Concepts we didn't cover yet (will cover in later sections)
// 1. Enum
// 2. Events
// 3. Try / Catch
// 4. Function Selector
// 5. abi.encode / decode
// 6. Hash with keccak256
// 7. Yul / Assembly
