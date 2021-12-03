// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";

import {LSSVMPair} from "../../LSSVMPair.sol";
import {LSSVMPairEnumerable} from "../../LSSVMPairEnumerable.sol";
import {LSSVMPairMissingEnumerable} from "../../LSSVMPairMissingEnumerable.sol";
import {LSSVMPairFactory} from "../../LSSVMPairFactory.sol";
import {ICurve} from "../../bonding-curves/ICurve.sol";
import {CurveErrorCodes} from "../../bonding-curves/CurveErrorCodes.sol";
import {Test721} from "../../mocks/Test721.sol";
import {IERC721Mintable} from "../../test/IERC721Mintable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {Hevm} from "../utils/Hevm.sol";

abstract contract LSSVMPairBaseTest is DSTest, ERC721Holder {
    uint256[] idList;
    uint256 startingId;
    IERC721Mintable test721;
    ICurve bondingCurve;
    LSSVMPairFactory factory;
    address payable constant feeRecipient = payable(address(69));
    uint256 constant protocolFeeMultiplier = 3e15;

    function setUp() public {
        bondingCurve = setupCurve();
        test721 = setup721();
        LSSVMPair enumerableTemplate = new LSSVMPairEnumerable();
        LSSVMPair missingEnumerableTemplate = new LSSVMPairMissingEnumerable();
        factory = new LSSVMPairFactory(
            enumerableTemplate,
            missingEnumerableTemplate,
            feeRecipient,
            protocolFeeMultiplier
        );
        test721.setApprovalForAll(address(factory), true);
        factory.setBondingCurveAllowed(bondingCurve, true);
    }

    /**
    @dev Ensures selling NFTs & buying them back results in no profit.
     */
    function test_bondingCurveSellBuyNoProfit(
        uint56 spotPrice,
        uint64 delta,
        uint8 numItems
    ) public payable {
        // modify spotPrice to be appropriate for the bonding curve
        spotPrice = modifySpotPrice(spotPrice);

        // modify delta to be appropriate for the bonding curve
        delta = modifyDelta(delta);

        // decrease the range of numItems to speed up testing
        numItems = numItems % 3;

        if (numItems == 0) {
            return;
        }

        delete idList;

        // initialize the pair
        uint256[] memory empty;
        LSSVMPair pair = factory.createPair(
            test721,
            bondingCurve,
            LSSVMPair.PoolType.TRADE,
            delta,
            0,
            spotPrice,
            empty
        );

        // mint NFTs to sell to the pair
        for (uint256 i = 0; i < numItems; i++) {
            test721.mint(address(this), startingId);
            idList.push(startingId);
            startingId += 1;
        }

        uint256 startBalance;
        uint256 endBalance;

        // sell all NFTs minted to the pair
        {
            (
                ,
                uint256 newSpotPrice,
                uint256 outputAmount,
                uint256 protocolFee
            ) = bondingCurve.getSellInfo(
                    spotPrice,
                    delta,
                    numItems,
                    0,
                    protocolFeeMultiplier
                );

            // give the pair contract enough ETH to pay for the NFTs
            payable(address(pair)).transfer(outputAmount + protocolFee);

            // sell NFTs
            test721.setApprovalForAll(address(pair), true);
            startBalance = address(this).balance;
            pair.swapNFTsForETH(idList, 0, payable(address(this)));
            spotPrice = uint56(newSpotPrice);
        }

        // buy back the NFTs just sold to the pair
        {
            (, , uint256 inputAmount, ) = bondingCurve.getBuyInfo(
                spotPrice,
                delta,
                numItems,
                0,
                protocolFeeMultiplier
            );
            pair.swapETHForAnyNFTs{value: inputAmount}(
                idList.length,
                address(this)
            );
            endBalance = address(this).balance;
        }

        // ensure the caller didn't profit from the aggregate trade
        assertGeDecimal(startBalance, endBalance, 18);

        // withdraw the ETH in the pair back
        pair.withdrawAllETH();
    }

    /**
    @dev Ensures buying NFTs & selling them back results in no profit.
     */
    function test_bondingCurveBuySellNoProfit(
        uint56 spotPrice,
        uint64 delta,
        uint8 numItems
    ) public payable {
        // modify spotPrice to be appropriate for the bonding curve
        spotPrice = modifySpotPrice(spotPrice);

        // modify delta to be appropriate for the bonding curve
        delta = modifyDelta(delta);

        // decrease the range of numItems to speed up testing
        numItems = numItems % 3;

        if (numItems == 0) {
            return;
        }

        delete idList;

        // initialize the pair
        for (uint256 i = 0; i < numItems; i++) {
            test721.mint(address(this), startingId);
            idList.push(startingId);
            startingId += 1;
        }
        LSSVMPair pair = factory.createPair(
            test721,
            bondingCurve,
            LSSVMPair.PoolType.TRADE,
            delta,
            0,
            spotPrice,
            idList
        );
        test721.setApprovalForAll(address(pair), true);

        uint256 startBalance;
        uint256 endBalance;

        // buy all NFTs
        {
            (, uint256 newSpotPrice, uint256 inputAmount, ) = bondingCurve
                .getBuyInfo(
                    spotPrice,
                    delta,
                    numItems,
                    0,
                    protocolFeeMultiplier
                );

            // buy NFTs
            startBalance = address(this).balance;
            pair.swapETHForAnyNFTs{value: inputAmount}(numItems, address(this));
            spotPrice = uint56(newSpotPrice);
        }

        // sell back the NFTs
        {
            bondingCurve.getSellInfo(
                spotPrice,
                delta,
                numItems,
                0,
                protocolFeeMultiplier
            );
            pair.swapNFTsForETH(idList, 0, payable(address(this)));
            endBalance = address(this).balance;
        }

        // ensure the caller didn't profit from the aggregate trade
        assertGeDecimal(startBalance, endBalance, 18);

        // withdraw the ETH in the pair back
        pair.withdrawAllETH();
    }

    function setupCurve() public virtual returns (ICurve);

    function setup721() public virtual returns (IERC721Mintable);

    function modifyDelta(uint64 delta) public virtual returns (uint64) {
        return delta;
    }

    function modifySpotPrice(uint56 spotPrice) public virtual returns (uint56) {
        return spotPrice;
    }

    receive() external payable {}
}