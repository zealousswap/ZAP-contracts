// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IContinuousClearingAuction} from '../interfaces/IContinuousClearingAuction.sol';
import {Checkpoint} from '../libraries/CheckpointLib.sol';
import {Bid} from '../libraries/BidLib.sol';
import {ConstantsLib} from '../libraries/ConstantsLib.sol';
import {FixedPoint96} from '../libraries/FixedPoint96.sol';
import {ValueX7} from '../libraries/ValueX7Lib.sol';
import {Tick} from '../interfaces/ITickStorage.sol';
import {Currency} from '../libraries/CurrencyLibrary.sol';
import {FixedPointMathLib} from 'solady/utils/FixedPointMathLib.sol';

/// @notice Accumulated tokens info for a single bid
struct BidAccumulationInfo {
    uint256 bidId;
    Bid bid;
    uint256 tokensAccumulated;
    uint256 currencySpentQ96;
    bool isFullyAboveClearing;
    bool isOutbid;
    bool isMarginal;
    bool isExited;
    uint64 lastFullyFilledCheckpointBlock;
    uint64 outbidBlock;
    uint64 marginalCheckpointBlock; // Block where bid was at clearing price before getting outbid
}

/// @notice Full query result containing auction state and all bid accumulation info
struct QueryResult {
    Checkpoint checkpoint;
    uint256 currencyRaised;
    uint256 totalCleared;
    bool isGraduated;
    uint64 startBlock;
    uint64 endBlock;
    uint64 claimBlock;
    uint256 sumCurrencyDemandAboveClearingQ96;
    BidAccumulationInfo[] bids;
}

/// @notice Static auction parameters that don't change after deployment
struct AuctionParams {
    uint64 startBlock;
    uint64 endBlock;
    uint64 claimBlock;
    address currency;
    address token;
    uint256 tickSpacing;
    uint256 floorPrice;
    uint128 totalSupply;
    uint256 maxBidPrice;
}

/// @title Query
/// @notice Lens contract for batch querying bid accumulation data
/// @dev Uses the same try/revert pattern as AuctionStateLens to get fresh checkpoint data
contract Query {
    using FixedPointMathLib for *;

    /// @notice Error thrown when the checkpoint fails
    error CheckpointFailed();
    /// @notice Error thrown when the revert reason is not the correct length
    error InvalidRevertReasonLength();

    /// @notice Query all bid accumulation info for a list of bid IDs
    /// @dev This function triggers a checkpoint and calculates accumulated tokens for each bid
    /// @param auction The auction contract address
    /// @param bidIds Array of bid IDs to query
    /// @return result The full query result with auction state and bid info
    function queryBids(IContinuousClearingAuction auction, uint256[] calldata bidIds) external returns (QueryResult memory result) {
        try this.revertWithQueryResult(auction, bidIds) {}
        catch (bytes memory reason) {
            return parseRevertReason(reason);
        }
    }

    /// @notice Query the last N bids in an auction
    /// @dev This function fetches the most recent bids by looking at nextBidId and going backwards
    /// @param auction The auction contract address
    /// @param count Number of recent bids to fetch (e.g., 7)
    /// @return result The full query result with auction state and the last N bids
    function queryLastBids(IContinuousClearingAuction auction, uint256 count) external returns (QueryResult memory result) {
        uint256 nextBidId = auction.nextBidId();
        
        // If no bids exist, return empty result
        if (nextBidId == 0) {
            try this.revertWithQueryResult(auction, new uint256[](0)) {}
            catch (bytes memory reason) {
                return parseRevertReason(reason);
            }
        }
        
        // Calculate how many bids we can actually fetch
        uint256 actualCount = count > nextBidId ? nextBidId : count;
        
        // Build array of bid IDs (most recent first)
        uint256[] memory bidIds = new uint256[](actualCount);
        for (uint256 i = 0; i < actualCount; i++) {
            bidIds[i] = nextBidId - 1 - i;
        }
        
        try this.revertWithQueryResult(auction, bidIds) {}
        catch (bytes memory reason) {
            return parseRevertReason(reason);
        }
    }

    /// @notice Get static auction parameters in a single call
    /// @dev This is a view function - no state changes, no checkpoint needed
    /// @param auction The auction contract address
    /// @return params The static auction parameters
    function getAuctionParams(IContinuousClearingAuction auction) external view returns (AuctionParams memory params) {
        params.startBlock = auction.startBlock();
        params.endBlock = auction.endBlock();
        params.claimBlock = auction.claimBlock();
        params.currency = auction.currency();
        params.token = auction.token();
        params.tickSpacing = auction.tickSpacing();
        params.floorPrice = auction.floorPrice();
        params.totalSupply = auction.totalSupply();
        params.maxBidPrice = auction.MAX_BID_PRICE();
    }

    /// @notice Internal function that checkpoints and reverts with encoded result
    function revertWithQueryResult(IContinuousClearingAuction auction, uint256[] calldata bidIds) external {
        // Trigger checkpoint to get fresh data (same pattern as AuctionStateLens)
        try auction.checkpoint() returns (Checkpoint memory checkpoint) {
            QueryResult memory result = _buildQueryResult(auction, checkpoint, bidIds);
            bytes memory dump = abi.encode(result);

            assembly {
                revert(add(dump, 32), mload(dump))
            }
        } catch {
            revert CheckpointFailed();
        }
    }

    /// @notice Build the full query result
    function _buildQueryResult(
        IContinuousClearingAuction auction,
        Checkpoint memory checkpoint,
        uint256[] calldata bidIds
    ) internal view returns (QueryResult memory result) {
        result.checkpoint = checkpoint;
        result.currencyRaised = auction.currencyRaised();
        result.totalCleared = auction.totalCleared();
        result.isGraduated = auction.isGraduated();
        result.startBlock = auction.startBlock();
        result.endBlock = auction.endBlock();
        result.claimBlock = auction.claimBlock();
        result.sumCurrencyDemandAboveClearingQ96 = auction.sumCurrencyDemandAboveClearingQ96();

        result.bids = new BidAccumulationInfo[](bidIds.length);

        for (uint256 i = 0; i < bidIds.length; i++) {
            result.bids[i] = _calculateBidAccumulation(auction, checkpoint, bidIds[i]);
        }
    }

    /// @notice Calculate accumulation info for a single bid
    function _calculateBidAccumulation(
        IContinuousClearingAuction auction,
        Checkpoint memory currentCheckpoint,
        uint256 bidId
    ) internal view returns (BidAccumulationInfo memory info) {
        info.bidId = bidId;
        
        // Get bid data
        try auction.bids(bidId) returns (Bid memory bid) {
            info.bid = bid;
        } catch {
            // Bid doesn't exist, return empty info
            return info;
        }

        info.isExited = info.bid.exitedBlock > 0;

        // If already exited, use the stored tokensFilled value
        if (info.isExited) {
            info.tokensAccumulated = info.bid.tokensFilled;
            return info;
        }

        uint256 bidMaxPrice = info.bid.maxPrice;
        uint256 currentClearingPrice = currentCheckpoint.clearingPrice;

        // Determine bid status relative to clearing price
        info.isFullyAboveClearing = currentClearingPrice < bidMaxPrice;
        info.isMarginal = currentClearingPrice == bidMaxPrice;
        info.isOutbid = currentClearingPrice > bidMaxPrice;

        // Get the start checkpoint for this bid
        Checkpoint memory startCheckpoint = auction.checkpoints(info.bid.startBlock);
        
        // Calculate mpsRemaining for this bid
        uint24 mpsRemaining = ConstantsLib.MPS - info.bid.startCumulativeMps;
        if (mpsRemaining == 0) {
            // Bid was placed when auction was sold out
            return info;
        }

        if (info.isFullyAboveClearing) {
            // Bid is still above clearing - calculate accumulation from start to current
            (info.tokensAccumulated, info.currencySpentQ96) = _calculateFill(
                info.bid,
                currentCheckpoint.cumulativeMpsPerPrice - startCheckpoint.cumulativeMpsPerPrice,
                currentCheckpoint.cumulativeMps - startCheckpoint.cumulativeMps,
                mpsRemaining
            );
        } else {
            // Bid is outbid or marginal - need to find the last checkpoint where bid was above clearing
            // Traverse backwards to find exit hints
            (info.lastFullyFilledCheckpointBlock, info.outbidBlock, info.marginalCheckpointBlock) = _findExitHints(
                auction,
                info.bid,
                currentCheckpoint
            );

            if (info.lastFullyFilledCheckpointBlock > 0) {
                Checkpoint memory upperCheckpoint = auction.checkpoints(info.lastFullyFilledCheckpointBlock);
                (info.tokensAccumulated, info.currencySpentQ96) = _calculateFill(
                    info.bid,
                    upperCheckpoint.cumulativeMpsPerPrice - startCheckpoint.cumulativeMpsPerPrice,
                    upperCheckpoint.cumulativeMps - startCheckpoint.cumulativeMps,
                    mpsRemaining
                );
            }
            // If lastFullyFilledCheckpointBlock is 0, bid was never above clearing
            
            // For marginal bids (clearingPrice == bidMaxPrice), add partial fill calculation
            // This accounts for tokens being accumulated while AT the clearing price
            if (info.isMarginal) {
                (uint256 partialTokens, uint256 partialCurrency) = _calculatePartialFill(
                    auction,
                    info.bid,
                    currentCheckpoint,
                    mpsRemaining
                );
                info.tokensAccumulated += partialTokens;
                info.currencySpentQ96 += partialCurrency;
            }
            
            // For outbid bids that were previously at clearing price (marginal), 
            // add partial fill from that marginal period
            if (info.isOutbid && info.marginalCheckpointBlock > 0) {
                Checkpoint memory marginalCheckpoint = auction.checkpoints(info.marginalCheckpointBlock);
                (uint256 partialTokens, uint256 partialCurrency) = _calculatePartialFill(
                    auction,
                    info.bid,
                    marginalCheckpoint,
                    mpsRemaining
                );
                info.tokensAccumulated += partialTokens;
                info.currencySpentQ96 += partialCurrency;
            }
        }
    }

    /// @notice Calculate partial fill for a marginal bid (at clearing price)
    /// @dev This uses the same formula as CheckpointAccountingLib.accountPartiallyFilledCheckpoints
    /// @param auction The auction contract
    /// @param bid The bid being evaluated
    /// @param currentCheckpoint The current checkpoint (where clearingPrice == bid.maxPrice)
    /// @param mpsRemaining The mps remaining when the bid was placed
    /// @return tokensFilled The tokens filled from partial fill
    /// @return currencySpentQ96 The currency spent from partial fill in Q96 form
    function _calculatePartialFill(
        IContinuousClearingAuction auction,
        Bid memory bid,
        Checkpoint memory currentCheckpoint,
        uint24 mpsRemaining
    ) internal view returns (uint256 tokensFilled, uint256 currencySpentQ96) {
        // Get the tick demand at the bid's max price (which equals clearing price for marginal bids)
        Tick memory tick = auction.ticks(bid.maxPrice);
        uint256 tickDemandQ96 = tick.currencyDemandQ96;
        
        if (tickDemandQ96 == 0) return (0, 0);
        
        // Get the currency raised at the clearing price from the checkpoint
        // This is the cumulative currency raised to bids at this price level
        uint256 currencyRaisedAtClearingX7 = ValueX7.unwrap(currentCheckpoint.currencyRaisedAtClearingPriceQ96_X7);
        
        if (currencyRaisedAtClearingX7 == 0) return (0, 0);
        
        // Calculate proportional fill using the same formula as CheckpointAccountingLib
        // denominator = tickDemandQ96 * mpsRemaining
        uint256 denominator = tickDemandQ96 * uint256(mpsRemaining);
        
        // currencySpentQ96 = bid.amountQ96 * currencyRaisedAtClearingX7 / denominator (rounded up)
        currencySpentQ96 = bid.amountQ96.fullMulDivUp(currencyRaisedAtClearingX7, denominator);
        
        // tokensFilled = bid.amountQ96 * currencyRaisedAtClearingX7 / denominator / maxPrice
        tokensFilled = bid.amountQ96.fullMulDiv(currencyRaisedAtClearingX7, denominator) / bid.maxPrice;
    }

    /// @notice Find exit hints for a partially filled bid
    function _findExitHints(
        IContinuousClearingAuction auction,
        Bid memory bid,
        Checkpoint memory currentCheckpoint
    ) internal view returns (uint64 lastFullyFilledCheckpointBlock, uint64 outbidBlock, uint64 marginalCheckpointBlock) {
        uint256 bidMaxPrice = bid.maxPrice;
        uint64 bidStartBlock = bid.startBlock;
        
        // Start from current checkpoint and traverse backwards
        uint64 checkpointBlock = currentCheckpoint.prev;
        uint64 prevCheckpointAboveClearing = 0;
        uint64 foundMarginalBlock = 0;

        // If current checkpoint has clearing price > bidMaxPrice, find where it was outbid
        if (currentCheckpoint.clearingPrice > bidMaxPrice) {
            // Current is outbid, look for last fully filled
            while (checkpointBlock > 0 && checkpointBlock >= bidStartBlock) {
                Checkpoint memory checkpoint = auction.checkpoints(checkpointBlock);
                
                if (checkpoint.clearingPrice < bidMaxPrice) {
                    // Found last fully filled checkpoint
                    lastFullyFilledCheckpointBlock = checkpointBlock;
                    outbidBlock = prevCheckpointAboveClearing > 0 ? prevCheckpointAboveClearing : uint64(block.number);
                    marginalCheckpointBlock = foundMarginalBlock;
                    return (lastFullyFilledCheckpointBlock, outbidBlock, marginalCheckpointBlock);
                } else if (checkpoint.clearingPrice == bidMaxPrice) {
                    // Found a checkpoint where bid was marginal (at clearing price)
                    // Use the FIRST marginal checkpoint we encounter going backwards
                    // (which is the LAST marginal checkpoint chronologically before outbid)
                    if (foundMarginalBlock == 0) {
                        foundMarginalBlock = checkpointBlock;
                    }
                } else if (checkpoint.clearingPrice > bidMaxPrice) {
                    prevCheckpointAboveClearing = checkpointBlock;
                }
                
                checkpointBlock = checkpoint.prev;
            }
            // If we exit the loop without finding lastFullyFilledCheckpointBlock, 
            // the bid may have started as marginal and never been fully above clearing
            if (foundMarginalBlock > 0) {
                marginalCheckpointBlock = foundMarginalBlock;
            }
        } else if (currentCheckpoint.clearingPrice == bidMaxPrice) {
            // Marginal bid - find last fully filled (where price was strictly less)
            while (checkpointBlock > 0 && checkpointBlock >= bidStartBlock) {
                Checkpoint memory checkpoint = auction.checkpoints(checkpointBlock);
                
                if (checkpoint.clearingPrice < bidMaxPrice) {
                    lastFullyFilledCheckpointBlock = checkpointBlock;
                    outbidBlock = 0; // Marginal at end, no outbid block
                    return (lastFullyFilledCheckpointBlock, outbidBlock, 0);
                }
                
                checkpointBlock = checkpoint.prev;
            }
        }

        return (0, 0, marginalCheckpointBlock);
    }

    /// @notice Calculate tokens filled using lazy accounting (same formula as CheckpointAccountingLib)
    function _calculateFill(
        Bid memory bid,
        uint256 cumulativeMpsPerPriceDelta,
        uint24 cumulativeMpsDelta,
        uint24 mpsRemaining
    ) internal pure returns (uint256 tokensFilled, uint256 currencySpentQ96) {
        // Currency spent is original currency amount multiplied by percentage fully filled over percentage allocated
        currencySpentQ96 = bid.amountQ96.fullMulDivUp(cumulativeMpsDelta, mpsRemaining);

        // Tokens filled are calculated from the effective amount over the allocation
        tokensFilled = bid.amountQ96.fullMulDiv(
            cumulativeMpsPerPriceDelta,
            (FixedPoint96.Q96 << FixedPoint96.RESOLUTION) * mpsRemaining
        );
    }

    /// @notice Parse the revert reason and return the QueryResult
    function parseRevertReason(bytes memory reason) internal pure returns (QueryResult memory) {
        // Dynamic struct, so we can't check exact length like AuctionStateLens
        // Just try to decode - will revert if invalid
        if (reason.length < 32) {
            revert InvalidRevertReasonLength();
        }
        return abi.decode(reason, (QueryResult));
    }
}
