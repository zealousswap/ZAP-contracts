// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IContinuousClearingAuction} from '../interfaces/IContinuousClearingAuction.sol';
import {Checkpoint} from '../libraries/CheckpointLib.sol';
import {Currency} from '../libraries/CurrencyLibrary.sol';

/// @notice The state of the auction containing the latest checkpoint
/// as well as the currency raised, total cleared, and whether the auction has graduated
struct AuctionState {
    Checkpoint checkpoint;
    uint256 currencyRaised;
    uint256 totalCleared;
    bool isGraduated;
    uint256 currencyBalance;
    uint256 sumCurrencyDemandAboveClearingQ96;
}

/// @title AuctionStateLens
/// @notice Lens contract for reading the state of the Auction contract
contract AuctionStateLens {
    /// @notice Error thrown when the checkpoint fails
    error CheckpointFailed();
    /// @notice Error thrown when the revert reason is not the correct length
    error InvalidRevertReasonLength();

    /// @notice Function which can be called from offchain to get the latest state of the auction
    function state(IContinuousClearingAuction auction) external returns (AuctionState memory) {
        try this.revertWithState(auction) {}
        catch (bytes memory reason) {
            return parseRevertReason(reason);
        }
    }

    /// @notice Function which checkpoints the auction, gets global values and encodes them into a revert string
    function revertWithState(IContinuousClearingAuction auction) external {
        try auction.checkpoint() returns (Checkpoint memory checkpoint) {
            // Get currency balance of the auction contract
            Currency currency = Currency.wrap(auction.currency());
            uint256 currencyBalance = currency.balanceOf(address(auction));
            
            AuctionState memory _state = AuctionState({
                checkpoint: checkpoint,
                currencyRaised: auction.currencyRaised(),
                totalCleared: auction.totalCleared(),
                isGraduated: auction.isGraduated(),
                currencyBalance: currencyBalance,
                sumCurrencyDemandAboveClearingQ96: auction.sumCurrencyDemandAboveClearingQ96()
            });
            bytes memory dump = abi.encode(_state);

            assembly {
                revert(add(dump, 32), mload(dump))
            }
        } catch {
            revert CheckpointFailed();
        }
    }

    /// @notice Function which parses the revert reason and returns the AuctionState
    function parseRevertReason(bytes memory reason) internal pure returns (AuctionState memory) {
        // Dynamic size check - AuctionState now has 5 fields plus checkpoint struct
        // Just check minimum size and let abi.decode handle validation
        if (reason.length < 32) {
            // Bubble up the revert reason if possible
            if (reason.length > 32) {
                assembly {
                    revert(add(reason, 32), mload(reason))
                }
            } else {
                // If the revert reason is too short revert
                revert InvalidRevertReasonLength();
            }
        }
        return abi.decode(reason, (AuctionState));
    }
}
