// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {CurveErrorCodes} from "./CurveErrorCodes.sol";

interface ICurve {
    /**
        @notice Validates if a delta value is valid for the curve. The criteria for
        validity is can be different for each type of curve, for instance ExponentialCurve
        requires delta to be at least 1.
        @param delta The delta value to be validated
        @return valid True if delta is valid, false otherwise
     */
    function validateDelta(uint256 delta) external pure returns (bool valid);


    /**
        @notice Validates if a new spot price is valid for the curve.
        @param newSpotPrice The new spot price to be set
        @return valid True if the new spot price is valid, false otherwise
     */
    function validateSpotPrice(uint256 newSpotPrice) external pure returns (bool valid);

    /**
        @notice Given the current state of the pair and the trade, computes how much the user
        should pay to purchase an NFT from the pair, the new spot price, and other values.
        @param spotPrice The current selling spot price of the pair, in ETH
        @param delta The delta parameter of the pair, what it means depends on the curve
        @param numItems The number of NFTs the user is buying from the pair
        @param feeMultiplier Determines how much fee the LP takes from this trade, 18 decimals
        @param protocolFeeMultiplier Determines how much fee the protocol takes from this trade, 18 decimals
        @return error Any math calculation errors, only Error.OK means the returned values are valid
        @return newSpotPrice The updated selling spot price, in ETH
        @return inputValue The amount that the user should pay, in ETH
        @return protocolFee The amount of fee to send to the protocol, in ETH
     */
    function getBuyInfo(
        uint256 spotPrice,
        uint256 delta,
        uint256 numItems,
        uint256 feeMultiplier,
        uint256 protocolFeeMultiplier
    )
        external
        pure
        returns (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 inputValue,
            uint256 protocolFee
        );

    /**
        @notice Given the current state of the pair and the trade, computes how much the user
        should receive when selling NFTs to the pair, the new spot price, and other values.
        @param spotPrice The current selling spot price of the pair, in ETH
        @param delta The delta parameter of the pair, what it means depends on the curve
        @param numItems The number of NFTs the user is selling to the pair
        @param feeMultiplier Determines how much fee the LP takes from this trade, 18 decimals
        @param protocolFeeMultiplier Determines how much fee the protocol takes from this trade, 18 decimals
        @return error Any math calculation errors, only Error.OK means the returned values are valid
        @return newSpotPrice The updated selling spot price, in ETH
        @return outputValue The amount that the user should receive, in ETH
        @return protocolFee The amount of fee to send to the protocol, in ETH
     */
    function getSellInfo(
        uint256 spotPrice,
        uint256 delta,
        uint256 numItems,
        uint256 feeMultiplier,
        uint256 protocolFeeMultiplier
    )
        external
        pure
        returns (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 outputValue,
            uint256 protocolFee
        );
}
