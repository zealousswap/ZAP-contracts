// SPDX-License-Identifier: MIT
pragma solidity =0.8.26 ^0.8.0 ^0.8.20 ^0.8.24 ^0.8.4;

// lib/blocknumberish/src/BlockNumberish.sol

/// @title BlockNumberish
/// A helper contract to get the current block number on different chains
/// inspired by https://github.com/ProjectOpenSea/tstorish/blob/main/src/Tstorish.sol
/// @custom:security-contact security@uniswap.org
contract BlockNumberish {
    // Arbitrum One chain ID.
    uint256 private constant ARB_CHAIN_ID = 42_161;
    // Unichain chain ID.
    uint256 private constant UNICHAIN_CHAIN_ID = 130;
    /// @dev Function selector for arbBlockNumber() from: https://github.com/OffchainLabs/nitro-precompile-interfaces/blob/f49a4889b486fd804a7901203f5f663cfd1581c8/ArbSys.sol#L17
    uint32 private constant ARB_SYS_SELECTOR = 0xa3b1b31d;
    /// @dev Arbitrum system contract address (address(100))
    uint8 private constant ARB_SYS_ADDRESS = 0x64;
    /// @dev Function selector for getFlashblockNumber() from: https://github.com/Uniswap/flashblocks_number_contract/blob/a667d57f0055de80b9909c8837e872c4364853c3/src/IFlashblockNumber.sol#L70
    uint32 private constant UNICHAIN_FLASHBLOCK_NUMBER_SELECTOR = 0xe5b37c5d;
    /// @dev Unichain flashblock number address
    address private constant UNICHAIN_FLASHBLOCK_NUMBER_ADDRESS = 0x3c3A8a41E095C76b03f79f70955fFf3b03cf753E;

    /// @notice Internal view function to get the current block number.
    /// @dev Returns Arbitrum block number on Arbitrum One, standard block number elsewhere.
    function _getBlockNumberish() internal view returns (uint256 blockNumber) {
        if (block.chainid == ARB_CHAIN_ID) {
            assembly {
                mstore(0x00, ARB_SYS_SELECTOR)
                // staticcall(gas, address, argsOffset, argsSize, retOffset, retSize)
                let success := staticcall(gas(), ARB_SYS_ADDRESS, 0x1c, 0x04, 0x00, 0x20)
                // revert if the call fails from OOG or returns malformed data
                if or(iszero(success), iszero(eq(returndatasize(), 0x20))) {
                    revert(0, 0)
                }

                // load the stored block number from memory
                blockNumber := mload(0x00)
            }
        } else {
            blockNumber = block.number;
        }
    }

    /// @notice Internal view function to get the current flashblock number.
    /// @dev Returns Unichain flashblock number on Unichain, 0 elsewhere.
    function _getFlashblockNumberish() internal view returns (uint256 flashblockNumber) {
        if (block.chainid == UNICHAIN_CHAIN_ID) {
            assembly {
                mstore(0x00, UNICHAIN_FLASHBLOCK_NUMBER_SELECTOR)
                // staticcall(gas, address, argsOffset, argsSize, retOffset, retSize)
                let success := staticcall(gas(), UNICHAIN_FLASHBLOCK_NUMBER_ADDRESS, 0x1c, 0x04, 0x00, 0x20)
                // revert if the call fails from OOG or returns malformed data
                if or(iszero(success), iszero(eq(returndatasize(), 0x20))) {
                    revert(0, 0)
                }

                // load the stored block number from memory
                flashblockNumber := mload(0x00)
            }
        }
    }
}

// src/libraries/ConstantsLib.sol

/// @title ConstantsLib
/// @notice Library containing protocol constants
library ConstantsLib {
    /// @notice we use milli-bips, or one thousandth of a basis point
    uint24 constant MPS = 1e7;
    /// @notice The upper bound of a ValueX7 value
    uint256 constant X7_UPPER_BOUND = type(uint256).max / 1e7;

    /// @notice The maximum total supply of tokens that can be sold in the Auction
    /// @dev    This is set to 2^100 tokens, which is just above 1e30, or one trillion units of a token with 18 decimals.
    ///         This upper bound is chosen to prevent the Auction from being used with an extremely large token supply,
    ///         which would restrict the clearing price to be a very low price in the calculation below.
    uint128 constant MAX_TOTAL_SUPPLY = 1 << 100;

    /// @notice The minimum allowable floor price is type(uint32).max + 1
    /// @dev This is the minimum price that fits in a uint160 after being inversed
    uint256 constant MIN_FLOOR_PRICE = uint256(type(uint32).max) + 1;

    /// @notice The minimum allowable tick spacing
    /// @dev We don't support tick spacings of 1 to avoid edge cases where the rounding of the clearing price
    ///      would cause the price to move between initialized ticks.
    uint256 constant MIN_TICK_SPACING = 2;
}

// src/libraries/FixedPoint96.sol

/// @title FixedPoint96
/// @notice A library for handling binary fixed point numbers, see https://en.wikipedia.org/wiki/Q_(number_format)
/// @dev Copied from https://github.com/Uniswap/v4-core/blob/main/src/libraries/FixedPoint96.sol
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}

// lib/solady/src/utils/FixedPointMathLib.sol

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol)
library FixedPointMathLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The operation failed, as the output exceeds the maximum value of uint256.
    error ExpOverflow();

    /// @dev The operation failed, as the output exceeds the maximum value of uint256.
    error FactorialOverflow();

    /// @dev The operation failed, due to an overflow.
    error RPowOverflow();

    /// @dev The mantissa is too big to fit.
    error MantissaOverflow();

    /// @dev The operation failed, due to an multiplication overflow.
    error MulWadFailed();

    /// @dev The operation failed, due to an multiplication overflow.
    error SMulWadFailed();

    /// @dev The operation failed, either due to a multiplication overflow, or a division by a zero.
    error DivWadFailed();

    /// @dev The operation failed, either due to a multiplication overflow, or a division by a zero.
    error SDivWadFailed();

    /// @dev The operation failed, either due to a multiplication overflow, or a division by a zero.
    error MulDivFailed();

    /// @dev The division failed, as the denominator is zero.
    error DivFailed();

    /// @dev The full precision multiply-divide operation failed, either due
    /// to the result being larger than 256 bits, or a division by a zero.
    error FullMulDivFailed();

    /// @dev The output is undefined, as the input is less-than-or-equal to zero.
    error LnWadUndefined();

    /// @dev The input outside the acceptable domain.
    error OutOfDomain();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The scalar of ETH and most ERC20s.
    uint256 internal constant WAD = 1e18;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*              SIMPLIFIED FIXED POINT OPERATIONS             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Equivalent to `(x * y) / WAD` rounded down.
    function mulWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
            if gt(x, div(not(0), y)) {
                if y {
                    mstore(0x00, 0xbac65e5b) // `MulWadFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            z := div(mul(x, y), WAD)
        }
    }

    /// @dev Equivalent to `(x * y) / WAD` rounded down.
    function sMulWad(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            // Equivalent to `require((x == 0 || z / x == y) && !(x == -1 && y == type(int256).min))`.
            if iszero(gt(or(iszero(x), eq(sdiv(z, x), y)), lt(not(x), eq(y, shl(255, 1))))) {
                mstore(0x00, 0xedcd4dd4) // `SMulWadFailed()`.
                revert(0x1c, 0x04)
            }
            z := sdiv(z, WAD)
        }
    }

    /// @dev Equivalent to `(x * y) / WAD` rounded down, but without overflow checks.
    function rawMulWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := div(mul(x, y), WAD)
        }
    }

    /// @dev Equivalent to `(x * y) / WAD` rounded down, but without overflow checks.
    function rawSMulWad(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := sdiv(mul(x, y), WAD)
        }
    }

    /// @dev Equivalent to `(x * y) / WAD` rounded up.
    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
            if iszero(eq(div(z, y), x)) {
                if y {
                    mstore(0x00, 0xbac65e5b) // `MulWadFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            z := add(iszero(iszero(mod(z, WAD))), div(z, WAD))
        }
    }

    /// @dev Equivalent to `(x * y) / WAD` rounded up, but without overflow checks.
    function rawMulWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := add(iszero(iszero(mod(mul(x, y), WAD))), div(mul(x, y), WAD))
        }
    }

    /// @dev Equivalent to `(x * WAD) / y` rounded down.
    function divWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to `require(y != 0 && x <= type(uint256).max / WAD)`.
            if iszero(mul(y, lt(x, add(1, div(not(0), WAD))))) {
                mstore(0x00, 0x7c5f487d) // `DivWadFailed()`.
                revert(0x1c, 0x04)
            }
            z := div(mul(x, WAD), y)
        }
    }

    /// @dev Equivalent to `(x * WAD) / y` rounded down.
    function sDivWad(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, WAD)
            // Equivalent to `require(y != 0 && ((x * WAD) / WAD == x))`.
            if iszero(mul(y, eq(sdiv(z, WAD), x))) {
                mstore(0x00, 0x5c43740d) // `SDivWadFailed()`.
                revert(0x1c, 0x04)
            }
            z := sdiv(z, y)
        }
    }

    /// @dev Equivalent to `(x * WAD) / y` rounded down, but without overflow and divide by zero checks.
    function rawDivWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := div(mul(x, WAD), y)
        }
    }

    /// @dev Equivalent to `(x * WAD) / y` rounded down, but without overflow and divide by zero checks.
    function rawSDivWad(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := sdiv(mul(x, WAD), y)
        }
    }

    /// @dev Equivalent to `(x * WAD) / y` rounded up.
    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to `require(y != 0 && x <= type(uint256).max / WAD)`.
            if iszero(mul(y, lt(x, add(1, div(not(0), WAD))))) {
                mstore(0x00, 0x7c5f487d) // `DivWadFailed()`.
                revert(0x1c, 0x04)
            }
            z := add(iszero(iszero(mod(mul(x, WAD), y))), div(mul(x, WAD), y))
        }
    }

    /// @dev Equivalent to `(x * WAD) / y` rounded up, but without overflow and divide by zero checks.
    function rawDivWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := add(iszero(iszero(mod(mul(x, WAD), y))), div(mul(x, WAD), y))
        }
    }

    /// @dev Equivalent to `x` to the power of `y`.
    /// because `x ** y = (e ** ln(x)) ** y = e ** (ln(x) * y)`.
    /// Note: This function is an approximation.
    function powWad(int256 x, int256 y) internal pure returns (int256) {
        // Using `ln(x)` means `x` must be greater than 0.
        return expWad((lnWad(x) * y) / int256(WAD));
    }

    /// @dev Returns `exp(x)`, denominated in `WAD`.
    /// Credit to Remco Bloemen under MIT license: https://2π.com/22/exp-ln
    /// Note: This function is an approximation. Monotonically increasing.
    function expWad(int256 x) internal pure returns (int256 r) {
        unchecked {
            // When the result is less than 0.5 we return zero.
            // This happens when `x <= (log(1e-18) * 1e18) ~ -4.15e19`.
            if (x <= -41446531673892822313) return r;

            /// @solidity memory-safe-assembly
            assembly {
                // When the result is greater than `(2**255 - 1) / 1e18` we can not represent it as
                // an int. This happens when `x >= floor(log((2**255 - 1) / 1e18) * 1e18) ≈ 135`.
                if iszero(slt(x, 135305999368893231589)) {
                    mstore(0x00, 0xa37bfec9) // `ExpOverflow()`.
                    revert(0x1c, 0x04)
                }
            }

            // `x` is now in the range `(-42, 136) * 1e18`. Convert to `(-42, 136) * 2**96`
            // for more intermediate precision and a binary basis. This base conversion
            // is a multiplication by 1e18 / 2**96 = 5**18 / 2**78.
            x = (x << 78) / 5 ** 18;

            // Reduce range of x to (-½ ln 2, ½ ln 2) * 2**96 by factoring out powers
            // of two such that exp(x) = exp(x') * 2**k, where k is an integer.
            // Solving this gives k = round(x / log(2)) and x' = x - k * log(2).
            int256 k = ((x << 96) / 54916777467707473351141471128 + 2 ** 95) >> 96;
            x = x - k * 54916777467707473351141471128;

            // `k` is in the range `[-61, 195]`.

            // Evaluate using a (6, 7)-term rational approximation.
            // `p` is made monic, we'll multiply by a scale factor later.
            int256 y = x + 1346386616545796478920950773328;
            y = ((y * x) >> 96) + 57155421227552351082224309758442;
            int256 p = y + x - 94201549194550492254356042504812;
            p = ((p * y) >> 96) + 28719021644029726153956944680412240;
            p = p * x + (4385272521454847904659076985693276 << 96);

            // We leave `p` in `2**192` basis so we don't need to scale it back up for the division.
            int256 q = x - 2855989394907223263936484059900;
            q = ((q * x) >> 96) + 50020603652535783019961831881945;
            q = ((q * x) >> 96) - 533845033583426703283633433725380;
            q = ((q * x) >> 96) + 3604857256930695427073651918091429;
            q = ((q * x) >> 96) - 14423608567350463180887372962807573;
            q = ((q * x) >> 96) + 26449188498355588339934803723976023;

            /// @solidity memory-safe-assembly
            assembly {
                // Div in assembly because solidity adds a zero check despite the unchecked.
                // The q polynomial won't have zeros in the domain as all its roots are complex.
                // No scaling is necessary because p is already `2**96` too large.
                r := sdiv(p, q)
            }

            // r should be in the range `(0.09, 0.25) * 2**96`.

            // We now need to multiply r by:
            // - The scale factor `s ≈ 6.031367120`.
            // - The `2**k` factor from the range reduction.
            // - The `1e18 / 2**96` factor for base conversion.
            // We do this all at once, with an intermediate result in `2**213`
            // basis, so the final right shift is always by a positive amount.
            r = int256(
                (uint256(r) * 3822833074963236453042738258902158003155416615667) >> uint256(195 - k)
            );
        }
    }

    /// @dev Returns `ln(x)`, denominated in `WAD`.
    /// Credit to Remco Bloemen under MIT license: https://2π.com/22/exp-ln
    /// Note: This function is an approximation. Monotonically increasing.
    function lnWad(int256 x) internal pure returns (int256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            // We want to convert `x` from `10**18` fixed point to `2**96` fixed point.
            // We do this by multiplying by `2**96 / 10**18`. But since
            // `ln(x * C) = ln(x) + ln(C)`, we can simply do nothing here
            // and add `ln(2**96 / 10**18)` at the end.

            // Compute `k = log2(x) - 96`, `r = 159 - k = 255 - log2(x) = 255 ^ log2(x)`.
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            // We place the check here for more optimal stack operations.
            if iszero(sgt(x, 0)) {
                mstore(0x00, 0x1615e638) // `LnWadUndefined()`.
                revert(0x1c, 0x04)
            }
            // forgefmt: disable-next-item
            r := xor(r, byte(and(0x1f, shr(shr(r, x), 0x8421084210842108cc6318c6db6d54be)),
                0xf8f9f9faf9fdfafbf9fdfcfdfafbfcfef9fafdfafcfcfbfefafafcfbffffffff))

            // Reduce range of x to (1, 2) * 2**96
            // ln(2^k * x) = k * ln(2) + ln(x)
            x := shr(159, shl(r, x))

            // Evaluate using a (8, 8)-term rational approximation.
            // `p` is made monic, we will multiply by a scale factor later.
            // forgefmt: disable-next-item
            let p := sub( // This heavily nested expression is to avoid stack-too-deep for via-ir.
                sar(96, mul(add(43456485725739037958740375743393,
                sar(96, mul(add(24828157081833163892658089445524,
                sar(96, mul(add(3273285459638523848632254066296,
                    x), x))), x))), x)), 11111509109440967052023855526967)
            p := sub(sar(96, mul(p, x)), 45023709667254063763336534515857)
            p := sub(sar(96, mul(p, x)), 14706773417378608786704636184526)
            p := sub(mul(p, x), shl(96, 795164235651350426258249787498))
            // We leave `p` in `2**192` basis so we don't need to scale it back up for the division.

            // `q` is monic by convention.
            let q := add(5573035233440673466300451813936, x)
            q := add(71694874799317883764090561454958, sar(96, mul(x, q)))
            q := add(283447036172924575727196451306956, sar(96, mul(x, q)))
            q := add(401686690394027663651624208769553, sar(96, mul(x, q)))
            q := add(204048457590392012362485061816622, sar(96, mul(x, q)))
            q := add(31853899698501571402653359427138, sar(96, mul(x, q)))
            q := add(909429971244387300277376558375, sar(96, mul(x, q)))

            // `p / q` is in the range `(0, 0.125) * 2**96`.

            // Finalization, we need to:
            // - Multiply by the scale factor `s = 5.549…`.
            // - Add `ln(2**96 / 10**18)`.
            // - Add `k * ln(2)`.
            // - Multiply by `10**18 / 2**96 = 5**18 >> 78`.

            // The q polynomial is known not to have zeros in the domain.
            // No scaling required because p is already `2**96` too large.
            p := sdiv(p, q)
            // Multiply by the scaling factor: `s * 5**18 * 2**96`, base is now `5**18 * 2**192`.
            p := mul(1677202110996718588342820967067443963516166, p)
            // Add `ln(2) * k * 5**18 * 2**192`.
            // forgefmt: disable-next-item
            p := add(mul(16597577552685614221487285958193947469193820559219878177908093499208371, sub(159, r)), p)
            // Add `ln(2**96 / 10**18) * 5**18 * 2**192`.
            p := add(600920179829731861736702779321621459595472258049074101567377883020018308, p)
            // Base conversion: mul `2**18 / 2**192`.
            r := sar(174, p)
        }
    }

    /// @dev Returns `W_0(x)`, denominated in `WAD`.
    /// See: https://en.wikipedia.org/wiki/Lambert_W_function
    /// a.k.a. Product log function. This is an approximation of the principal branch.
    /// Note: This function is an approximation. Monotonically increasing.
    function lambertW0Wad(int256 x) internal pure returns (int256 w) {
        // forgefmt: disable-next-item
        unchecked {
            if ((w = x) <= -367879441171442322) revert OutOfDomain(); // `x` less than `-1/e`.
            (int256 wad, int256 p) = (int256(WAD), x);
            uint256 c; // Whether we need to avoid catastrophic cancellation.
            uint256 i = 4; // Number of iterations.
            if (w <= 0x1ffffffffffff) {
                if (-0x4000000000000 <= w) {
                    i = 1; // Inputs near zero only take one step to converge.
                } else if (w <= -0x3ffffffffffffff) {
                    i = 32; // Inputs near `-1/e` take very long to converge.
                }
            } else if (uint256(w >> 63) == uint256(0)) {
                /// @solidity memory-safe-assembly
                assembly {
                    // Inline log2 for more performance, since the range is small.
                    let v := shr(49, w)
                    let l := shl(3, lt(0xff, v))
                    l := add(or(l, byte(and(0x1f, shr(shr(l, v), 0x8421084210842108cc6318c6db6d54be)),
                        0x0706060506020504060203020504030106050205030304010505030400000000)), 49)
                    w := sdiv(shl(l, 7), byte(sub(l, 31), 0x0303030303030303040506080c13))
                    c := gt(l, 60)
                    i := add(2, add(gt(l, 53), c))
                }
            } else {
                int256 ll = lnWad(w = lnWad(w));
                /// @solidity memory-safe-assembly
                assembly {
                    // `w = ln(x) - ln(ln(x)) + b * ln(ln(x)) / ln(x)`.
                    w := add(sdiv(mul(ll, 1023715080943847266), w), sub(w, ll))
                    i := add(3, iszero(shr(68, x)))
                    c := iszero(shr(143, x))
                }
                if (c == uint256(0)) {
                    do { // If `x` is big, use Newton's so that intermediate values won't overflow.
                        int256 e = expWad(w);
                        /// @solidity memory-safe-assembly
                        assembly {
                            let t := mul(w, div(e, wad))
                            w := sub(w, sdiv(sub(t, x), div(add(e, t), wad)))
                        }
                        if (p <= w) break;
                        p = w;
                    } while (--i != uint256(0));
                    /// @solidity memory-safe-assembly
                    assembly {
                        w := sub(w, sgt(w, 2))
                    }
                    return w;
                }
            }
            do { // Otherwise, use Halley's for faster convergence.
                int256 e = expWad(w);
                /// @solidity memory-safe-assembly
                assembly {
                    let t := add(w, wad)
                    let s := sub(mul(w, e), mul(x, wad))
                    w := sub(w, sdiv(mul(s, wad), sub(mul(e, t), sdiv(mul(add(t, wad), s), add(t, t)))))
                }
                if (p <= w) break;
                p = w;
            } while (--i != c);
            /// @solidity memory-safe-assembly
            assembly {
                w := sub(w, sgt(w, 2))
            }
            // For certain ranges of `x`, we'll use the quadratic-rate recursive formula of
            // R. Iacono and J.P. Boyd for the last iteration, to avoid catastrophic cancellation.
            if (c == uint256(0)) return w;
            int256 t = w | 1;
            /// @solidity memory-safe-assembly
            assembly {
                x := sdiv(mul(x, wad), t)
            }
            x = (t * (wad + lnWad(x)));
            /// @solidity memory-safe-assembly
            assembly {
                w := sdiv(x, add(wad, t))
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  GENERAL NUMBER UTILITIES                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns `a * b == x * y`, with full precision.
    function fullMulEq(uint256 a, uint256 b, uint256 x, uint256 y)
        internal
        pure
        returns (bool result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := and(eq(mul(a, b), mul(x, y)), eq(mulmod(x, y, not(0)), mulmod(a, b, not(0))))
        }
    }

    /// @dev Calculates `floor(x * y / d)` with full precision.
    /// Throws if result overflows a uint256 or when `d` is zero.
    /// Credit to Remco Bloemen under MIT license: https://2π.com/21/muldiv
    function fullMulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // 512-bit multiply `[p1 p0] = x * y`.
            // Compute the product mod `2**256` and mod `2**256 - 1`
            // then use the Chinese Remainder Theorem to reconstruct
            // the 512 bit result. The result is stored in two 256
            // variables such that `product = p1 * 2**256 + p0`.

            // Temporarily use `z` as `p0` to save gas.
            z := mul(x, y) // Lower 256 bits of `x * y`.
            for {} 1 {} {
                // If overflows.
                if iszero(mul(or(iszero(x), eq(div(z, x), y)), d)) {
                    let mm := mulmod(x, y, not(0))
                    let p1 := sub(mm, add(z, lt(mm, z))) // Upper 256 bits of `x * y`.

                    /*------------------- 512 by 256 division --------------------*/

                    // Make division exact by subtracting the remainder from `[p1 p0]`.
                    let r := mulmod(x, y, d) // Compute remainder using mulmod.
                    let t := and(d, sub(0, d)) // The least significant bit of `d`. `t >= 1`.
                    // Make sure `z` is less than `2**256`. Also prevents `d == 0`.
                    // Placing the check here seems to give more optimal stack operations.
                    if iszero(gt(d, p1)) {
                        mstore(0x00, 0xae47f702) // `FullMulDivFailed()`.
                        revert(0x1c, 0x04)
                    }
                    d := div(d, t) // Divide `d` by `t`, which is a power of two.
                    // Invert `d mod 2**256`
                    // Now that `d` is an odd number, it has an inverse
                    // modulo `2**256` such that `d * inv = 1 mod 2**256`.
                    // Compute the inverse by starting with a seed that is correct
                    // correct for four bits. That is, `d * inv = 1 mod 2**4`.
                    let inv := xor(2, mul(3, d))
                    // Now use Newton-Raphson iteration to improve the precision.
                    // Thanks to Hensel's lifting lemma, this also works in modular
                    // arithmetic, doubling the correct bits in each step.
                    inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**8
                    inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**16
                    inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**32
                    inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**64
                    inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**128
                    z :=
                        mul(
                            // Divide [p1 p0] by the factors of two.
                            // Shift in bits from `p1` into `p0`. For this we need
                            // to flip `t` such that it is `2**256 / t`.
                            or(mul(sub(p1, gt(r, z)), add(div(sub(0, t), t), 1)), div(sub(z, r), t)),
                            mul(sub(2, mul(d, inv)), inv) // inverse mod 2**256
                        )
                    break
                }
                z := div(z, d)
                break
            }
        }
    }

    /// @dev Calculates `floor(x * y / d)` with full precision.
    /// Behavior is undefined if `d` is zero or the final result cannot fit in 256 bits.
    /// Performs the full 512 bit calculation regardless.
    function fullMulDivUnchecked(uint256 x, uint256 y, uint256 d)
        internal
        pure
        returns (uint256 z)
    {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            let mm := mulmod(x, y, not(0))
            let p1 := sub(mm, add(z, lt(mm, z)))
            let t := and(d, sub(0, d))
            let r := mulmod(x, y, d)
            d := div(d, t)
            let inv := xor(2, mul(3, d))
            inv := mul(inv, sub(2, mul(d, inv)))
            inv := mul(inv, sub(2, mul(d, inv)))
            inv := mul(inv, sub(2, mul(d, inv)))
            inv := mul(inv, sub(2, mul(d, inv)))
            inv := mul(inv, sub(2, mul(d, inv)))
            z :=
                mul(
                    or(mul(sub(p1, gt(r, z)), add(div(sub(0, t), t), 1)), div(sub(z, r), t)),
                    mul(sub(2, mul(d, inv)), inv)
                )
        }
    }

    /// @dev Calculates `floor(x * y / d)` with full precision, rounded up.
    /// Throws if result overflows a uint256 or when `d` is zero.
    /// Credit to Uniswap-v3-core under MIT license:
    /// https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/FullMath.sol
    function fullMulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        z = fullMulDiv(x, y, d);
        /// @solidity memory-safe-assembly
        assembly {
            if mulmod(x, y, d) {
                z := add(z, 1)
                if iszero(z) {
                    mstore(0x00, 0xae47f702) // `FullMulDivFailed()`.
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    /// @dev Calculates `floor(x * y / 2 ** n)` with full precision.
    /// Throws if result overflows a uint256.
    /// Credit to Philogy under MIT license:
    /// https://github.com/SorellaLabs/angstrom/blob/main/contracts/src/libraries/X128MathLib.sol
    function fullMulDivN(uint256 x, uint256 y, uint8 n) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Temporarily use `z` as `p0` to save gas.
            z := mul(x, y) // Lower 256 bits of `x * y`. We'll call this `z`.
            for {} 1 {} {
                if iszero(or(iszero(x), eq(div(z, x), y))) {
                    let k := and(n, 0xff) // `n`, cleaned.
                    let mm := mulmod(x, y, not(0))
                    let p1 := sub(mm, add(z, lt(mm, z))) // Upper 256 bits of `x * y`.
                    //         |      p1     |      z     |
                    // Before: | p1_0 ¦ p1_1 | z_0  ¦ z_1 |
                    // Final:  |   0  ¦ p1_0 | p1_1 ¦ z_0 |
                    // Check that final `z` doesn't overflow by checking that p1_0 = 0.
                    if iszero(shr(k, p1)) {
                        z := add(shl(sub(256, k), p1), shr(k, z))
                        break
                    }
                    mstore(0x00, 0xae47f702) // `FullMulDivFailed()`.
                    revert(0x1c, 0x04)
                }
                z := shr(and(n, 0xff), z)
                break
            }
        }
    }

    /// @dev Returns `floor(x * y / d)`.
    /// Reverts if `x * y` overflows, or `d` is zero.
    function mulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            // Equivalent to `require(d != 0 && (y == 0 || x <= type(uint256).max / y))`.
            if iszero(mul(or(iszero(x), eq(div(z, x), y)), d)) {
                mstore(0x00, 0xad251c27) // `MulDivFailed()`.
                revert(0x1c, 0x04)
            }
            z := div(z, d)
        }
    }

    /// @dev Returns `ceil(x * y / d)`.
    /// Reverts if `x * y` overflows, or `d` is zero.
    function mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            // Equivalent to `require(d != 0 && (y == 0 || x <= type(uint256).max / y))`.
            if iszero(mul(or(iszero(x), eq(div(z, x), y)), d)) {
                mstore(0x00, 0xad251c27) // `MulDivFailed()`.
                revert(0x1c, 0x04)
            }
            z := add(iszero(iszero(mod(z, d))), div(z, d))
        }
    }

    /// @dev Returns `x`, the modular multiplicative inverse of `a`, such that `(a * x) % n == 1`.
    function invMod(uint256 a, uint256 n) internal pure returns (uint256 x) {
        /// @solidity memory-safe-assembly
        assembly {
            let g := n
            let r := mod(a, n)
            for { let y := 1 } 1 {} {
                let q := div(g, r)
                let t := g
                g := r
                r := sub(t, mul(r, q))
                let u := x
                x := y
                y := sub(u, mul(y, q))
                if iszero(r) { break }
            }
            x := mul(eq(g, 1), add(x, mul(slt(x, 0), n)))
        }
    }

    /// @dev Returns `ceil(x / d)`.
    /// Reverts if `d` is zero.
    function divUp(uint256 x, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(d) {
                mstore(0x00, 0x65244e4e) // `DivFailed()`.
                revert(0x1c, 0x04)
            }
            z := add(iszero(iszero(mod(x, d))), div(x, d))
        }
    }

    /// @dev Returns `max(0, x - y)`. Alias for `saturatingSub`.
    function zeroFloorSub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(gt(x, y), sub(x, y))
        }
    }

    /// @dev Returns `max(0, x - y)`.
    function saturatingSub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(gt(x, y), sub(x, y))
        }
    }

    /// @dev Returns `min(2 ** 256 - 1, x + y)`.
    function saturatingAdd(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := or(sub(0, lt(add(x, y), x)), add(x, y))
        }
    }

    /// @dev Returns `min(2 ** 256 - 1, x * y)`.
    function saturatingMul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := or(sub(or(iszero(x), eq(div(mul(x, y), x), y)), 1), mul(x, y))
        }
    }

    /// @dev Returns `condition ? x : y`, without branching.
    function ternary(bool condition, uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), iszero(condition)))
        }
    }

    /// @dev Returns `condition ? x : y`, without branching.
    function ternary(bool condition, bytes32 x, bytes32 y) internal pure returns (bytes32 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), iszero(condition)))
        }
    }

    /// @dev Returns `condition ? x : y`, without branching.
    function ternary(bool condition, address x, address y) internal pure returns (address z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), iszero(condition)))
        }
    }

    /// @dev Returns `x != 0 ? x : y`, without branching.
    function coalesce(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := or(x, mul(y, iszero(x)))
        }
    }

    /// @dev Returns `x != bytes32(0) ? x : y`, without branching.
    function coalesce(bytes32 x, bytes32 y) internal pure returns (bytes32 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := or(x, mul(y, iszero(x)))
        }
    }

    /// @dev Returns `x != address(0) ? x : y`, without branching.
    function coalesce(address x, address y) internal pure returns (address z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := or(x, mul(y, iszero(shl(96, x))))
        }
    }

    /// @dev Exponentiate `x` to `y` by squaring, denominated in base `b`.
    /// Reverts if the computation overflows.
    function rpow(uint256 x, uint256 y, uint256 b) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(b, iszero(y)) // `0 ** 0 = 1`. Otherwise, `0 ** n = 0`.
            if x {
                z := xor(b, mul(xor(b, x), and(y, 1))) // `z = isEven(y) ? scale : x`
                let half := shr(1, b) // Divide `b` by 2.
                // Divide `y` by 2 every iteration.
                for { y := shr(1, y) } y { y := shr(1, y) } {
                    let xx := mul(x, x) // Store x squared.
                    let xxRound := add(xx, half) // Round to the nearest number.
                    // Revert if `xx + half` overflowed, or if `x ** 2` overflows.
                    if or(lt(xxRound, xx), shr(128, x)) {
                        mstore(0x00, 0x49f7642b) // `RPowOverflow()`.
                        revert(0x1c, 0x04)
                    }
                    x := div(xxRound, b) // Set `x` to scaled `xxRound`.
                    // If `y` is odd:
                    if and(y, 1) {
                        let zx := mul(z, x) // Compute `z * x`.
                        let zxRound := add(zx, half) // Round to the nearest number.
                        // If `z * x` overflowed or `zx + half` overflowed:
                        if or(xor(div(zx, x), z), lt(zxRound, zx)) {
                            // Revert if `x` is non-zero.
                            if x {
                                mstore(0x00, 0x49f7642b) // `RPowOverflow()`.
                                revert(0x1c, 0x04)
                            }
                        }
                        z := div(zxRound, b) // Return properly scaled `zxRound`.
                    }
                }
            }
        }
    }

    /// @dev Returns the square root of `x`, rounded down.
    function sqrt(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // `floor(sqrt(2**15)) = 181`. `sqrt(2**15) - 181 = 2.84`.
            z := 181 // The "correct" value is 1, but this saves a multiplication later.

            // This segment is to get a reasonable initial estimate for the Babylonian method. With a bad
            // start, the correct # of bits increases ~linearly each iteration instead of ~quadratically.

            // Let `y = x / 2**r`. We check `y >= 2**(k + 8)`
            // but shift right by `k` bits to ensure that if `x >= 256`, then `y >= 256`.
            let r := shl(7, lt(0xffffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffffff, shr(r, x))))
            z := shl(shr(1, r), z)

            // Goal was to get `z*z*y` within a small factor of `x`. More iterations could
            // get y in a tighter range. Currently, we will have y in `[256, 256*(2**16))`.
            // We ensured `y >= 256` so that the relative difference between `y` and `y+1` is small.
            // That's not possible if `x < 256` but we can just verify those cases exhaustively.

            // Now, `z*z*y <= x < z*z*(y+1)`, and `y <= 2**(16+8)`, and either `y >= 256`, or `x < 256`.
            // Correctness can be checked exhaustively for `x < 256`, so we assume `y >= 256`.
            // Then `z*sqrt(y)` is within `sqrt(257)/sqrt(256)` of `sqrt(x)`, or about 20bps.

            // For `s` in the range `[1/256, 256]`, the estimate `f(s) = (181/1024) * (s+1)`
            // is in the range `(1/2.84 * sqrt(s), 2.84 * sqrt(s))`,
            // with largest error when `s = 1` and when `s = 256` or `1/256`.

            // Since `y` is in `[256, 256*(2**16))`, let `a = y/65536`, so that `a` is in `[1/256, 256)`.
            // Then we can estimate `sqrt(y)` using
            // `sqrt(65536) * 181/1024 * (a + 1) = 181/4 * (y + 65536)/65536 = 181 * (y + 65536)/2**18`.

            // There is no overflow risk here since `y < 2**136` after the first branch above.
            z := shr(18, mul(z, add(shr(r, x), 65536))) // A `mul()` is saved from starting `z` at 181.

            // Given the worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // If `x+1` is a perfect square, the Babylonian method cycles between
            // `floor(sqrt(x))` and `ceil(sqrt(x))`. This statement ensures we return floor.
            // See: https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            z := sub(z, lt(div(x, z), z))
        }
    }

    /// @dev Returns the cube root of `x`, rounded down.
    /// Credit to bout3fiddy and pcaversaccio under AGPLv3 license:
    /// https://github.com/pcaversaccio/snekmate/blob/main/src/snekmate/utils/math.vy
    /// Formally verified by xuwinnie:
    /// https://github.com/vectorized/solady/blob/main/audits/xuwinnie-solady-cbrt-proof.pdf
    function cbrt(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            let r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            // Makeshift lookup table to nudge the approximate log2 result.
            z := div(shl(div(r, 3), shl(lt(0xf, shr(r, x)), 0xf)), xor(7, mod(r, 3)))
            // Newton-Raphson's.
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            // Round down.
            z := sub(z, lt(div(x, mul(z, z)), z))
        }
    }

    /// @dev Returns the square root of `x`, denominated in `WAD`, rounded down.
    function sqrtWad(uint256 x) internal pure returns (uint256 z) {
        unchecked {
            if (x <= type(uint256).max / 10 ** 18) return sqrt(x * 10 ** 18);
            z = (1 + sqrt(x)) * 10 ** 9;
            z = (fullMulDivUnchecked(x, 10 ** 18, z) + z) >> 1;
        }
        /// @solidity memory-safe-assembly
        assembly {
            z := sub(z, gt(999999999999999999, sub(mulmod(z, z, x), 1))) // Round down.
        }
    }

    /// @dev Returns the cube root of `x`, denominated in `WAD`, rounded down.
    /// Formally verified by xuwinnie:
    /// https://github.com/vectorized/solady/blob/main/audits/xuwinnie-solady-cbrt-proof.pdf
    function cbrtWad(uint256 x) internal pure returns (uint256 z) {
        unchecked {
            if (x <= type(uint256).max / 10 ** 36) return cbrt(x * 10 ** 36);
            z = (1 + cbrt(x)) * 10 ** 12;
            z = (fullMulDivUnchecked(x, 10 ** 36, z * z) + z + z) / 3;
        }
        /// @solidity memory-safe-assembly
        assembly {
            let p := x
            for {} 1 {} {
                if iszero(shr(229, p)) {
                    if iszero(shr(199, p)) {
                        p := mul(p, 100000000000000000) // 10 ** 17.
                        break
                    }
                    p := mul(p, 100000000) // 10 ** 8.
                    break
                }
                if iszero(shr(249, p)) { p := mul(p, 100) }
                break
            }
            let t := mulmod(mul(z, z), z, p)
            z := sub(z, gt(lt(t, shr(1, p)), iszero(t))) // Round down.
        }
    }

    /// @dev Returns the factorial of `x`.
    function factorial(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := 1
            if iszero(lt(x, 58)) {
                mstore(0x00, 0xaba0f2a2) // `FactorialOverflow()`.
                revert(0x1c, 0x04)
            }
            for {} x { x := sub(x, 1) } { z := mul(z, x) }
        }
    }

    /// @dev Returns the log2 of `x`.
    /// Equivalent to computing the index of the most significant bit (MSB) of `x`.
    /// Returns 0 if `x` is zero.
    function log2(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            // forgefmt: disable-next-item
            r := or(r, byte(and(0x1f, shr(shr(r, x), 0x8421084210842108cc6318c6db6d54be)),
                0x0706060506020504060203020504030106050205030304010505030400000000))
        }
    }

    /// @dev Returns the log2 of `x`, rounded up.
    /// Returns 0 if `x` is zero.
    function log2Up(uint256 x) internal pure returns (uint256 r) {
        r = log2(x);
        /// @solidity memory-safe-assembly
        assembly {
            r := add(r, lt(shl(r, 1), x))
        }
    }

    /// @dev Returns the log10 of `x`.
    /// Returns 0 if `x` is zero.
    function log10(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(lt(x, 100000000000000000000000000000000000000)) {
                x := div(x, 100000000000000000000000000000000000000)
                r := 38
            }
            if iszero(lt(x, 100000000000000000000)) {
                x := div(x, 100000000000000000000)
                r := add(r, 20)
            }
            if iszero(lt(x, 10000000000)) {
                x := div(x, 10000000000)
                r := add(r, 10)
            }
            if iszero(lt(x, 100000)) {
                x := div(x, 100000)
                r := add(r, 5)
            }
            r := add(r, add(gt(x, 9), add(gt(x, 99), add(gt(x, 999), gt(x, 9999)))))
        }
    }

    /// @dev Returns the log10 of `x`, rounded up.
    /// Returns 0 if `x` is zero.
    function log10Up(uint256 x) internal pure returns (uint256 r) {
        r = log10(x);
        /// @solidity memory-safe-assembly
        assembly {
            r := add(r, lt(exp(10, r), x))
        }
    }

    /// @dev Returns the log256 of `x`.
    /// Returns 0 if `x` is zero.
    function log256(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(shr(3, r), lt(0xff, shr(r, x)))
        }
    }

    /// @dev Returns the log256 of `x`, rounded up.
    /// Returns 0 if `x` is zero.
    function log256Up(uint256 x) internal pure returns (uint256 r) {
        r = log256(x);
        /// @solidity memory-safe-assembly
        assembly {
            r := add(r, lt(shl(shl(3, r), 1), x))
        }
    }

    /// @dev Returns the scientific notation format `mantissa * 10 ** exponent` of `x`.
    /// Useful for compressing prices (e.g. using 25 bit mantissa and 7 bit exponent).
    function sci(uint256 x) internal pure returns (uint256 mantissa, uint256 exponent) {
        /// @solidity memory-safe-assembly
        assembly {
            mantissa := x
            if mantissa {
                if iszero(mod(mantissa, 1000000000000000000000000000000000)) {
                    mantissa := div(mantissa, 1000000000000000000000000000000000)
                    exponent := 33
                }
                if iszero(mod(mantissa, 10000000000000000000)) {
                    mantissa := div(mantissa, 10000000000000000000)
                    exponent := add(exponent, 19)
                }
                if iszero(mod(mantissa, 1000000000000)) {
                    mantissa := div(mantissa, 1000000000000)
                    exponent := add(exponent, 12)
                }
                if iszero(mod(mantissa, 1000000)) {
                    mantissa := div(mantissa, 1000000)
                    exponent := add(exponent, 6)
                }
                if iszero(mod(mantissa, 10000)) {
                    mantissa := div(mantissa, 10000)
                    exponent := add(exponent, 4)
                }
                if iszero(mod(mantissa, 100)) {
                    mantissa := div(mantissa, 100)
                    exponent := add(exponent, 2)
                }
                if iszero(mod(mantissa, 10)) {
                    mantissa := div(mantissa, 10)
                    exponent := add(exponent, 1)
                }
            }
        }
    }

    /// @dev Convenience function for packing `x` into a smaller number using `sci`.
    /// The `mantissa` will be in bits [7..255] (the upper 249 bits).
    /// The `exponent` will be in bits [0..6] (the lower 7 bits).
    /// Use `SafeCastLib` to safely ensure that the `packed` number is small
    /// enough to fit in the desired unsigned integer type:
    /// ```
    ///     uint32 packed = SafeCastLib.toUint32(FixedPointMathLib.packSci(777 ether));
    /// ```
    function packSci(uint256 x) internal pure returns (uint256 packed) {
        (x, packed) = sci(x); // Reuse for `mantissa` and `exponent`.
        /// @solidity memory-safe-assembly
        assembly {
            if shr(249, x) {
                mstore(0x00, 0xce30380c) // `MantissaOverflow()`.
                revert(0x1c, 0x04)
            }
            packed := or(shl(7, x), packed)
        }
    }

    /// @dev Convenience function for unpacking a packed number from `packSci`.
    function unpackSci(uint256 packed) internal pure returns (uint256 unpacked) {
        unchecked {
            unpacked = (packed >> 7) * 10 ** (packed & 0x7f);
        }
    }

    /// @dev Returns the average of `x` and `y`. Rounds towards zero.
    function avg(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = (x & y) + ((x ^ y) >> 1);
        }
    }

    /// @dev Returns the average of `x` and `y`. Rounds towards negative infinity.
    function avg(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            z = (x >> 1) + (y >> 1) + (x & y & 1);
        }
    }

    /// @dev Returns the absolute value of `x`.
    function abs(int256 x) internal pure returns (uint256 z) {
        unchecked {
            z = (uint256(x) + uint256(x >> 255)) ^ uint256(x >> 255);
        }
    }

    /// @dev Returns the absolute distance between `x` and `y`.
    function dist(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := add(xor(sub(0, gt(x, y)), sub(y, x)), gt(x, y))
        }
    }

    /// @dev Returns the absolute distance between `x` and `y`.
    function dist(int256 x, int256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := add(xor(sub(0, sgt(x, y)), sub(y, x)), sgt(x, y))
        }
    }

    /// @dev Returns the minimum of `x` and `y`.
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), lt(y, x)))
        }
    }

    /// @dev Returns the minimum of `x` and `y`.
    function min(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), slt(y, x)))
        }
    }

    /// @dev Returns the maximum of `x` and `y`.
    function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), gt(y, x)))
        }
    }

    /// @dev Returns the maximum of `x` and `y`.
    function max(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), sgt(y, x)))
        }
    }

    /// @dev Returns `x`, bounded to `minValue` and `maxValue`.
    function clamp(uint256 x, uint256 minValue, uint256 maxValue)
        internal
        pure
        returns (uint256 z)
    {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, minValue), gt(minValue, x)))
            z := xor(z, mul(xor(z, maxValue), lt(maxValue, z)))
        }
    }

    /// @dev Returns `x`, bounded to `minValue` and `maxValue`.
    function clamp(int256 x, int256 minValue, int256 maxValue) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, minValue), sgt(minValue, x)))
            z := xor(z, mul(xor(z, maxValue), slt(maxValue, z)))
        }
    }

    /// @dev Returns greatest common divisor of `x` and `y`.
    function gcd(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            for { z := x } y {} {
                let t := y
                y := mod(z, y)
                z := t
            }
        }
    }

    /// @dev Returns `a + (b - a) * (t - begin) / (end - begin)`,
    /// with `t` clamped between `begin` and `end` (inclusive).
    /// Agnostic to the order of (`a`, `b`) and (`end`, `begin`).
    /// If `begins == end`, returns `t <= begin ? a : b`.
    function lerp(uint256 a, uint256 b, uint256 t, uint256 begin, uint256 end)
        internal
        pure
        returns (uint256)
    {
        if (begin > end) (t, begin, end) = (~t, ~begin, ~end);
        if (t <= begin) return a;
        if (t >= end) return b;
        unchecked {
            if (b >= a) return a + fullMulDiv(b - a, t - begin, end - begin);
            return a - fullMulDiv(a - b, t - begin, end - begin);
        }
    }

    /// @dev Returns `a + (b - a) * (t - begin) / (end - begin)`.
    /// with `t` clamped between `begin` and `end` (inclusive).
    /// Agnostic to the order of (`a`, `b`) and (`end`, `begin`).
    /// If `begins == end`, returns `t <= begin ? a : b`.
    function lerp(int256 a, int256 b, int256 t, int256 begin, int256 end)
        internal
        pure
        returns (int256)
    {
        if (begin > end) (t, begin, end) = (~t, ~begin, ~end);
        if (t <= begin) return a;
        if (t >= end) return b;
        // forgefmt: disable-next-item
        unchecked {
            if (b >= a) return int256(uint256(a) + fullMulDiv(uint256(b - a),
                uint256(t - begin), uint256(end - begin)));
            return int256(uint256(a) - fullMulDiv(uint256(a - b),
                uint256(t - begin), uint256(end - begin)));
        }
    }

    /// @dev Returns if `x` is an even number. Some people may need this.
    function isEven(uint256 x) internal pure returns (bool) {
        return x & uint256(1) == uint256(0);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   RAW NUMBER OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns `x + y`, without checking for overflow.
    function rawAdd(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x + y;
        }
    }

    /// @dev Returns `x + y`, without checking for overflow.
    function rawAdd(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            z = x + y;
        }
    }

    /// @dev Returns `x - y`, without checking for underflow.
    function rawSub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x - y;
        }
    }

    /// @dev Returns `x - y`, without checking for underflow.
    function rawSub(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            z = x - y;
        }
    }

    /// @dev Returns `x * y`, without checking for overflow.
    function rawMul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x * y;
        }
    }

    /// @dev Returns `x * y`, without checking for overflow.
    function rawMul(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            z = x * y;
        }
    }

    /// @dev Returns `x / y`, returning 0 if `y` is zero.
    function rawDiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := div(x, y)
        }
    }

    /// @dev Returns `x / y`, returning 0 if `y` is zero.
    function rawSDiv(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := sdiv(x, y)
        }
    }

    /// @dev Returns `x % y`, returning 0 if `y` is zero.
    function rawMod(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mod(x, y)
        }
    }

    /// @dev Returns `x % y`, returning 0 if `y` is zero.
    function rawSMod(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := smod(x, y)
        }
    }

    /// @dev Returns `(x + y) % d`, return 0 if `d` if zero.
    function rawAddMod(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := addmod(x, y, d)
        }
    }

    /// @dev Returns `(x * y) % d`, return 0 if `d` if zero.
    function rawMulMod(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mulmod(x, y, d)
        }
    }
}

// src/interfaces/external/IDistributionContract.sol

/// @title IDistributionContract
/// @notice Interface for token distribution contracts.
interface IDistributionContract {
    /// @notice Notify a distribution contract that it has received the tokens to distribute
    function onTokensReceived() external;
}

// lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/introspection/IERC165.sol)

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// src/interfaces/external/IERC20Minimal.sol

/// @notice Minimal ERC20 interface
interface IERC20Minimal {
    /// @notice Returns an account's balance in the token
    /// @param account The account for which to look up the number of tokens it has, i.e. its balance
    /// @return The number of tokens held by the account
    function balanceOf(address account) external view returns (uint256);

    /// @notice Transfers the amount of token from the `msg.sender` to the recipient
    /// @param recipient The account that will receive the amount transferred
    /// @param amount The number of tokens to send from the sender to the recipient
    /// @return Returns true for a successful transfer, false for an unsuccessful transfer
    function transfer(address recipient, uint256 amount) external returns (bool);

    /// @notice Approves the spender to spend the amount of tokens from the `msg.sender`
    /// @param spender The account that will be allowed to spend the amount
    /// @param amount The number of tokens to allow the spender to spend
    /// @return Returns true for a successful approval, false for an unsuccessful approval
    function approve(address spender, uint256 amount) external returns (bool);
}

// src/interfaces/ITickStorage.sol

/// @notice Each tick contains a pointer to the next price in the linked list
///         and the cumulative currency demand at the tick's price level
struct Tick {
    uint256 next;
    uint256 currencyDemandQ96;
}

/// @title ITickStorage
/// @notice Interface for the TickStorage contract
interface ITickStorage {
    /// @notice Error thrown when the tick spacing is too small
    error TickSpacingTooSmall();
    /// @notice Error thrown when the floor price is zero
    error FloorPriceIsZero();
    /// @notice Error thrown when the floor price is below the minimum floor price
    error FloorPriceTooLow();
    /// @notice Error thrown when the previous price hint is invalid (higher than the new price)
    error TickPreviousPriceInvalid();
    /// @notice Error thrown when the tick price is not increasing
    error TickPriceNotIncreasing();
    /// @notice Error thrown when the tick is not initialized
    error TickNotInitialized();
    /// @notice Error thrown when the price is not at a boundary designated by the tick spacing
    error TickPriceNotAtBoundary();
    /// @notice Error thrown when the tick price is invalid
    error InvalidTickPrice();
    /// @notice Error thrown when trying to update the demand of an uninitialized tick
    error CannotUpdateUninitializedTick();

    /// @notice Emitted when a tick is initialized
    /// @param price The price of the tick
    event TickInitialized(uint256 price);

    /// @notice Emitted when the nextActiveTick is updated
    /// @param price The price of the tick
    event NextActiveTickUpdated(uint256 price);

    /// @notice The price of the next initialized tick above the clearing price
    /// @dev This will be equal to the clearingPrice if no ticks have been initialized yet
    /// @return The price of the next active tick
    function nextActiveTickPrice() external view returns (uint256);

    /// @notice Get the floor price of the auction
    /// @return The minimum price for bids
    function floorPrice() external view returns (uint256);

    /// @notice Get the tick spacing enforced for bid prices
    /// @return The tick spacing value
    function tickSpacing() external view returns (uint256);

    /// @notice Get a tick at a price
    /// @dev The returned tick is not guaranteed to be initialized
    /// @param price The price of the tick, which must be at a boundary designated by the tick spacing
    /// @return The tick at the given price
    function ticks(uint256 price) external view returns (Tick memory);
}

// src/interfaces/IValidationHook.sol

/// @notice Interface for custom bid validation logic
interface IValidationHook {
    /// @notice Validate a bid
    /// @dev MUST revert if the bid is invalid
    /// @param maxPrice The maximum price the bidder is willing to pay
    /// @param amount The amount of the bid
    /// @param owner The owner of the bid
    /// @param sender The sender of the bid
    /// @param hookData Additional data to pass to the hook required for validation
    function validate(uint256 maxPrice, uint128 amount, address owner, address sender, bytes calldata hookData) external;
}

// lib/solady/src/utils/ReentrancyGuardTransient.sol

/// @notice Reentrancy guard mixin (transient storage variant).
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/ReentrancyGuardTransient.sol)
///
/// @dev Note: This implementation utilizes the `TSTORE` and `TLOAD` opcodes.
/// Please ensure that the chain you are deploying on supports them.
abstract contract ReentrancyGuardTransient {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Unauthorized reentrant call.
    error Reentrancy();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Equivalent to: `uint32(bytes4(keccak256("Reentrancy()"))) | 1 << 71`.
    /// 9 bytes is large enough to avoid collisions in practice,
    /// but not too large to result in excessive bytecode bloat.
    uint256 private constant _REENTRANCY_GUARD_SLOT = 0x8000000000ab143c06;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      REENTRANCY GUARD                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Guards a function from reentrancy.
    modifier nonReentrant() virtual {
        if (_useTransientReentrancyGuardOnlyOnMainnet()) {
            uint256 s = _REENTRANCY_GUARD_SLOT;
            if (block.chainid == 1) {
                /// @solidity memory-safe-assembly
                assembly {
                    if tload(s) {
                        mstore(0x00, s) // `Reentrancy()`.
                        revert(0x1c, 0x04)
                    }
                    tstore(s, address())
                }
            } else {
                /// @solidity memory-safe-assembly
                assembly {
                    if eq(sload(s), address()) {
                        mstore(0x00, s) // `Reentrancy()`.
                        revert(0x1c, 0x04)
                    }
                    sstore(s, address())
                }
            }
        } else {
            /// @solidity memory-safe-assembly
            assembly {
                if tload(_REENTRANCY_GUARD_SLOT) {
                    mstore(0x00, 0xab143c06) // `Reentrancy()`.
                    revert(0x1c, 0x04)
                }
                tstore(_REENTRANCY_GUARD_SLOT, address())
            }
        }
        _;
        if (_useTransientReentrancyGuardOnlyOnMainnet()) {
            uint256 s = _REENTRANCY_GUARD_SLOT;
            if (block.chainid == 1) {
                /// @solidity memory-safe-assembly
                assembly {
                    tstore(s, 0)
                }
            } else {
                /// @solidity memory-safe-assembly
                assembly {
                    sstore(s, s)
                }
            }
        } else {
            /// @solidity memory-safe-assembly
            assembly {
                tstore(_REENTRANCY_GUARD_SLOT, 0)
            }
        }
    }

    /// @dev Guards a view function from read-only reentrancy.
    modifier nonReadReentrant() virtual {
        if (_useTransientReentrancyGuardOnlyOnMainnet()) {
            uint256 s = _REENTRANCY_GUARD_SLOT;
            if (block.chainid == 1) {
                /// @solidity memory-safe-assembly
                assembly {
                    if tload(s) {
                        mstore(0x00, s) // `Reentrancy()`.
                        revert(0x1c, 0x04)
                    }
                }
            } else {
                /// @solidity memory-safe-assembly
                assembly {
                    if eq(sload(s), address()) {
                        mstore(0x00, s) // `Reentrancy()`.
                        revert(0x1c, 0x04)
                    }
                }
            }
        } else {
            /// @solidity memory-safe-assembly
            assembly {
                if tload(_REENTRANCY_GUARD_SLOT) {
                    mstore(0x00, 0xab143c06) // `Reentrancy()`.
                    revert(0x1c, 0x04)
                }
            }
        }
        _;
    }

    /// @dev For widespread compatibility with L2s.
    /// Only Ethereum mainnet is expensive anyways.
    function _useTransientReentrancyGuardOnlyOnMainnet() internal view virtual returns (bool) {
        return true;
    }
}

// lib/solady/src/utils/SSTORE2.sol

/// @notice Read and write to persistent storage at a fraction of the cost.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/SSTORE2.sol)
/// @author Saw-mon-and-Natalie (https://github.com/Saw-mon-and-Natalie)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SSTORE2.sol)
/// @author Modified from 0xSequence (https://github.com/0xSequence/sstore2/blob/master/contracts/SSTORE2.sol)
/// @author Modified from SSTORE3 (https://github.com/Philogy/sstore3)
library SSTORE2 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The proxy initialization code.
    uint256 private constant _CREATE3_PROXY_INITCODE = 0x67363d3d37363d34f03d5260086018f3;

    /// @dev Hash of the `_CREATE3_PROXY_INITCODE`.
    /// Equivalent to `keccak256(abi.encodePacked(hex"67363d3d37363d34f03d5260086018f3"))`.
    bytes32 internal constant CREATE3_PROXY_INITCODE_HASH =
        0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CUSTOM ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Unable to deploy the storage contract.
    error DeploymentFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         WRITE LOGIC                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Writes `data` into the bytecode of a storage contract and returns its address.
    function write(bytes memory data) internal returns (address pointer) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(data) // Let `l` be `n + 1`. +1 as we prefix a STOP opcode.
            /**
             * ---------------------------------------------------+
             * Opcode | Mnemonic       | Stack     | Memory       |
             * ---------------------------------------------------|
             * 61 l   | PUSH2 l        | l         |              |
             * 80     | DUP1           | l l       |              |
             * 60 0xa | PUSH1 0xa      | 0xa l l   |              |
             * 3D     | RETURNDATASIZE | 0 0xa l l |              |
             * 39     | CODECOPY       | l         | [0..l): code |
             * 3D     | RETURNDATASIZE | 0 l       | [0..l): code |
             * F3     | RETURN         |           | [0..l): code |
             * 00     | STOP           |           |              |
             * ---------------------------------------------------+
             * @dev Prefix the bytecode with a STOP opcode to ensure it cannot be called.
             * Also PUSH2 is used since max contract size cap is 24,576 bytes which is less than 2 ** 16.
             */
            // Do a out-of-gas revert if `n + 1` is more than 2 bytes.
            mstore(add(data, gt(n, 0xfffe)), add(0xfe61000180600a3d393df300, shl(0x40, n)))
            // Deploy a new contract with the generated creation code.
            pointer := create(0, add(data, 0x15), add(n, 0xb))
            if iszero(pointer) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(data, n) // Restore the length of `data`.
        }
    }

    /// @dev Writes `data` into the bytecode of a storage contract with `salt`
    /// and returns its normal CREATE2 deterministic address.
    function writeCounterfactual(bytes memory data, bytes32 salt)
        internal
        returns (address pointer)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(data)
            // Do a out-of-gas revert if `n + 1` is more than 2 bytes.
            mstore(add(data, gt(n, 0xfffe)), add(0xfe61000180600a3d393df300, shl(0x40, n)))
            // Deploy a new contract with the generated creation code.
            pointer := create2(0, add(data, 0x15), add(n, 0xb), salt)
            if iszero(pointer) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(data, n) // Restore the length of `data`.
        }
    }

    /// @dev Writes `data` into the bytecode of a storage contract and returns its address.
    /// This uses the so-called "CREATE3" workflow,
    /// which means that `pointer` is agnostic to `data, and only depends on `salt`.
    function writeDeterministic(bytes memory data, bytes32 salt)
        internal
        returns (address pointer)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(data)
            mstore(0x00, _CREATE3_PROXY_INITCODE) // Store the `_PROXY_INITCODE`.
            let proxy := create2(0, 0x10, 0x10, salt)
            if iszero(proxy) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x14, proxy) // Store the proxy's address.
            // 0xd6 = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ proxy ++ 0x01).
            // 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex).
            mstore(0x00, 0xd694)
            mstore8(0x34, 0x01) // Nonce of the proxy contract (1).
            pointer := keccak256(0x1e, 0x17)

            // Do a out-of-gas revert if `n + 1` is more than 2 bytes.
            mstore(add(data, gt(n, 0xfffe)), add(0xfe61000180600a3d393df300, shl(0x40, n)))
            if iszero(
                mul( // The arguments of `mul` are evaluated last to first.
                    extcodesize(pointer),
                    call(gas(), proxy, 0, add(data, 0x15), add(n, 0xb), codesize(), 0x00)
                )
            ) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(data, n) // Restore the length of `data`.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    ADDRESS CALCULATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the initialization code hash of the storage contract for `data`.
    /// Used for mining vanity addresses with create2crunch.
    function initCodeHash(bytes memory data) internal pure returns (bytes32 hash) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(data)
            // Do a out-of-gas revert if `n + 1` is more than 2 bytes.
            returndatacopy(returndatasize(), returndatasize(), gt(n, 0xfffe))
            mstore(data, add(0x61000180600a3d393df300, shl(0x40, n)))
            hash := keccak256(add(data, 0x15), add(n, 0xb))
            mstore(data, n) // Restore the length of `data`.
        }
    }

    /// @dev Equivalent to `predictCounterfactualAddress(data, salt, address(this))`
    function predictCounterfactualAddress(bytes memory data, bytes32 salt)
        internal
        view
        returns (address pointer)
    {
        pointer = predictCounterfactualAddress(data, salt, address(this));
    }

    /// @dev Returns the CREATE2 address of the storage contract for `data`
    /// deployed with `salt` by `deployer`.
    /// Note: The returned result has dirty upper 96 bits. Please clean if used in assembly.
    function predictCounterfactualAddress(bytes memory data, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 hash = initCodeHash(data);
        /// @solidity memory-safe-assembly
        assembly {
            // Compute and store the bytecode hash.
            mstore8(0x00, 0xff) // Write the prefix.
            mstore(0x35, hash)
            mstore(0x01, shl(96, deployer))
            mstore(0x15, salt)
            predicted := keccak256(0x00, 0x55)
            // Restore the part of the free memory pointer that has been overwritten.
            mstore(0x35, 0)
        }
    }

    /// @dev Equivalent to `predictDeterministicAddress(salt, address(this))`.
    function predictDeterministicAddress(bytes32 salt) internal view returns (address pointer) {
        pointer = predictDeterministicAddress(salt, address(this));
    }

    /// @dev Returns the "CREATE3" deterministic address for `salt` with `deployer`.
    function predictDeterministicAddress(bytes32 salt, address deployer)
        internal
        pure
        returns (address pointer)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x00, deployer) // Store `deployer`.
            mstore8(0x0b, 0xff) // Store the prefix.
            mstore(0x20, salt) // Store the salt.
            mstore(0x40, CREATE3_PROXY_INITCODE_HASH) // Store the bytecode hash.

            mstore(0x14, keccak256(0x0b, 0x55)) // Store the proxy's address.
            mstore(0x40, m) // Restore the free memory pointer.
            // 0xd6 = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ proxy ++ 0x01).
            // 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex).
            mstore(0x00, 0xd694)
            mstore8(0x34, 0x01) // Nonce of the proxy contract (1).
            pointer := keccak256(0x1e, 0x17)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         READ LOGIC                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Equivalent to `read(pointer, 0, 2 ** 256 - 1)`.
    function read(address pointer) internal view returns (bytes memory data) {
        /// @solidity memory-safe-assembly
        assembly {
            data := mload(0x40)
            let n := and(0xffffffffff, sub(extcodesize(pointer), 0x01))
            extcodecopy(pointer, add(data, 0x1f), 0x00, add(n, 0x21))
            mstore(data, n) // Store the length.
            mstore(0x40, add(n, add(data, 0x40))) // Allocate memory.
        }
    }

    /// @dev Equivalent to `read(pointer, start, 2 ** 256 - 1)`.
    function read(address pointer, uint256 start) internal view returns (bytes memory data) {
        /// @solidity memory-safe-assembly
        assembly {
            data := mload(0x40)
            let n := and(0xffffffffff, sub(extcodesize(pointer), 0x01))
            let l := sub(n, and(0xffffff, mul(lt(start, n), start)))
            extcodecopy(pointer, add(data, 0x1f), start, add(l, 0x21))
            mstore(data, mul(sub(n, start), lt(start, n))) // Store the length.
            mstore(0x40, add(data, add(0x40, mload(data)))) // Allocate memory.
        }
    }

    /// @dev Returns a slice of the data on `pointer` from `start` to `end`.
    /// `start` and `end` will be clamped to the range `[0, args.length]`.
    /// The `pointer` MUST be deployed via the SSTORE2 write functions.
    /// Otherwise, the behavior is undefined.
    /// Out-of-gas reverts if `pointer` does not have any code.
    function read(address pointer, uint256 start, uint256 end)
        internal
        view
        returns (bytes memory data)
    {
        /// @solidity memory-safe-assembly
        assembly {
            data := mload(0x40)
            if iszero(lt(end, 0xffff)) { end := 0xffff }
            let d := mul(sub(end, start), lt(start, end))
            extcodecopy(pointer, add(data, 0x1f), start, add(d, 0x01))
            if iszero(and(0xff, mload(add(data, d)))) {
                let n := sub(extcodesize(pointer), 0x01)
                returndatacopy(returndatasize(), returndatasize(), shr(40, n))
                d := mul(gt(n, start), sub(d, mul(gt(end, n), sub(end, n))))
            }
            mstore(data, d) // Store the length.
            mstore(add(add(data, 0x20), d), 0) // Zeroize the slot after the bytes.
            mstore(0x40, add(add(data, 0x40), d)) // Allocate memory.
        }
    }
}

// lib/solady/src/utils/SafeTransferLib.sol

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/SafeTransferLib.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @author Permit2 operations from (https://github.com/Uniswap/permit2/blob/main/src/libraries/Permit2Lib.sol)
///
/// @dev Note:
/// - For ETH transfers, please use `forceSafeTransferETH` for DoS protection.
library SafeTransferLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The ETH transfer has failed.
    error ETHTransferFailed();

    /// @dev The ERC20 `transferFrom` has failed.
    error TransferFromFailed();

    /// @dev The ERC20 `transfer` has failed.
    error TransferFailed();

    /// @dev The ERC20 `approve` has failed.
    error ApproveFailed();

    /// @dev The ERC20 `totalSupply` query has failed.
    error TotalSupplyQueryFailed();

    /// @dev The Permit2 operation has failed.
    error Permit2Failed();

    /// @dev The Permit2 amount must be less than `2**160 - 1`.
    error Permit2AmountOverflow();

    /// @dev The Permit2 approve operation has failed.
    error Permit2ApproveFailed();

    /// @dev The Permit2 lockdown operation has failed.
    error Permit2LockdownFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Suggested gas stipend for contract receiving ETH that disallows any storage writes.
    uint256 internal constant GAS_STIPEND_NO_STORAGE_WRITES = 2300;

    /// @dev Suggested gas stipend for contract receiving ETH to perform a few
    /// storage reads and writes, but low enough to prevent griefing.
    uint256 internal constant GAS_STIPEND_NO_GRIEF = 100000;

    /// @dev The unique EIP-712 domain separator for the DAI token contract.
    bytes32 internal constant DAI_DOMAIN_SEPARATOR =
        0xdbb8cf42e1ecb028be3f3dbc922e1d878b963f411dc388ced501601c60f7c6f7;

    /// @dev The address for the WETH9 contract on Ethereum mainnet.
    address internal constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @dev The canonical Permit2 address.
    /// [Github](https://github.com/Uniswap/permit2)
    /// [Etherscan](https://etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ETH OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // If the ETH transfer MUST succeed with a reasonable gas budget, use the force variants.
    //
    // The regular variants:
    // - Forwards all remaining gas to the target.
    // - Reverts if the target reverts.
    // - Reverts if the current contract has insufficient balance.
    //
    // The force variants:
    // - Forwards with an optional gas stipend
    //   (defaults to `GAS_STIPEND_NO_GRIEF`, which is sufficient for most cases).
    // - If the target reverts, or if the gas stipend is exhausted,
    //   creates a temporary contract to force send the ETH via `SELFDESTRUCT`.
    //   Future compatible with `SENDALL`: https://eips.ethereum.org/EIPS/eip-4758.
    // - Reverts if the current contract has insufficient balance.
    //
    // The try variants:
    // - Forwards with a mandatory gas stipend.
    // - Instead of reverting, returns whether the transfer succeeded.

    /// @dev Sends `amount` (in wei) ETH to `to`.
    function safeTransferETH(address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(call(gas(), to, amount, codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Sends all the ETH in the current contract to `to`.
    function safeTransferAllETH(address to) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // Transfer all the ETH and check if it succeeded or not.
            if iszero(call(gas(), to, selfbalance(), codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Force sends `amount` (in wei) ETH to `to`, with a `gasStipend`.
    function forceSafeTransferETH(address to, uint256 amount, uint256 gasStipend) internal {
        /// @solidity memory-safe-assembly
        assembly {
            if lt(selfbalance(), amount) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
            if iszero(call(gasStipend, to, amount, codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                if iszero(create(amount, 0x0b, 0x16)) { revert(codesize(), codesize()) } // For gas estimation.
            }
        }
    }

    /// @dev Force sends all the ETH in the current contract to `to`, with a `gasStipend`.
    function forceSafeTransferAllETH(address to, uint256 gasStipend) internal {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(call(gasStipend, to, selfbalance(), codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                if iszero(create(selfbalance(), 0x0b, 0x16)) { revert(codesize(), codesize()) } // For gas estimation.
            }
        }
    }

    /// @dev Force sends `amount` (in wei) ETH to `to`, with `GAS_STIPEND_NO_GRIEF`.
    function forceSafeTransferETH(address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            if lt(selfbalance(), amount) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
            if iszero(call(GAS_STIPEND_NO_GRIEF, to, amount, codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                if iszero(create(amount, 0x0b, 0x16)) { revert(codesize(), codesize()) } // For gas estimation.
            }
        }
    }

    /// @dev Force sends all the ETH in the current contract to `to`, with `GAS_STIPEND_NO_GRIEF`.
    function forceSafeTransferAllETH(address to) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // forgefmt: disable-next-item
            if iszero(call(GAS_STIPEND_NO_GRIEF, to, selfbalance(), codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                if iszero(create(selfbalance(), 0x0b, 0x16)) { revert(codesize(), codesize()) } // For gas estimation.
            }
        }
    }

    /// @dev Sends `amount` (in wei) ETH to `to`, with a `gasStipend`.
    function trySafeTransferETH(address to, uint256 amount, uint256 gasStipend)
        internal
        returns (bool success)
    {
        /// @solidity memory-safe-assembly
        assembly {
            success := call(gasStipend, to, amount, codesize(), 0x00, codesize(), 0x00)
        }
    }

    /// @dev Sends all the ETH in the current contract to `to`, with a `gasStipend`.
    function trySafeTransferAllETH(address to, uint256 gasStipend)
        internal
        returns (bool success)
    {
        /// @solidity memory-safe-assembly
        assembly {
            success := call(gasStipend, to, selfbalance(), codesize(), 0x00, codesize(), 0x00)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ERC20 OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Sends `amount` of ERC20 `token` from `from` to `to`.
    /// Reverts upon failure.
    ///
    /// The `from` account must have at least `amount` approved for
    /// the current contract to manage.
    function safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, amount) // Store the `amount` argument.
            mstore(0x40, to) // Store the `to` argument.
            mstore(0x2c, shl(96, from)) // Store the `from` argument.
            mstore(0x0c, 0x23b872dd000000000000000000000000) // `transferFrom(address,address,uint256)`.
            let success := call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
            if iszero(and(eq(mload(0x00), 1), success)) {
                if iszero(lt(or(iszero(extcodesize(token)), returndatasize()), success)) {
                    mstore(0x00, 0x7939f424) // `TransferFromFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Sends `amount` of ERC20 `token` from `from` to `to`.
    ///
    /// The `from` account must have at least `amount` approved for the current contract to manage.
    function trySafeTransferFrom(address token, address from, address to, uint256 amount)
        internal
        returns (bool success)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, amount) // Store the `amount` argument.
            mstore(0x40, to) // Store the `to` argument.
            mstore(0x2c, shl(96, from)) // Store the `from` argument.
            mstore(0x0c, 0x23b872dd000000000000000000000000) // `transferFrom(address,address,uint256)`.
            success := call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
            if iszero(and(eq(mload(0x00), 1), success)) {
                success := lt(or(iszero(extcodesize(token)), returndatasize()), success)
            }
            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Sends all of ERC20 `token` from `from` to `to`.
    /// Reverts upon failure.
    ///
    /// The `from` account must have their entire balance approved for the current contract to manage.
    function safeTransferAllFrom(address token, address from, address to)
        internal
        returns (uint256 amount)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x40, to) // Store the `to` argument.
            mstore(0x2c, shl(96, from)) // Store the `from` argument.
            mstore(0x0c, 0x70a08231000000000000000000000000) // `balanceOf(address)`.
            // Read the balance, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                    staticcall(gas(), token, 0x1c, 0x24, 0x60, 0x20)
                )
            ) {
                mstore(0x00, 0x7939f424) // `TransferFromFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x00, 0x23b872dd) // `transferFrom(address,address,uint256)`.
            amount := mload(0x60) // The `amount` is already at 0x60. We'll need to return it.
            // Perform the transfer, reverting upon failure.
            let success := call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
            if iszero(and(eq(mload(0x00), 1), success)) {
                if iszero(lt(or(iszero(extcodesize(token)), returndatasize()), success)) {
                    mstore(0x00, 0x7939f424) // `TransferFromFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Sends `amount` of ERC20 `token` from the current contract to `to`.
    /// Reverts upon failure.
    function safeTransfer(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0xa9059cbb000000000000000000000000) // `transfer(address,uint256)`.
            // Perform the transfer, reverting upon failure.
            let success := call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
            if iszero(and(eq(mload(0x00), 1), success)) {
                if iszero(lt(or(iszero(extcodesize(token)), returndatasize()), success)) {
                    mstore(0x00, 0x90b8ec18) // `TransferFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Sends all of ERC20 `token` from the current contract to `to`.
    /// Reverts upon failure.
    function safeTransferAll(address token, address to) internal returns (uint256 amount) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, 0x70a08231) // Store the function selector of `balanceOf(address)`.
            mstore(0x20, address()) // Store the address of the current contract.
            // Read the balance, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                    staticcall(gas(), token, 0x1c, 0x24, 0x34, 0x20)
                )
            ) {
                mstore(0x00, 0x90b8ec18) // `TransferFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x14, to) // Store the `to` argument.
            amount := mload(0x34) // The `amount` is already at 0x34. We'll need to return it.
            mstore(0x00, 0xa9059cbb000000000000000000000000) // `transfer(address,uint256)`.
            // Perform the transfer, reverting upon failure.
            let success := call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
            if iszero(and(eq(mload(0x00), 1), success)) {
                if iszero(lt(or(iszero(extcodesize(token)), returndatasize()), success)) {
                    mstore(0x00, 0x90b8ec18) // `TransferFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Sets `amount` of ERC20 `token` for `to` to manage on behalf of the current contract.
    /// Reverts upon failure.
    function safeApprove(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0x095ea7b3000000000000000000000000) // `approve(address,uint256)`.
            let success := call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
            if iszero(and(eq(mload(0x00), 1), success)) {
                if iszero(lt(or(iszero(extcodesize(token)), returndatasize()), success)) {
                    mstore(0x00, 0x3e3f8f73) // `ApproveFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Sets `amount` of ERC20 `token` for `to` to manage on behalf of the current contract.
    /// If the initial attempt to approve fails, attempts to reset the approved amount to zero,
    /// then retries the approval again (some tokens, e.g. USDT, requires this).
    /// Reverts upon failure.
    function safeApproveWithRetry(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0x095ea7b3000000000000000000000000) // `approve(address,uint256)`.
            // Perform the approval, retrying upon failure.
            let success := call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
            if iszero(and(eq(mload(0x00), 1), success)) {
                if iszero(lt(or(iszero(extcodesize(token)), returndatasize()), success)) {
                    mstore(0x34, 0) // Store 0 for the `amount`.
                    mstore(0x00, 0x095ea7b3000000000000000000000000) // `approve(address,uint256)`.
                    pop(call(gas(), token, 0, 0x10, 0x44, codesize(), 0x00)) // Reset the approval.
                    mstore(0x34, amount) // Store back the original `amount`.
                    // Retry the approval, reverting upon failure.
                    success := call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                    if iszero(and(eq(mload(0x00), 1), success)) {
                        // Check the `extcodesize` again just in case the token selfdestructs lol.
                        if iszero(lt(or(iszero(extcodesize(token)), returndatasize()), success)) {
                            mstore(0x00, 0x3e3f8f73) // `ApproveFailed()`.
                            revert(0x1c, 0x04)
                        }
                    }
                }
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Returns the amount of ERC20 `token` owned by `account`.
    /// Returns zero if the `token` does not exist.
    function balanceOf(address token, address account) internal view returns (uint256 amount) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, account) // Store the `account` argument.
            mstore(0x00, 0x70a08231000000000000000000000000) // `balanceOf(address)`.
            amount :=
                mul( // The arguments of `mul` are evaluated from right to left.
                    mload(0x20),
                    and( // The arguments of `and` are evaluated from right to left.
                        gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                        staticcall(gas(), token, 0x10, 0x24, 0x20, 0x20)
                    )
                )
        }
    }

    /// @dev Performs a `token.balanceOf(account)` check.
    /// `implemented` denotes whether the `token` does not implement `balanceOf`.
    /// `amount` is zero if the `token` does not implement `balanceOf`.
    function checkBalanceOf(address token, address account)
        internal
        view
        returns (bool implemented, uint256 amount)
    {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, account) // Store the `account` argument.
            mstore(0x00, 0x70a08231000000000000000000000000) // `balanceOf(address)`.
            implemented :=
                and( // The arguments of `and` are evaluated from right to left.
                    gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                    staticcall(gas(), token, 0x10, 0x24, 0x20, 0x20)
                )
            amount := mul(mload(0x20), implemented)
        }
    }

    /// @dev Returns the total supply of the `token`.
    /// Reverts if the token does not exist or does not implement `totalSupply()`.
    function totalSupply(address token) internal view returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, 0x18160ddd) // `totalSupply()`.
            if iszero(
                and(gt(returndatasize(), 0x1f), staticcall(gas(), token, 0x1c, 0x04, 0x00, 0x20))
            ) {
                mstore(0x00, 0x54cd9435) // `TotalSupplyQueryFailed()`.
                revert(0x1c, 0x04)
            }
            result := mload(0x00)
        }
    }

    /// @dev Sends `amount` of ERC20 `token` from `from` to `to`.
    /// If the initial attempt fails, try to use Permit2 to transfer the token.
    /// Reverts upon failure.
    ///
    /// The `from` account must have at least `amount` approved for the current contract to manage.
    function safeTransferFrom2(address token, address from, address to, uint256 amount) internal {
        if (!trySafeTransferFrom(token, from, to, amount)) {
            permit2TransferFrom(token, from, to, amount);
        }
    }

    /// @dev Sends `amount` of ERC20 `token` from `from` to `to` via Permit2.
    /// Reverts upon failure.
    function permit2TransferFrom(address token, address from, address to, uint256 amount)
        internal
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(add(m, 0x74), shr(96, shl(96, token)))
            mstore(add(m, 0x54), amount)
            mstore(add(m, 0x34), to)
            mstore(add(m, 0x20), shl(96, from))
            // `transferFrom(address,address,uint160,address)`.
            mstore(m, 0x36c78516000000000000000000000000)
            let p := PERMIT2
            let exists := eq(chainid(), 1)
            if iszero(exists) { exists := iszero(iszero(extcodesize(p))) }
            if iszero(
                and(
                    call(gas(), p, 0, add(m, 0x10), 0x84, codesize(), 0x00),
                    lt(iszero(extcodesize(token)), exists) // Token has code and Permit2 exists.
                )
            ) {
                mstore(0x00, 0x7939f4248757f0fd) // `TransferFromFailed()` or `Permit2AmountOverflow()`.
                revert(add(0x18, shl(2, iszero(iszero(shr(160, amount))))), 0x04)
            }
        }
    }

    /// @dev Permit a user to spend a given amount of
    /// another user's tokens via native EIP-2612 permit if possible, falling
    /// back to Permit2 if native permit fails or is not implemented on the token.
    function permit2(
        address token,
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        bool success;
        /// @solidity memory-safe-assembly
        assembly {
            for {} shl(96, xor(token, WETH9)) {} {
                mstore(0x00, 0x3644e515) // `DOMAIN_SEPARATOR()`.
                if iszero(
                    and( // The arguments of `and` are evaluated from right to left.
                        lt(iszero(mload(0x00)), eq(returndatasize(), 0x20)), // Returns 1 non-zero word.
                        // Gas stipend to limit gas burn for tokens that don't refund gas when
                        // an non-existing function is called. 5K should be enough for a SLOAD.
                        staticcall(5000, token, 0x1c, 0x04, 0x00, 0x20)
                    )
                ) { break }
                // After here, we can be sure that token is a contract.
                let m := mload(0x40)
                mstore(add(m, 0x34), spender)
                mstore(add(m, 0x20), shl(96, owner))
                mstore(add(m, 0x74), deadline)
                if eq(mload(0x00), DAI_DOMAIN_SEPARATOR) {
                    mstore(0x14, owner)
                    mstore(0x00, 0x7ecebe00000000000000000000000000) // `nonces(address)`.
                    mstore(
                        add(m, 0x94),
                        lt(iszero(amount), staticcall(gas(), token, 0x10, 0x24, add(m, 0x54), 0x20))
                    )
                    mstore(m, 0x8fcbaf0c000000000000000000000000) // `IDAIPermit.permit`.
                    // `nonces` is already at `add(m, 0x54)`.
                    // `amount != 0` is already stored at `add(m, 0x94)`.
                    mstore(add(m, 0xb4), and(0xff, v))
                    mstore(add(m, 0xd4), r)
                    mstore(add(m, 0xf4), s)
                    success := call(gas(), token, 0, add(m, 0x10), 0x104, codesize(), 0x00)
                    break
                }
                mstore(m, 0xd505accf000000000000000000000000) // `IERC20Permit.permit`.
                mstore(add(m, 0x54), amount)
                mstore(add(m, 0x94), and(0xff, v))
                mstore(add(m, 0xb4), r)
                mstore(add(m, 0xd4), s)
                success := call(gas(), token, 0, add(m, 0x10), 0xe4, codesize(), 0x00)
                break
            }
        }
        if (!success) simplePermit2(token, owner, spender, amount, deadline, v, r, s);
    }

    /// @dev Simple permit on the Permit2 contract.
    function simplePermit2(
        address token,
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, 0x927da105) // `allowance(address,address,address)`.
            {
                let addressMask := shr(96, not(0))
                mstore(add(m, 0x20), and(addressMask, owner))
                mstore(add(m, 0x40), and(addressMask, token))
                mstore(add(m, 0x60), and(addressMask, spender))
                mstore(add(m, 0xc0), and(addressMask, spender))
            }
            let p := mul(PERMIT2, iszero(shr(160, amount)))
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    gt(returndatasize(), 0x5f), // Returns 3 words: `amount`, `expiration`, `nonce`.
                    staticcall(gas(), p, add(m, 0x1c), 0x64, add(m, 0x60), 0x60)
                )
            ) {
                mstore(0x00, 0x6b836e6b8757f0fd) // `Permit2Failed()` or `Permit2AmountOverflow()`.
                revert(add(0x18, shl(2, iszero(p))), 0x04)
            }
            mstore(m, 0x2b67b570) // `Permit2.permit` (PermitSingle variant).
            // `owner` is already `add(m, 0x20)`.
            // `token` is already at `add(m, 0x40)`.
            mstore(add(m, 0x60), amount)
            mstore(add(m, 0x80), 0xffffffffffff) // `expiration = type(uint48).max`.
            // `nonce` is already at `add(m, 0xa0)`.
            // `spender` is already at `add(m, 0xc0)`.
            mstore(add(m, 0xe0), deadline)
            mstore(add(m, 0x100), 0x100) // `signature` offset.
            mstore(add(m, 0x120), 0x41) // `signature` length.
            mstore(add(m, 0x140), r)
            mstore(add(m, 0x160), s)
            mstore(add(m, 0x180), shl(248, v))
            if iszero( // Revert if token does not have code, or if the call fails.
            mul(extcodesize(token), call(gas(), p, 0, add(m, 0x1c), 0x184, codesize(), 0x00))) {
                mstore(0x00, 0x6b836e6b) // `Permit2Failed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Approves `spender` to spend `amount` of `token` for `address(this)`.
    function permit2Approve(address token, address spender, uint160 amount, uint48 expiration)
        internal
    {
        /// @solidity memory-safe-assembly
        assembly {
            let addressMask := shr(96, not(0))
            let m := mload(0x40)
            mstore(m, 0x87517c45) // `approve(address,address,uint160,uint48)`.
            mstore(add(m, 0x20), and(addressMask, token))
            mstore(add(m, 0x40), and(addressMask, spender))
            mstore(add(m, 0x60), and(addressMask, amount))
            mstore(add(m, 0x80), and(0xffffffffffff, expiration))
            if iszero(call(gas(), PERMIT2, 0, add(m, 0x1c), 0xa0, codesize(), 0x00)) {
                mstore(0x00, 0x324f14ae) // `Permit2ApproveFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Revokes an approval for `token` and `spender` for `address(this)`.
    function permit2Lockdown(address token, address spender) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, 0xcc53287f) // `Permit2.lockdown`.
            mstore(add(m, 0x20), 0x20) // Offset of the `approvals`.
            mstore(add(m, 0x40), 1) // `approvals.length`.
            mstore(add(m, 0x60), shr(96, shl(96, token)))
            mstore(add(m, 0x80), shr(96, shl(96, spender)))
            if iszero(call(gas(), PERMIT2, 0, add(m, 0x1c), 0xa0, codesize(), 0x00)) {
                mstore(0x00, 0x96b3de23) // `Permit2LockdownFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }
}

// src/libraries/StepLib.sol

struct AuctionStep {
    uint24 mps; // Mps to sell per block in the step
    uint64 startBlock; // Start block of the step (inclusive)
    uint64 endBlock; // Ending block of the step (exclusive)
}

/// @notice Library for auction step calculations and parsing
library StepLib {
    using StepLib for *;

    /// @notice The size of a uint64 in bytes
    uint256 public constant UINT64_SIZE = 8;

    /// @notice Error thrown when the offset is too large for the data length
    error StepLib__InvalidOffsetTooLarge();
    /// @notice Error thrown when the offset is not at a step boundary - a uint64 aligned offset
    error StepLib__InvalidOffsetNotAtStepBoundary();

    /// @notice Unpack the mps and block delta from the auction steps data
    function parse(bytes8 data) internal pure returns (uint24 mps, uint40 blockDelta) {
        mps = uint24(bytes3(data));
        blockDelta = uint40(uint64(data));
    }

    /// @notice Load a word at `offset` from data and parse it into mps and blockDelta
    function get(bytes memory data, uint256 offset) internal pure returns (uint24 mps, uint40 blockDelta) {
        // Offset cannot be greater than the data length
        if (offset >= data.length) revert StepLib__InvalidOffsetTooLarge();
        // Offset must be a multiple of a step (uint64 -  uint24|uint40)
        if (offset % UINT64_SIZE != 0) revert StepLib__InvalidOffsetNotAtStepBoundary();

        assembly {
            let packedValue := mload(add(add(data, 0x20), offset))
            packedValue := shr(192, packedValue)
            mps := shr(40, packedValue)
            blockDelta := and(packedValue, 0xFFFFFFFFFF)
        }
    }
}

// src/libraries/BidLib.sol

struct Bid {
    uint64 startBlock; // Block number when the bid was first made in
    uint24 startCumulativeMps; // Cumulative mps at the start of the bid
    uint64 exitedBlock; // Block number when the bid was exited
    uint256 maxPrice; // The max price of the bid
    address owner; // Who will receive the tokens filled and currency refunded
    uint256 amountQ96; // User's currency amount in Q96 form
    uint256 tokensFilled; // Amount of tokens filled
}

/// @title BidLib
library BidLib {
    using BidLib for *;

    /// @dev Error thrown when a bid is submitted with no remaining percentage of the auction
    ///      This is prevented by the auction contract as bids cannot be submitted when the auction is sold out,
    ///      but we catch it instead of reverting with division by zero.
    error MpsRemainingIsZero();

    /// @notice Calculate the number of mps remaining in the auction since the bid was submitted
    /// @param bid The bid to calculate the remaining mps for
    /// @return The number of mps remaining in the auction
    function mpsRemainingInAuctionAfterSubmission(Bid memory bid) internal pure returns (uint24) {
        return ConstantsLib.MPS - bid.startCumulativeMps;
    }

    /// @notice Scale a bid amount to its effective amount over the remaining percentage of the auction
    ///         This is an important normalization step to ensure that we can calculate the currencyRaised
    ///         when cumulative demand is less than supply using the original supply schedule.
    /// @param bid The bid to scale
    /// @return The scaled amount
    function toEffectiveAmount(Bid memory bid) internal pure returns (uint256) {
        uint24 mpsRemainingInAuction = bid.mpsRemainingInAuctionAfterSubmission();
        if (mpsRemainingInAuction == 0) revert MpsRemainingIsZero();
        return bid.amountQ96 * ConstantsLib.MPS / mpsRemainingInAuction;
    }
}

// src/libraries/CurrencyLibrary.sol

type Currency is address;

using CurrencyLibrary for Currency global;

/// @title CurrencyLibrary
/// @dev This library allows for transferring and holding native tokens and ERC20 tokens
/// @dev Forked from https://github.com/Uniswap/v4-core/blob/main/src/types/Currency.sol but modified to not bubble up reverts
library CurrencyLibrary {
    /// @notice Thrown when a native transfer fails
    error NativeTransferFailed();

    /// @notice Thrown when an ERC20 transfer fails
    error ERC20TransferFailed();

    /// @notice A constant to represent the native currency
    Currency public constant ADDRESS_ZERO = Currency.wrap(address(0));

    function transfer(Currency currency, address to, uint256 amount) internal {
        // altered from https://github.com/transmissions11/solmate/blob/44a9963d4c78111f77caa0e65d677b8b46d6f2e6/src/utils/SafeTransferLib.sol
        // modified custom error selectors

        bool success;
        if (currency.isAddressZero()) {
            assembly ('memory-safe') {
                // Transfer the ETH and revert if it fails.
                success := call(gas(), to, amount, 0, 0, 0, 0)
            }
            // revert with NativeTransferFailed
            if (!success) {
                revert NativeTransferFailed();
            }
        } else {
            assembly ('memory-safe') {
                // Get a pointer to some free memory.
                let fmp := mload(0x40)

                // Write the abi-encoded calldata into memory, beginning with the function selector.
                mstore(fmp, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(fmp, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
                mstore(add(fmp, 36), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

                success := and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                    // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                    // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                    // Counterintuitively, this call must be positioned second to the or() call in the
                    // surrounding and() call or else returndatasize() will be zero during the computation.
                    call(gas(), currency, 0, fmp, 68, 0, 32)
                )

                // Now clean the memory we used
                mstore(fmp, 0) // 4 byte `selector` and 28 bytes of `to` were stored here
                mstore(add(fmp, 0x20), 0) // 4 bytes of `to` and 28 bytes of `amount` were stored here
                mstore(add(fmp, 0x40), 0) // 4 bytes of `amount` were stored here
            }
            // revert with ERC20TransferFailed
            if (!success) {
                revert ERC20TransferFailed();
            }
        }
    }

    function balanceOf(Currency currency, address owner) internal view returns (uint256) {
        if (currency.isAddressZero()) {
            return owner.balance;
        } else {
            return IERC20Minimal(Currency.unwrap(currency)).balanceOf(owner);
        }
    }

    function isAddressZero(Currency currency) internal pure returns (bool) {
        return Currency.unwrap(currency) == Currency.unwrap(ADDRESS_ZERO);
    }
}

// src/interfaces/IStepStorage.sol

/// @notice Interface for managing auction step storage
interface IStepStorage {
    /// @notice Error thrown when the end block is equal to or before the start block
    error InvalidEndBlock();
    /// @notice Error thrown when the auction is over
    error AuctionIsOver();
    /// @notice Error thrown when the auction data length is invalid
    error InvalidAuctionDataLength();
    /// @notice Error thrown when the block delta in a step is zero
    error StepBlockDeltaCannotBeZero();
    /// @notice Error thrown when the mps is invalid
    /// @param actualMps The sum of the mps times the block delta
    /// @param expectedMps The expected mps of the auction (ConstantsLib.MPS)
    error InvalidStepDataMps(uint256 actualMps, uint256 expectedMps);
    /// @notice Error thrown when the calculated end block is invalid
    /// @param actualEndBlock The calculated end block from the step data
    /// @param expectedEndBlock The expected end block from the constructor
    error InvalidEndBlockGivenStepData(uint64 actualEndBlock, uint64 expectedEndBlock);

    /// @notice The address pointer to the contract deployed by SSTORE2
    /// @return The address pointer
    function pointer() external view returns (address);

    /// @notice Get the current active auction step
    function step() external view returns (AuctionStep memory);

    /// @notice Emitted when an auction step is recorded
    /// @param startBlock The start block of the auction step
    /// @param endBlock The end block of the auction step
    /// @param mps The percentage of total tokens to sell per block during this auction step, represented in ten-millionths of the total supply (1e7 = 100%)
    event AuctionStepRecorded(uint256 startBlock, uint256 endBlock, uint24 mps);
}

// src/libraries/MaxBidPriceLib.sol

/// @title MaxBidPriceLib
/// @notice Library for calculating the maximum bid price for a given total supply
/// @dev The two are generally inversely correlated with certain constraints.
library MaxBidPriceLib {
    /**
     * @dev Given a total supply we want to find the maximum bid price such that both the
     * token liquidity and currency liquidity at the end of the Auction are less than the
     * maximum liquidity supported by Uniswap v4.
     *
     * The chart below shows the shaded area of valid (max bid price, total supply) value pairs such that
     * both calculated liquidity values are less than the maximum liquidity supported by Uniswap v4.
     * (x axis represents the max bid price in log form, and y is the total supply in log form)
     *
     * y ↑
     * |               :                         :   :
     * |                                            :                                  :
     * 128 +               :                               :
     * |                                                  :                            :
     * |               :                                 :   :
     * |                                                    :                          :
     * |               :                                       :
     * |                                                          :                    :
     * |               :                                         :   : (x=110, y=100)
     * | : : : : : : : +#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+ : ::: : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : : :
     * 96 +            +############################################   :
     * |               #################################################  :            :
     * |               +#################################################+#  :
     * |               #####################################################+          :
     * |               +#######################################################:
     * |               ########################################################## :    :
     * |               +#########################################################+#  :
     * |               #############################################################+  :
     * 64 +            +###############################################################: (x=160, y=62)
     * |               ################################################################:  :
     * |               +###############################################################  :   :
     * |               ################################################################:    :
     * |               +###############################################################        :
     * |               ################################################################:          :
     * |               +###############################################################          :   :
     * |               ################################################################:            :
     * 32 +            +###############################################################                :
     * |               ################################################################:                  :
     * |               +###############################################################                  :   :
     * |               ################################################################:                    :
     * |               +###############################################################                        :
     * |               ################################################################:                          :
     * |               +###############################################################+               +         :   : +
     * +---------------+###############+###############+###############+###############+---------------+---------------+--------------- x (max price)
     *  0              32              64              96              128             160             192             224           256
     *
     *
     * Legend:
     * x = max bid price in log form
     * y = total supply in log form
     * L_max = 2^107 (the lowest max liquidity per tick supported in Uniswap v4)
     * p_sqrtMax = 1461446703485210103287273052203988822378723970342 (max sqrt price in Uniswap v4)
     * p_sqrtMin = 4295128739 (min sqrt price in Uniswap v4)
     * x < 160, x > 32; (minimum price of 2^32, maximum price of 2^160)
     * y < 100; (minimum supply of 2^0 or 1, maximum supply of 2^100)
     *
     * Equations for liquidity amounts in Uniswap v4:
     * 1) If currencyIsCurrency1, L_0 = (2^y * ((2^((x+96)/2) * 2^160) / 2^96)) / |2^((x+96)/2)-p_sqrtMax| < L_max
     * 2)                         L_1 = (2^(x+y)) / |2^((x+96)/2)-p_sqrtMin| < L_max
     * 3) if currencyIsCurrency0, L_0 = (2^y * p_sqrtMax * 2^((192-x+96)/2)) / (2^(192-x+96) * |p_sqrtMax-2^((192-x+96)/2)|) < L_max
     * 4)                         L_1 = (2^(y+96)) / |2^((192-x+96)/2)-p_sqrtMin| < L_max
     */
    /// @notice The maximum allowable price for a bid is type(uint160).max
    /// @dev This is the maximum price that can be shifted left by 96 bits without overflowing a uint256
    uint256 constant MAX_V4_PRICE = type(uint160).max;

    /// @notice The total supply value below which the maximum bid price is capped at MAX_V4_PRICE
    /// @dev Since the two are inversely correlated, generally lower total supply = higher max bid price
    ///      However, for very small total supply values we still can't exceed the max v4 price.
    ///      This is the intersection of `maxPriceKeepingCurrencyRaisedUnderInt128Max` and MAX_V4_PRICE,
    ///      meaning that because we can't support prices above uint160.max, all total supply values at or below
    ///      this threshold are capped at MAX_V4_PRICE.
    uint256 constant LOWER_TOTAL_SUPPLY_THRESHOLD = 1 << 62;

    /// @notice Calculates the maximum bid price for a given total supply
    /// @dev Total supply values under the LOWER_TOTAL_SUPPLY_THRESHOLD are capped at MAX_V4_PRICE
    function maxBidPrice(uint128 _totalSupply) internal pure returns (uint256) {
        // Small total supply values would return a price which exceeds the max v4 price, so we cap it at MAX_V4_PRICE
        if (_totalSupply <= LOWER_TOTAL_SUPPLY_THRESHOLD) return MAX_V4_PRICE;
        /**
         * Derivation: For a given total supply y (in log space), find the max bid price x (in log space)
         * The equations in the chart are equivalent for both currency/token sort orders (intuitive given a full range position).
         * Token1 liquidity is the limiting factor, so we use L_1 for simplicity:
         *  2^(x+y) / |2^((x+96)/2)-p_sqrtMin| < L_max
         *  2^(x+y) < L_max * |2^((x+96)/2)-p_sqrtMin|
         * We substitute a larger number than p_sqrtMin such that |2^((x+96)/2)-p_sqrtMin| ~ 2^((x+96)/2 - 1)
         *  2^(x+y) < L_max * 2^((x+96)/2 - 1)
         * Using 2^107 for L_max, we get:
         *  2^(x+y) < 2^107 * 2^((x+96)/2 - 1)
         * Taking the log2 of both sides, we get:
         *  x + y < 107 + (x+96) / 2 - 1
         *  x + y < 107 + x/2 + 48 - 1
         * Since we are given total supply (y), we can solve for x:
         *  x/2 = 107 + 47 - y
         *  x/2 = 154 - y
         *  x = 2 * (154 - y)
         * We want to find 2^x, not `x` so we take both sides to the power of 2:
         *  2^x = (2^154 / 2^y) ** 2
         *
         * Because we return early if total supply is less than 2^62 the result of this will not overflow a uint256.
         */
        uint256 maxPriceKeepingLiquidityUnderMax = uint256((1 << 154) / _totalSupply) ** 2;

        // Additionally, we need to ensure that the currency raised is <= int128.max (2^127 - 1)
        // since PoolManager will cast it to int128 when the position is created.
        // The maxmimum currencyRaised in the auction is equal to totalSupply * maxBidPrice / Q96
        // To be conservative, we ensure that it is under 2^126, and rearranging the equation we get:
        // maxBidPrice < (2^126 * Q96) / totalSupply = 2^222 / totalSupply
        uint256 maxPriceKeepingCurrencyRaisedUnderInt128Max = uint256(1 << 222) / _totalSupply;

        // Take the minimum of the two to ensure that the (max bid price, total supply) pair is within the valid range.
        return FixedPointMathLib.min(maxPriceKeepingLiquidityUnderMax, maxPriceKeepingCurrencyRaisedUnderInt128Max);
    }
}

// src/libraries/ValidationHookLib.sol

/// @title ValidationHookLib
/// @notice Library for handling calls to validation hooks and bubbling up the revert reason
library ValidationHookLib {
    /// @notice Error thrown when a validation hook call fails
    /// @param reason The bubbled up revert reason
    error ValidationHookCallFailed(bytes reason);

    /// @notice Handles calling a validation hook and bubbling up the revert reason
    function handleValidate(
        IValidationHook hook,
        uint256 maxPrice,
        uint128 amount,
        address owner,
        address sender,
        bytes calldata hookData
    ) internal {
        if (address(hook) == address(0)) return;

        try hook.validate(maxPrice, amount, owner, sender, hookData) {}
        catch (bytes memory reason) {
            revert ValidationHookCallFailed(reason);
        }
    }
}

// src/interfaces/IBidStorage.sol

/// @notice Interface for bid storage operations
interface IBidStorage {
    /// @notice Error thrown when doing an operation on a bid that does not exist
    error BidIdDoesNotExist(uint256 bidId);

    /// @notice Get the id of the next bid to be created
    /// @return The id of the next bid to be created
    function nextBidId() external view returns (uint256);

    /// @notice Get a bid from storage
    /// @dev Will revert if the bid does not exist
    /// @param bidId The id of the bid to get
    /// @return The bid
    function bids(uint256 bidId) external view returns (Bid memory);
}

// src/interfaces/external/ILBPInitializer.sol

/// @dev The interface id of the ILBPInitializer interface
bytes4 constant ILBP_INITIALIZER_INTERFACE_ID = type(ILBPInitializer).interfaceId;

/// @notice General parameters for initializing an LBP strategy
struct LBPInitializationParams {
    uint256 initialPriceX96; // the price discovered by the contract
    uint256 tokensSold; // the number of tokens sold by the contract
    uint256 currencyRaised; // the amount of currency raised by the contract
}

/// @title ILBPInitializer
/// @notice Generic interface for contracts used for initializing an LBP strategy
interface ILBPInitializer is IDistributionContract, IERC165 {
    /// @notice Returns the LBP initialization parameters as determined by the implementing contract
    /// @dev The implementing contract MUST ensure that these values are correct at the time of calling
    /// @return params The LBP initialization parameters
    function lbpInitializationParams() external view returns (LBPInitializationParams memory params);

    /// @notice Returns the token used by the initializer
    function token() external view returns (address);
    /// @notice Returns the currency used by the initializer
    function currency() external view returns (address);
    /// @notice Returns the total supply of the token used by the initializer
    function totalSupply() external view returns (uint128);
    /// @notice Returns the address which will receive the unsold tokens
    function tokensRecipient() external view returns (address);
    /// @notice Returns the address which will receive the raised currency
    function fundsRecipient() external view returns (address);
    /// @notice Returns the start block of the initializer
    function startBlock() external view returns (uint64);
    /// @notice Returns the end block of the initializer
    function endBlock() external view returns (uint64);
}

// src/interfaces/ITokenCurrencyStorage.sol

/// @notice Interface for token and currency storage operations
interface ITokenCurrencyStorage {
    /// @notice Error thrown when the token is the native currency
    error TokenIsAddressZero();
    /// @notice Error thrown when the token and currency are the same
    error TokenAndCurrencyCannotBeTheSame();
    /// @notice Error thrown when the total supply is zero
    error TotalSupplyIsZero();
    /// @notice Error thrown when the total supply is too large
    error TotalSupplyIsTooLarge();
    /// @notice Error thrown when the funds recipient is the zero address
    error FundsRecipientIsZero();
    /// @notice Error thrown when the tokens recipient is the zero address
    error TokensRecipientIsZero();
    /// @notice Error thrown when the currency cannot be swept
    error CannotSweepCurrency();
    /// @notice Error thrown when the tokens cannot be swept
    error CannotSweepTokens();
    /// @notice Error thrown when the auction has not graduated
    error NotGraduated();

    /// @notice Emitted when the tokens are swept
    /// @param tokensRecipient The address of the tokens recipient
    /// @param tokensAmount The amount of tokens swept
    event TokensSwept(address indexed tokensRecipient, uint256 tokensAmount);

    /// @notice Emitted when the currency is swept
    /// @param fundsRecipient The address of the funds recipient
    /// @param currencyAmount The amount of currency swept
    event CurrencySwept(address indexed fundsRecipient, uint256 currencyAmount);
}

// src/TickStorage.sol

/// @title TickStorage
/// @notice Abstract contract for handling tick storage
abstract contract TickStorage is ITickStorage {
    /// @notice Mapping of price levels to tick data
    mapping(uint256 price => Tick) private $_ticks;

    /// @notice The price of the next initialized tick above the clearing price
    /// @dev This will be equal to the clearingPrice if no ticks have been initialized yet
    uint256 internal $nextActiveTickPrice;
    /// @notice The floor price of the auction
    uint256 internal immutable FLOOR_PRICE;
    /// @notice The tick spacing of the auction - bids must be placed at discrete tick intervals
    uint256 internal immutable TICK_SPACING;

    /// @notice Sentinel value for the next pointer of the highest tick in the book
    uint256 public constant MAX_TICK_PTR = type(uint256).max;

    constructor(uint256 _tickSpacing, uint256 _floorPrice) {
        if (_tickSpacing < ConstantsLib.MIN_TICK_SPACING) revert TickSpacingTooSmall();
        TICK_SPACING = _tickSpacing;
        if (_floorPrice == 0) revert FloorPriceIsZero();
        if (_floorPrice < ConstantsLib.MIN_FLOOR_PRICE) revert FloorPriceTooLow();
        FLOOR_PRICE = _floorPrice;
        // Initialize the floor price as the first tick
        // _getTick will validate that it is also at a tick boundary
        _getTick(FLOOR_PRICE).next = MAX_TICK_PTR;
        $nextActiveTickPrice = MAX_TICK_PTR;
        emit NextActiveTickUpdated(MAX_TICK_PTR);
        emit TickInitialized(FLOOR_PRICE);
    }

    /// @notice Internal function to get a tick at a price
    /// @dev The returned tick is not guaranteed to be initialized
    function _getTick(uint256 price) internal view returns (Tick storage) {
        // Validate `price` is at a boundary designated by the tick spacing
        if (price % TICK_SPACING != 0) revert TickPriceNotAtBoundary();
        return $_ticks[price];
    }

    /// @notice Initialize a tick at `price` if it does not exist already
    /// @dev `prevPrice` MUST be the price of an initialized tick before the new price.
    ///      Ideally, it is the price of the tick immediately preceding the desired price. If not,
    ///      we will iterate through the ticks until we find the next price which requires more gas.
    ///      If `price` is < `nextActiveTickPrice`, then `price` will be set as the nextActiveTickPrice
    /// @param prevPrice The price of the previous tick
    /// @param price The price of the tick
    function _initializeTickIfNeeded(uint256 prevPrice, uint256 price) internal {
        if (price == MAX_TICK_PTR) revert InvalidTickPrice();
        // _getTick will validate that `price` is at a boundary designated by the tick spacing
        Tick storage $newTick = _getTick(price);
        // Early return if the tick is already initialized
        if ($newTick.next != 0) return;
        // Otherwise, we need to iterate through the linked list to find the correct position for the new tick
        // Require that `prevPrice` is less than `price` since we can only iterate forward
        if (prevPrice >= price) revert TickPreviousPriceInvalid();
        uint256 nextPrice = _getTick(prevPrice).next;
        // Revert if the next price is 0 as that means the `prevPrice` hint was not an initialized tick
        if (nextPrice == 0) revert TickPreviousPriceInvalid();
        // Move the `prevPrice` pointer up until its next pointer is a tick greater than or equal to `price`
        // If `price` would be the highest tick in the list, this will iterate until `nextPrice` == MAX_TICK_PTR,
        // which will end the loop since we don't allow for ticks to be initialized at MAX_TICK_PTR.
        // Iterating to find the tick right before `price` ensures that it is correctly positioned in the linked list.
        while (nextPrice < price) {
            prevPrice = nextPrice;
            nextPrice = _getTick(nextPrice).next;
        }
        // Update linked list pointers
        $newTick.next = nextPrice;
        _getTick(prevPrice).next = price;
        // If the next tick is the nextActiveTick, update nextActiveTick to the new tick
        // In the base case, where next == 0 and nextActiveTickPrice == 0, this will set nextActiveTickPrice to price
        if (nextPrice == $nextActiveTickPrice) {
            $nextActiveTickPrice = price;
            emit NextActiveTickUpdated(price);
        }

        emit TickInitialized(price);
    }

    /// @notice Internal function to add demand to a tick
    /// @param price The price of the tick
    /// @param currencyDemandQ96 The demand to add
    function _updateTickDemand(uint256 price, uint256 currencyDemandQ96) internal {
        Tick storage $tick = _getTick(price);
        if ($tick.next == 0) revert CannotUpdateUninitializedTick();
        $tick.currencyDemandQ96 += currencyDemandQ96;
    }

    // Getters
    /// @inheritdoc ITickStorage
    function floorPrice() external view returns (uint256) {
        return FLOOR_PRICE;
    }

    /// @inheritdoc ITickStorage
    function tickSpacing() external view returns (uint256) {
        return TICK_SPACING;
    }

    /// @inheritdoc ITickStorage
    function nextActiveTickPrice() external view returns (uint256) {
        return $nextActiveTickPrice;
    }

    /// @inheritdoc ITickStorage
    function ticks(uint256 price) external view returns (Tick memory) {
        return _getTick(price);
    }
}

// src/libraries/ValueX7Lib.sol

/// @notice A ValueX7 is a uint256 value that has been multiplied by MPS
/// @dev X7 values are used for demand values to avoid intermediate division by MPS
type ValueX7 is uint256;

using {saturatingSub, divUint256} for ValueX7 global;

/// @notice Subtract two ValueX7 values, returning zero on underflow.
/// @dev Wrapper around FixedPointMathLib.saturatingSub
function saturatingSub(ValueX7 a, ValueX7 b) pure returns (ValueX7) {
    return ValueX7.wrap(FixedPointMathLib.saturatingSub(ValueX7.unwrap(a), ValueX7.unwrap(b)));
}

/// @notice Divide a ValueX7 value by a uint256
function divUint256(ValueX7 a, uint256 b) pure returns (ValueX7) {
    return ValueX7.wrap(ValueX7.unwrap(a) / b);
}

/// @title ValueX7Lib
library ValueX7Lib {
    using ValueX7Lib for ValueX7;

    /// @notice The scaling factor for ValueX7 values (ConstantsLib.MPS)
    uint256 public constant X7 = ConstantsLib.MPS;

    /// @notice Multiply a uint256 value by MPS
    /// @dev This ensures that future operations will not lose precision
    /// @return The result as a ValueX7
    function scaleUpToX7(uint256 value) internal pure returns (ValueX7) {
        return ValueX7.wrap(value * X7);
    }

    /// @notice Divide a ValueX7 value by MPS
    /// @return The result as a uint256
    function scaleDownToUint256(ValueX7 value) internal pure returns (uint256) {
        return ValueX7.unwrap(value) / X7;
    }
}

// src/BidStorage.sol

/// @notice Abstract contract for managing bid storage
abstract contract BidStorage is IBidStorage {
    /// @notice The id of the next bid to be created
    uint256 private $_nextBidId;
    /// @notice The mapping of bid ids to bids
    mapping(uint256 bidId => Bid bid) private $_bids;

    /// @notice Get a bid from storage
    /// @param bidId The id of the bid to get
    /// @return bid The bid
    function _getBid(uint256 bidId) internal view returns (Bid storage) {
        if (bidId >= $_nextBidId) revert BidIdDoesNotExist(bidId);
        return $_bids[bidId];
    }

    /// @notice Create a new bid
    /// @param _blockNumberIsh The block number when the bid was created
    /// @param _amount The amount of the bid
    /// @param _owner The owner of the bid
    /// @param _maxPrice The maximum price for the bid
    /// @param _startCumulativeMps The cumulative mps at the start of the bid
    /// @return bid The created bid
    /// @return bidId The id of the created bid
    function _createBid(
        uint256 _blockNumberIsh,
        uint256 _amount,
        address _owner,
        uint256 _maxPrice,
        uint24 _startCumulativeMps
    ) internal returns (Bid memory bid, uint256 bidId) {
        bid = Bid({
            startBlock: uint64(_blockNumberIsh),
            startCumulativeMps: _startCumulativeMps,
            exitedBlock: 0,
            maxPrice: _maxPrice,
            amountQ96: _amount,
            owner: _owner,
            tokensFilled: 0
        });

        bidId = $_nextBidId;
        $_bids[bidId] = bid;
        $_nextBidId++;
    }

    /// Getters
    /// @inheritdoc IBidStorage
    function nextBidId() external view returns (uint256) {
        return $_nextBidId;
    }

    /// @inheritdoc IBidStorage
    function bids(uint256 bidId) external view returns (Bid memory) {
        return _getBid(bidId);
    }
}

// src/libraries/CheckpointLib.sol

struct Checkpoint {
    uint256 clearingPrice; // The X96 price which the auction is currently clearing at
    ValueX7 currencyRaisedAtClearingPriceQ96_X7; // The currency raised so far to this clearing price
    uint256 cumulativeMpsPerPrice; // A running sum of the ratio between mps and price
    uint24 cumulativeMps; // The number of mps sold in the auction so far (via the original supply schedule)
    uint64 prev; // Block number of the previous checkpoint
    uint64 next; // Block number of the next checkpoint
}

/// @title CheckpointLib
library CheckpointLib {
    /// @notice Get the remaining mps in the auction at the given checkpoint
    /// @param _checkpoint The checkpoint with `cumulativeMps` so far
    /// @return The remaining mps in the auction
    function remainingMpsInAuction(Checkpoint memory _checkpoint) internal pure returns (uint24) {
        return ConstantsLib.MPS - _checkpoint.cumulativeMps;
    }

    /// @notice Calculate the supply to price ratio. Will return zero if `price` is zero
    /// @dev This function returns a value in Q96 form
    /// @param mps The number of supply mps sold
    /// @param price The price they were sold at
    /// @return the ratio
    function getMpsPerPrice(uint24 mps, uint256 price) internal pure returns (uint256) {
        if (price == 0) return 0;
        // The bitshift cannot overflow because a uint24 shifted left FixedPoint96.RESOLUTION * 2 (192) bits will always be less than 2^256
        return (uint256(mps) << 192) / price;
    }
}

// src/interfaces/ICheckpointStorage.sol

/// @notice Interface for checkpoint storage operations
interface ICheckpointStorage {
    /// @notice Revert when attempting to insert a checkpoint at a block number not strictly greater than the last one
    error CheckpointBlockNotIncreasing();

    /// @notice Get the latest checkpoint at the last checkpointed block
    /// @dev Be aware that the latest checkpoint may not be up to date, it is recommended
    ///      to always call `checkpoint()` before using getter functions
    /// @return The latest checkpoint
    function latestCheckpoint() external view returns (Checkpoint memory);

    /// @notice Get the number of the last checkpointed block
    /// @dev Be aware that the last checkpointed block may not be up to date, it is recommended
    ///      to always call `checkpoint()` before using getter functions
    /// @return The block number of the last checkpoint
    function lastCheckpointedBlock() external view returns (uint64);

    /// @notice Get a checkpoint at a block number
    /// @param blockNumber The block number to get the checkpoint for
    function checkpoints(uint64 blockNumber) external view returns (Checkpoint memory);
}

// src/StepStorage.sol

/// @title StepStorage
/// @notice Abstract contract to store and read information about the auction issuance schedule
abstract contract StepStorage is IStepStorage {
    using StepLib for *;
    using SSTORE2 for *;

    /// @notice The block at which the auction starts
    uint64 internal immutable START_BLOCK;
    /// @notice The block at which the auction ends
    uint64 internal immutable END_BLOCK;
    /// @notice Cached length of the auction steps data provided in the constructor
    uint256 internal immutable _LENGTH;

    /// @notice The address pointer to the contract deployed by SSTORE2
    address private immutable $_pointer;
    /// @notice The word offset of the last read step in `auctionStepsData` bytes
    uint256 private $_offset;
    /// @notice The current active auction step
    AuctionStep internal $step;

    constructor(bytes memory _auctionStepsData, uint64 _startBlock, uint64 _endBlock) {
        if (_startBlock >= _endBlock) revert InvalidEndBlock();
        START_BLOCK = _startBlock;
        END_BLOCK = _endBlock;
        _LENGTH = _auctionStepsData.length;

        address _pointer = _auctionStepsData.write();
        _validate(_pointer);
        $_pointer = _pointer;

        _advanceStep();
    }

    /// @notice Validate the data provided in the constructor
    /// @dev Checks that the contract was correctly deployed by SSTORE2 and that the total mps and blocks are valid
    function _validate(address _pointer) internal view {
        bytes memory _auctionStepsData = _pointer.read();
        if (
            _auctionStepsData.length == 0 || _auctionStepsData.length % StepLib.UINT64_SIZE != 0
                || _auctionStepsData.length != _LENGTH
        ) revert InvalidAuctionDataLength();

        // Loop through the auction steps data and check if the mps is valid
        uint256 sumMps = 0;
        uint64 sumBlockDelta = 0;
        for (uint256 i = 0; i < _LENGTH; i += StepLib.UINT64_SIZE) {
            (uint24 mps, uint40 blockDelta) = _auctionStepsData.get(i);
            // Prevent the block delta from being set to zero
            if (blockDelta == 0) revert StepBlockDeltaCannotBeZero();
            sumMps += mps * blockDelta;
            sumBlockDelta += blockDelta;
        }
        if (sumMps != ConstantsLib.MPS) revert InvalidStepDataMps(sumMps, ConstantsLib.MPS);
        uint64 calculatedEndBlock = START_BLOCK + sumBlockDelta;
        if (calculatedEndBlock != END_BLOCK) revert InvalidEndBlockGivenStepData(calculatedEndBlock, END_BLOCK);
    }

    /// @notice Advance the current auction step
    /// @dev This function is called on every new bid if the current step is complete
    function _advanceStep() internal returns (AuctionStep memory) {
        if ($_offset >= _LENGTH) revert AuctionIsOver();

        bytes8 _auctionStep = bytes8($_pointer.read($_offset, $_offset + StepLib.UINT64_SIZE));
        (uint24 mps, uint40 blockDelta) = _auctionStep.parse();

        uint64 _startBlock = $step.endBlock;
        if (_startBlock == 0) _startBlock = START_BLOCK;
        uint64 _endBlock = _startBlock + uint64(blockDelta);

        $step = AuctionStep({startBlock: _startBlock, endBlock: _endBlock, mps: mps});

        $_offset += StepLib.UINT64_SIZE;

        emit AuctionStepRecorded(_startBlock, _endBlock, mps);
        return $step;
    }

    /// @inheritdoc IStepStorage
    function step() external view returns (AuctionStep memory) {
        return $step;
    }

    // Getters
    /// @inheritdoc IStepStorage
    function pointer() external view returns (address) {
        return $_pointer;
    }
}

// src/libraries/CheckpointAccountingLib.sol

/// @title CheckpointAccountingLib
/// @notice Pure accounting helpers for computing fills and currency spent across checkpoints
library CheckpointAccountingLib {
    using FixedPointMathLib for *;
    using BidLib for *;

    /// @notice Calculate the tokens sold and proportion of input used for a fully filled bid between two checkpoints
    /// @dev MUST only be used for checkpoints where the bid's max price is strictly greater than the clearing price
    ///      because it uses lazy accounting to calculate the tokens filled
    /// @param upper The upper checkpoint
    /// @param startCheckpoint The start checkpoint of the bid
    /// @param bid The bid
    /// @return tokensFilled The tokens sold
    /// @return currencySpentQ96 The amount of currency spent in Q96 form
    function accountFullyFilledCheckpoints(Checkpoint memory upper, Checkpoint memory startCheckpoint, Bid memory bid)
        internal
        pure
        returns (uint256 tokensFilled, uint256 currencySpentQ96)
    {
        (tokensFilled, currencySpentQ96) = calculateFill(
            bid,
            upper.cumulativeMpsPerPrice - startCheckpoint.cumulativeMpsPerPrice,
            upper.cumulativeMps - startCheckpoint.cumulativeMps
        );
    }

    /// @notice Calculate the tokens sold and currency spent for a partially filled bid
    /// @param bid The bid
    /// @param tickDemandQ96 The total demand at the tick
    /// @param currencyRaisedAtClearingPriceQ96_X7 The cumulative supply sold to the clearing price
    /// @return tokensFilled The tokens sold
    /// @return currencySpentQ96 The amount of currency spent in Q96 form
    function accountPartiallyFilledCheckpoints(
        Bid memory bid,
        uint256 tickDemandQ96,
        ValueX7 currencyRaisedAtClearingPriceQ96_X7
    ) internal pure returns (uint256 tokensFilled, uint256 currencySpentQ96) {
        if (tickDemandQ96 == 0) return (0, 0);

        // Apply the ratio between bid demand and tick demand to the currencyRaisedAtClearingPriceQ96_X7 value
        // If currency spent is calculated to have a remainder, we round up.
        // In the case where the result would have been 0, we will return 1 wei.
        uint256 denominator = tickDemandQ96 * bid.mpsRemainingInAuctionAfterSubmission();
        currencySpentQ96 = bid.amountQ96.fullMulDivUp(ValueX7.unwrap(currencyRaisedAtClearingPriceQ96_X7), denominator);

        // We derive tokens filled from the currency spent by dividing it by the max price.
        // If the currency spent is 0, tokens filled will be 0 as well.
        tokensFilled =
            bid.amountQ96.fullMulDiv(ValueX7.unwrap(currencyRaisedAtClearingPriceQ96_X7), denominator) / bid.maxPrice;
    }

    /// @notice Calculate the tokens filled and currency spent for a bid
    /// @dev Uses lazy accounting to efficiently calculate fills across time periods without iterating blocks.
    ///      MUST only be used when the bid's max price is strictly greater than the clearing price throughout.
    /// @param bid the bid to evaluate
    /// @param cumulativeMpsPerPriceDelta the cumulative sum of supply to price ratio
    /// @param cumulativeMpsDelta the cumulative sum of mps values across the block range
    /// @return tokensFilled the amount of tokens filled for this bid
    /// @return currencySpentQ96 the amount of currency spent by this bid in Q96 form
    function calculateFill(Bid memory bid, uint256 cumulativeMpsPerPriceDelta, uint24 cumulativeMpsDelta)
        internal
        pure
        returns (uint256 tokensFilled, uint256 currencySpentQ96)
    {
        uint24 mpsRemainingInAuctionAfterSubmission = bid.mpsRemainingInAuctionAfterSubmission();

        // Currency spent is original currency amount multiplied by percentage fully filled over percentage allocated
        currencySpentQ96 = bid.amountQ96.fullMulDivUp(cumulativeMpsDelta, mpsRemainingInAuctionAfterSubmission);

        // Tokens filled are calculated from the effective amount over the allocation
        tokensFilled = bid.amountQ96
            .fullMulDiv(
                cumulativeMpsPerPriceDelta,
                (FixedPoint96.Q96 << FixedPoint96.RESOLUTION) * mpsRemainingInAuctionAfterSubmission
            );
    }
}

// src/TokenCurrencyStorage.sol

/// @title TokenCurrencyStorage
abstract contract TokenCurrencyStorage is ITokenCurrencyStorage {
    using ValueX7Lib for *;
    using CurrencyLibrary for Currency;

    /// @notice The currency being raised in the auction
    Currency internal immutable CURRENCY;
    /// @notice The token being sold in the auction
    IERC20Minimal internal immutable TOKEN;
    /// @notice The total supply of tokens to sell
    uint128 internal immutable TOTAL_SUPPLY;
    /// @notice The recipient of any unsold tokens at the end of the auction
    address internal immutable TOKENS_RECIPIENT;
    /// @notice The recipient of the raised Currency from the auction
    address internal immutable FUNDS_RECIPIENT;
    /// @notice The amount of currency required to be raised for the auction
    ///         to graduate in Q96 form, scaled up by X7
    ValueX7 internal immutable REQUIRED_CURRENCY_RAISED_Q96_X7;

    /// @notice The block at which the currency was swept
    uint256 public sweepCurrencyBlock;
    /// @notice The block at which the tokens were swept
    uint256 public sweepUnsoldTokensBlock;

    constructor(
        address _token,
        address _currency,
        uint128 _totalSupply,
        address _tokensRecipient,
        address _fundsRecipient,
        uint128 _requiredCurrencyRaised
    ) {
        if (_token == address(0)) revert TokenIsAddressZero();
        if (_token == _currency) revert TokenAndCurrencyCannotBeTheSame();
        if (_totalSupply == 0) revert TotalSupplyIsZero();
        if (_totalSupply > ConstantsLib.MAX_TOTAL_SUPPLY) revert TotalSupplyIsTooLarge();
        if (_tokensRecipient == address(0)) revert TokensRecipientIsZero();
        if (_fundsRecipient == address(0)) revert FundsRecipientIsZero();

        TOKEN = IERC20Minimal(_token);
        CURRENCY = Currency.wrap(_currency);
        TOTAL_SUPPLY = _totalSupply;
        TOKENS_RECIPIENT = _tokensRecipient;
        FUNDS_RECIPIENT = _fundsRecipient;
        REQUIRED_CURRENCY_RAISED_Q96_X7 = (uint256(_requiredCurrencyRaised) << FixedPoint96.RESOLUTION).scaleUpToX7();
    }

    function _sweepCurrency(uint256 _blockNumberIsh, uint256 _amount) internal {
        sweepCurrencyBlock = _blockNumberIsh;
        if (_amount > 0) {
            CURRENCY.transfer(FUNDS_RECIPIENT, _amount);
        }
        emit CurrencySwept(FUNDS_RECIPIENT, _amount);
    }

    function _sweepUnsoldTokens(uint256 _blockNumberIsh, uint256 _amount) internal {
        sweepUnsoldTokensBlock = _blockNumberIsh;
        if (_amount > 0) {
            Currency.wrap(address(TOKEN)).transfer(TOKENS_RECIPIENT, _amount);
        }
        emit TokensSwept(TOKENS_RECIPIENT, _amount);
    }
}

// src/CheckpointStorage.sol

/// @title CheckpointStorage
/// @notice Abstract contract for managing auction checkpoints and bid fill calculations
abstract contract CheckpointStorage is ICheckpointStorage {
    /// @notice Maximum block number value used as sentinel for last checkpoint
    uint64 public constant MAX_BLOCK_NUMBER = type(uint64).max;

    /// @notice Storage of checkpoints
    mapping(uint64 blockNumber => Checkpoint) private $_checkpoints;
    /// @notice The block number of the last checkpointed block
    uint64 internal $lastCheckpointedBlock;

    /// @inheritdoc ICheckpointStorage
    function latestCheckpoint() public view returns (Checkpoint memory) {
        return _getCheckpoint($lastCheckpointedBlock);
    }

    /// @notice Get a checkpoint from storage
    function _getCheckpoint(uint64 blockNumber) internal view returns (Checkpoint memory) {
        return $_checkpoints[blockNumber];
    }

    /// @notice Insert a checkpoint into storage
    /// @dev This function updates the prev and next pointers of the latest checkpoint and the new checkpoint
    function _insertCheckpoint(Checkpoint memory checkpoint, uint64 blockNumber) internal {
        uint64 _lastCheckpointedBlock = $lastCheckpointedBlock;
        // Enforce strictly increasing checkpoint block numbers
        if (blockNumber <= _lastCheckpointedBlock) revert CheckpointBlockNotIncreasing();
        // Link new checkpoint to the previous checkpoint
        checkpoint.prev = _lastCheckpointedBlock;
        checkpoint.next = MAX_BLOCK_NUMBER;
        // Link previous checkpoint to the new checkpoint
        $_checkpoints[_lastCheckpointedBlock].next = blockNumber;
        // Write the new checkpoint
        $_checkpoints[blockNumber] = checkpoint;
        // Update the last checkpointed block
        $lastCheckpointedBlock = blockNumber;
    }

    /// @notice Calculate the tokens sold and proportion of input used for a fully filled bid between two checkpoints
    /// @dev This function MUST only be used for checkpoints where the bid's max price is strictly greater than the clearing price
    ///      because it uses lazy accounting to calculate the tokens filled
    /// @param upper The upper checkpoint
    /// @param startCheckpoint The start checkpoint of the bid
    /// @param bid The bid
    /// @return tokensFilled The tokens sold
    /// @return currencySpentQ96 The amount of currency spent in Q96 form
    function _accountFullyFilledCheckpoints(Checkpoint memory upper, Checkpoint memory startCheckpoint, Bid memory bid)
        internal
        pure
        returns (uint256 tokensFilled, uint256 currencySpentQ96)
    {
        return CheckpointAccountingLib.accountFullyFilledCheckpoints(upper, startCheckpoint, bid);
    }

    /// @notice Calculate the tokens sold and currency spent for a partially filled bid
    /// @param bid The bid
    /// @param tickDemandQ96 The total demand at the tick
    /// @param currencyRaisedAtClearingPriceQ96_X7 The cumulative supply sold to the clearing price
    /// @return tokensFilled The tokens sold
    /// @return currencySpentQ96 The amount of currency spent in Q96 form
    function _accountPartiallyFilledCheckpoints(
        Bid memory bid,
        uint256 tickDemandQ96,
        ValueX7 currencyRaisedAtClearingPriceQ96_X7
    ) internal pure returns (uint256 tokensFilled, uint256 currencySpentQ96) {
        return CheckpointAccountingLib.accountPartiallyFilledCheckpoints(
            bid, tickDemandQ96, currencyRaisedAtClearingPriceQ96_X7
        );
    }

    /// @inheritdoc ICheckpointStorage
    function lastCheckpointedBlock() external view returns (uint64) {
        return $lastCheckpointedBlock;
    }

    /// @inheritdoc ICheckpointStorage
    function checkpoints(uint64 blockNumber) external view returns (Checkpoint memory) {
        return $_checkpoints[blockNumber];
    }
}

// src/interfaces/IContinuousClearingAuction.sol

/// @notice Parameters for the auction
/// @dev token and totalSupply are passed as constructor arguments
struct AuctionParameters {
    address currency; // token to raise funds in. Use address(0) for ETH
    address tokensRecipient; // address to receive leftover tokens
    address fundsRecipient; // address to receive all raised funds
    uint64 startBlock; // Block which the first step starts
    uint64 endBlock; // When the auction finishes
    uint64 claimBlock; // Block when the auction can claimed
    uint256 tickSpacing; // Fixed granularity for prices
    address validationHook; // Optional hook called before a bid
    uint256 floorPrice; // Starting floor price for the auction
    uint128 requiredCurrencyRaised; // Amount of currency required to be raised for the auction to graduate
    bytes auctionStepsData; // Packed bytes describing token issuance schedule
}

/// @notice Interface for the ContinuousClearingAuction contract
interface IContinuousClearingAuction is
    ILBPInitializer,
    ICheckpointStorage,
    ITickStorage,
    IStepStorage,
    ITokenCurrencyStorage,
    IBidStorage
{
    /// @notice Error thrown when the amount received is invalid
    error InvalidTokenAmountReceived();

    /// @notice Error thrown when an invalid value is deposited
    error InvalidAmount();
    /// @notice Error thrown when the bid owner is the zero address
    error BidOwnerCannotBeZeroAddress();
    /// @notice Error thrown when the bid price is below the clearing price
    error BidMustBeAboveClearingPrice();
    /// @notice Error thrown when the bid price is too high given the auction's total supply
    /// @param maxPrice The price of the bid
    /// @param maxBidPrice The max price allowed for a bid
    error InvalidBidPriceTooHigh(uint256 maxPrice, uint256 maxBidPrice);
    /// @notice Error thrown when the bid amount is too small
    error BidAmountTooSmall();
    /// @notice Error thrown when msg.value is non zero when currency is not ETH
    error CurrencyIsNotNative();
    /// @notice Error thrown when the auction is not started
    error AuctionNotStarted();
    /// @notice Error thrown when the tokens required for the auction have not been received
    error TokensNotReceived();
    /// @notice Error thrown when the claim block is before the end block
    error ClaimBlockIsBeforeEndBlock();
    /// @notice Error thrown when the floor price plus tick spacing is greater than the maximum bid price
    error FloorPriceAndTickSpacingGreaterThanMaxBidPrice(uint256 nextTick, uint256 maxBidPrice);
    /// @notice Error thrown when the floor price plus tick spacing would overflow a uint256
    error FloorPriceAndTickSpacingTooLarge();
    /// @notice Error thrown when the bid has already been exited
    error BidAlreadyExited();
    /// @notice Error thrown when the bid is higher than the clearing price
    error CannotExitBid();
    /// @notice Error thrown when the bid cannot be partially exited before the end block
    error CannotPartiallyExitBidBeforeEndBlock();
    /// @notice Error thrown when the last fully filled checkpoint hint is invalid
    error InvalidLastFullyFilledCheckpointHint();
    /// @notice Error thrown when the outbid block checkpoint hint is invalid
    error InvalidOutbidBlockCheckpointHint();
    /// @notice Error thrown when the bid is not claimable
    error NotClaimable();
    /// @notice Error thrown when the bids are not owned by the same owner
    error BatchClaimDifferentOwner(address expectedOwner, address receivedOwner);
    /// @notice Error thrown when the bid has not been exited
    error BidNotExited();
    /// @notice Error thrown when the bid cannot be partially exited before the auction has graduated
    error CannotPartiallyExitBidBeforeGraduation();
    /// @notice Error thrown when the token transfer fails
    error TokenTransferFailed();
    /// @notice Error thrown when the auction is not over
    error AuctionIsNotOver();
    /// @notice Error thrown when the end block is not checkpointed
    error AuctionIsNotFinalized();
    /// @notice Error thrown when the bid is too large
    error InvalidBidUnableToClear();
    /// @notice Error thrown when the auction has sold the entire total supply of tokens
    error AuctionSoldOut();
    /// @notice Error thrown when the tick price is not greater than the next active tick price
    error TickHintMustBeGreaterThanNextActiveTickPrice(uint256 tickPrice, uint256 nextActiveTickPrice);

    /// @notice Emitted when the tokens are received
    /// @param totalSupply The total supply of tokens received
    event TokensReceived(uint256 totalSupply);

    /// @notice Emitted when a bid is submitted
    /// @param id The id of the bid
    /// @param owner The owner of the bid
    /// @param price The price of the bid
    /// @param amount The amount of the bid
    event BidSubmitted(uint256 indexed id, address indexed owner, uint256 price, uint128 amount);

    /// @notice Emitted when a new checkpoint is created
    /// @param blockNumber The block number of the checkpoint
    /// @param clearingPrice The clearing price of the checkpoint
    /// @param cumulativeMps The cumulative percentage of total tokens allocated across all previous steps, represented in ten-millionths of the total supply (1e7 = 100%)
    event CheckpointUpdated(uint256 blockNumber, uint256 clearingPrice, uint24 cumulativeMps);

    /// @notice Emitted when the clearing price is updated
    /// @param blockNumber The block number when the clearing price was updated
    /// @param clearingPrice The new clearing price
    event ClearingPriceUpdated(uint256 blockNumber, uint256 clearingPrice);

    /// @notice Emitted when a bid is exited
    /// @param bidId The id of the bid
    /// @param owner The owner of the bid
    /// @param tokensFilled The amount of tokens filled
    /// @param currencyRefunded The amount of currency refunded
    event BidExited(uint256 indexed bidId, address indexed owner, uint256 tokensFilled, uint256 currencyRefunded);

    /// @notice Emitted when a bid is claimed
    /// @param bidId The id of the bid
    /// @param owner The owner of the bid
    /// @param tokensFilled The amount of tokens claimed
    event TokensClaimed(uint256 indexed bidId, address indexed owner, uint256 tokensFilled);

    /// @notice Submit a new bid
    /// @param maxPrice The maximum price the bidder is willing to pay
    /// @param amount The amount of the bid
    /// @param owner The owner of the bid
    /// @param prevTickPrice The price of the previous tick
    /// @param hookData Additional data to pass to the hook required for validation
    /// @return bidId The id of the bid
    function submitBid(uint256 maxPrice, uint128 amount, address owner, uint256 prevTickPrice, bytes calldata hookData)
        external
        payable
        returns (uint256 bidId);

    /// @notice Submit a new bid without specifying the previous tick price
    /// @dev It is NOT recommended to use this function unless you are sure that `maxPrice` is already initialized
    ///      as this function will iterate through every tick starting from the floor price if it is not.
    /// @param maxPrice The maximum price the bidder is willing to pay
    /// @param amount The amount of the bid
    /// @param owner The owner of the bid
    /// @param hookData Additional data to pass to the hook required for validation
    /// @return bidId The id of the bid
    function submitBid(uint256 maxPrice, uint128 amount, address owner, bytes calldata hookData)
        external
        payable
        returns (uint256 bidId);

    /// @notice Register a new checkpoint
    /// @dev This function is called every time a new bid is submitted above the current clearing price
    /// @dev If the auction is over, it returns the final checkpoint
    /// @return _checkpoint The checkpoint at the current block
    function checkpoint() external returns (Checkpoint memory _checkpoint);

    /// @notice Get the most up to date clearing price
    /// @dev This will be at least as up to date as the latest checkpoint. It can be incremented from calls to `forceIterateOverTicks`
    /// @dev Callers MUST ensure that the latest checkpoint is up to date before using this function.
    /// @dev Additionally, it is recommended to use this function instead of reading the clearingPrice from the latest checkpoint.
    /// @return The current clearing price in Q96 form
    function clearingPrice() external view returns (uint256);

    /// @notice Whether the auction has graduated as of the given checkpoint
    /// @dev The auction is considered graduated if the currency raised is greater than or equal to the required currency raised
    /// @dev Be aware that the latest checkpoint may be out of date
    /// @return bool True if the auction has graduated, false otherwise
    function isGraduated() external view returns (bool);

    /// @notice Get the currency raised at the last checkpointed block
    /// @dev This may be less than the balance of this contract if there are outstanding refunds for bidders
    /// @dev Be aware that the latest checkpoint may be out of date
    /// @return The currency raised
    function currencyRaised() external view returns (uint256);

    /// @notice Exit a bid
    /// @dev This function can only be used for bids where the max price is above the final clearing price after the auction has ended
    /// @param bidId The id of the bid
    function exitBid(uint256 bidId) external;

    /// @notice Exit a bid which has been partially filled
    /// @dev This function can be used only for partially filled bids. For fully filled bids, `exitBid` must be used
    /// @param bidId The id of the bid
    /// @param lastFullyFilledCheckpointBlock The last checkpointed block where the clearing price is strictly < bid.maxPrice
    /// @param outbidBlock The first checkpointed block where the clearing price is strictly > bid.maxPrice, or 0 if the bid is partially filled at the end of the auction
    function exitPartiallyFilledBid(uint256 bidId, uint64 lastFullyFilledCheckpointBlock, uint64 outbidBlock) external;

    /// @notice Claim tokens after the auction's claim block
    /// @notice The bid must be exited before claiming tokens
    /// @dev Anyone can claim tokens for any bid, the tokens are transferred to the bid owner
    /// @param bidId The id of the bid
    function claimTokens(uint256 bidId) external;

    /// @notice Claim tokens for multiple bids
    /// @dev Anyone can claim tokens for bids of the same owner, the tokens are transferred to the owner
    /// @dev A TokensClaimed event is emitted for each bid but only one token transfer will be made
    /// @param owner The owner of the bids
    /// @param bidIds The ids of the bids
    function claimTokensBatch(address owner, uint256[] calldata bidIds) external;

    /// @notice Withdraw all of the currency raised
    /// @dev Can be called by anyone after the auction has ended
    function sweepCurrency() external;

    /// @notice Implements IERC165.supportsInterface to signal support for the ILBPInitializer interface
    /// @param interfaceId The interface identifier to check
    function supportsInterface(bytes4 interfaceId) external view override(IERC165) returns (bool);

    /// @notice The currency being raised in the auction
    function currency() external view returns (address);

    /// @notice The token being sold in the auction
    function token() external view returns (address);

    /// @notice The total supply of tokens to sell
    function totalSupply() external view returns (uint128);

    /// @notice The recipient of any unsold tokens at the end of the auction
    function tokensRecipient() external view returns (address);

    /// @notice The recipient of the raised currency from the auction
    function fundsRecipient() external view returns (address);

    /// @notice The block at which the auction starts
    /// @return The starting block number
    function startBlock() external view override(ILBPInitializer) returns (uint64);

    /// @notice The block at which the auction ends
    /// @return The ending block number
    function endBlock() external view override(ILBPInitializer) returns (uint64);

    /// @notice The block at which the auction can be claimed
    function claimBlock() external view returns (uint64);

    /// @notice The address of the validation hook for the auction
    function validationHook() external view returns (IValidationHook);

    /// @notice Sweep any leftover tokens to the tokens recipient
    /// @dev This function can only be called after the auction has ended
    function sweepUnsoldTokens() external;

    /// @notice The currency raised as of the last checkpoint in Q96 representation, scaled up by X7
    /// @dev Most use cases will want to use `currencyRaised()` instead
    function currencyRaisedQ96_X7() external view returns (ValueX7);

    /// @notice The sum of demand in ticks above the clearing price
    function sumCurrencyDemandAboveClearingQ96() external view returns (uint256);

    /// @notice The total currency raised as of the last checkpoint in Q96 representation, scaled up by X7
    /// @dev Most use cases will want to use `totalCleared()` instead
    function totalClearedQ96_X7() external view returns (ValueX7);

    /// @notice The total tokens cleared as of the last checkpoint in uint256 representation
    function totalCleared() external view returns (uint256);
}

// src/ContinuousClearingAuction.sol

/// @title ContinuousClearingAuction
/// @custom:security-contact security@uniswap.org
/// @notice Implements a time weighted uniform clearing price auction
/// @dev Can be constructed directly or through the ContinuousClearingAuctionFactory. In either case, users must validate
///      that the auction parameters are correct and not incorrectly set.
contract ContinuousClearingAuction is
    BidStorage,
    CheckpointStorage,
    StepStorage,
    TickStorage,
    TokenCurrencyStorage,
    BlockNumberish,
    ReentrancyGuardTransient,
    IContinuousClearingAuction
{
    using FixedPointMathLib for *;
    using CurrencyLibrary for Currency;
    using BidLib for *;
    using StepLib for *;
    using CheckpointLib for Checkpoint;
    using ValidationHookLib for IValidationHook;
    using ValueX7Lib for *;

    /// @notice The maximum price which a bid can be submitted at
    /// @dev Set during construction using MaxBidPriceLib.maxBidPrice() based on TOTAL_SUPPLY
    uint256 public immutable MAX_BID_PRICE;
    /// @notice The block at which purchased tokens can be claimed
    uint64 internal immutable CLAIM_BLOCK;
    /// @notice An optional hook to be called before a bid is registered
    IValidationHook internal immutable VALIDATION_HOOK;

    /// @notice The total currency raised in the auction in Q96 representation, scaled up by X7
    ValueX7 internal $currencyRaisedQ96_X7;
    /// @notice The total tokens sold in the auction so far, in Q96 representation, scaled up by X7
    ValueX7 internal $totalClearedQ96_X7;
    /// @notice The sum of currency demand in ticks above the clearing price
    /// @dev This will increase every time a new bid is submitted, and decrease when bids are outbid.
    uint256 internal $sumCurrencyDemandAboveClearingQ96;
    /// @notice The most up to date clearing price, set on each call to `checkpoint`
    /// @dev This can be incremented manually by calling `forceIterateOverTicks`
    uint256 internal $clearingPrice;

    /// @notice Whether the TOTAL_SUPPLY of tokens has been received
    bool private $_tokensReceived;

    constructor(address _token, uint128 _totalSupply, AuctionParameters memory _parameters)
        StepStorage(_parameters.auctionStepsData, _parameters.startBlock, _parameters.endBlock)
        TokenCurrencyStorage(
            _token,
            _parameters.currency,
            _totalSupply,
            _parameters.tokensRecipient,
            _parameters.fundsRecipient,
            _parameters.requiredCurrencyRaised
        )
        TickStorage(_parameters.tickSpacing, _parameters.floorPrice)
    {
        CLAIM_BLOCK = _parameters.claimBlock;
        VALIDATION_HOOK = IValidationHook(_parameters.validationHook);

        if (CLAIM_BLOCK < END_BLOCK) revert ClaimBlockIsBeforeEndBlock();

        // See MaxBidPriceLib library for more details on the bid price calculations.
        MAX_BID_PRICE = MaxBidPriceLib.maxBidPrice(TOTAL_SUPPLY);
        // The floor price and tick spacing must allow for at least one tick above the floor price to be initialized
        if (_parameters.tickSpacing > MAX_BID_PRICE || _parameters.floorPrice > MAX_BID_PRICE - _parameters.tickSpacing)
        {
            revert FloorPriceAndTickSpacingGreaterThanMaxBidPrice(
                _parameters.floorPrice + _parameters.tickSpacing, MAX_BID_PRICE
            );
        }

        $clearingPrice = FLOOR_PRICE;
        emit ClearingPriceUpdated(_getBlockNumberish(), $clearingPrice);
    }

    /// @notice Modifier for functions which can only be called after the auction is over
    modifier onlyAfterAuctionIsOver() {
        if (_getBlockNumberish() < END_BLOCK) revert AuctionIsNotOver();
        _;
    }

    /// @notice Modifier for claim related functions which can only be called after the claim block
    modifier onlyAfterClaimBlock() {
        if (_getBlockNumberish() < CLAIM_BLOCK) revert NotClaimable();
        _;
    }

    /// @notice Modifier for functions which can only be called after the auction is started and the tokens have been received
    modifier onlyActiveAuction() {
        _onlyActiveAuction();
        _;
    }

    /// @notice Internal function to check if the auction is active
    /// @dev Submitting bids or checkpointing is not allowed unless the auction is active
    function _onlyActiveAuction() internal view {
        if (_getBlockNumberish() < START_BLOCK) revert AuctionNotStarted();
        if (!$_tokensReceived) revert TokensNotReceived();
    }

    /// @notice Modifier for functions which require the latest checkpoint to be up to date
    modifier ensureEndBlockIsCheckpointed() {
        if ($lastCheckpointedBlock != END_BLOCK) {
            checkpoint();
        }
        _;
    }

    /// @inheritdoc IDistributionContract
    function onTokensReceived() external {
        // Don't check balance or emit the TokensReceived event if the tokens have already been received
        if ($_tokensReceived) return;
        // Use the normal totalSupply value instead of the Q96 value
        if (TOKEN.balanceOf(address(this)) < TOTAL_SUPPLY) {
            revert InvalidTokenAmountReceived();
        }
        $_tokensReceived = true;
        emit TokensReceived(TOTAL_SUPPLY);
    }

    /// @inheritdoc ILBPInitializer
    /// @dev The calling contract must be aware that the values returned in this function for `currencyRaised` and `tokensSold`
    ///      may not be reflective of the actual values if the auction did not graduate.
    function lbpInitializationParams() external view returns (LBPInitializationParams memory params) {
        // Require that the auction has been checkpointed at the end block before returning initialization params
        if ($lastCheckpointedBlock != END_BLOCK) revert AuctionIsNotFinalized();

        return LBPInitializationParams({
            initialPriceX96: $clearingPrice, tokensSold: totalCleared(), currencyRaised: currencyRaised()
        });
    }

    /// @inheritdoc IContinuousClearingAuction
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == ILBP_INITIALIZER_INTERFACE_ID || interfaceId == IERC165.supportsInterface.selector;
    }

    /// @inheritdoc IContinuousClearingAuction
    function clearingPrice() external view returns (uint256) {
        return $clearingPrice;
    }

    /// @inheritdoc IContinuousClearingAuction
    function isGraduated() external view returns (bool) {
        return _isGraduated();
    }

    /// @notice Whether the auction has graduated as of the given checkpoint
    /// @dev The auction is considered `graudated` if the currency raised is greater than or equal to the required currency raised
    function _isGraduated() internal view returns (bool) {
        return ValueX7.unwrap($currencyRaisedQ96_X7) >= ValueX7.unwrap(REQUIRED_CURRENCY_RAISED_Q96_X7);
    }

    /// @inheritdoc IContinuousClearingAuction
    function currencyRaised() public view returns (uint256) {
        return _currencyRaised();
    }

    /// @notice Return the currency raised in uint256 representation
    /// @return The currency raised
    function _currencyRaised() internal view returns (uint256) {
        return $currencyRaisedQ96_X7.divUint256(FixedPoint96.Q96).scaleDownToUint256();
    }

    /// @notice Return a new checkpoint after advancing the current checkpoint by some `mps`
    ///         This function updates the cumulative values of the checkpoint, and
    ///         requires that the clearing price is up to date
    /// @param _checkpoint The checkpoint to sell tokens at its clearing price
    /// @param _deltaMps The number of mps to sell
    /// @return The checkpoint with all cumulative values updated
    function _sellTokensAtClearingPrice(Checkpoint memory _checkpoint, uint24 _deltaMps)
        internal
        returns (Checkpoint memory)
    {
        // Advance the auction by selling an additional `deltaMps` share of TOTAL_SUPPLY at the current clearing price.
        //
        // At a high level, the algorithm is:
        // 1) Assume all demand is strictly above the clearing price: currencyRaised = sumAboveClearingQ96 × deltaMps.
        // 2) If the clearing price is exactly on an initialized tick that has demand, account for the partially filled
        //    bids at the clearing tick. There are two ways to derive the at-clearing currencyRaised when the price is
        //    not rounded up:
        //       (A) total implied currencyRaised at the rounded-up price − contribution from above-clearing
        //       (B) tick demand at clearing × deltaMps
        //    If the clearing price was rounded up to the tick boundary, (A) can exceed (B); cap with min(A, B).

        uint256 priceQ96 = _checkpoint.clearingPrice;
        uint256 deltaMpsU = uint256(_deltaMps);
        uint256 sumAboveQ96 = $sumCurrencyDemandAboveClearingQ96;

        // The base case is where all demand sits strictly above the clearing price
        uint256 currencyRaisedDeltaQ96X7;
        unchecked {
            currencyRaisedDeltaQ96X7 = sumAboveQ96 * deltaMpsU; // Overflow prevented by _submitBid::InvalidBidUnableToClear()
        }

        // When the clearing price is a tick with non zero demand
        // bidders at that tick can be partially filled. We split the currencyRaised into:
        // - (1) above-clearing contribution (already computed) and
        // - (2) at-clearing contribution.
        if (priceQ96 % TICK_SPACING == 0) {
            uint256 demandAtPriceQ96 = _getTick(priceQ96).currencyDemandQ96;
            if (demandAtPriceQ96 > 0) {
                // Cache and rename the above-clearing contribution
                uint256 currencyRaisedAboveClearingQ96X7 = currencyRaisedDeltaQ96X7;

                // Total implied currencyRaised at the (potentially rounded-up) clearing price:
                // = TOTAL_SUPPLY × priceQ96 (Q96) × deltaMps (X7) = Q96*X7
                // Note: this will be an overestimate if the price is rounded up
                uint256 totalCurrencyForDeltaQ96X7;
                unchecked {
                    totalCurrencyForDeltaQ96X7 = (uint256(TOTAL_SUPPLY) * priceQ96) * deltaMpsU;
                }

                // (A) Derived contribution from the clearing tick by substracting
                //     the above-clearing contribution from the total implied currencyRaised
                uint256 calculatedCurrencyRaisedAtClearingQ96X7 =
                    totalCurrencyForDeltaQ96X7 - currencyRaisedAboveClearingQ96X7;

                // (B) Maximum possible currencyRaised from bids at the clearing tick, scaling the tick demand by deltaMps
                uint256 maximumCurrencyRaisedAtClearingQ96X7;
                unchecked {
                    maximumCurrencyRaisedAtClearingQ96X7 = demandAtPriceQ96 * deltaMpsU;
                }

                // If price was rounded up, (A) can exceed (B). In that case, currencyRaised from the clearing tick is bounded by actual
                // tick demand; take min((A), (B)). If the price was not rounded up, (A) == (B).
                uint256 currencyRaisedAtClearingQ96X7 = FixedPointMathLib.min(
                    calculatedCurrencyRaisedAtClearingQ96X7, maximumCurrencyRaisedAtClearingQ96X7
                );

                // Change in currency raised = currency raised at clearing + currency raised above clearing
                currencyRaisedDeltaQ96X7 = currencyRaisedAtClearingQ96X7 + currencyRaisedAboveClearingQ96X7;
                // Track cumulative currency raised exactly at this clearing price (used for partial exits)
                _checkpoint.currencyRaisedAtClearingPriceQ96_X7 = ValueX7.wrap(
                    ValueX7.unwrap(_checkpoint.currencyRaisedAtClearingPriceQ96_X7) + currencyRaisedAtClearingQ96X7
                );
            }
        }

        // Convert currency to tokens at price, rounding up, and update global cleared tokens.
        // Intentional round-up leaves a small amount of dust to sweep, ensuring cleared tokens never exceed TOTAL_SUPPLY
        // even when using rounded-up clearing prices on tick boundaries.
        uint256 tokensClearedQ96X7 = currencyRaisedDeltaQ96X7.fullMulDivUp(FixedPoint96.Q96, priceQ96);
        $totalClearedQ96_X7 = ValueX7.wrap(ValueX7.unwrap($totalClearedQ96_X7) + tokensClearedQ96X7);
        // Update global currency raised
        $currencyRaisedQ96_X7 = ValueX7.wrap(ValueX7.unwrap($currencyRaisedQ96_X7) + currencyRaisedDeltaQ96X7);

        _checkpoint.cumulativeMps += _deltaMps;
        // Harmonic-mean accumulator: add (mps / price) using the rounded-up clearing price for this increment
        _checkpoint.cumulativeMpsPerPrice += CheckpointLib.getMpsPerPrice(_deltaMps, priceQ96);
        return _checkpoint;
    }

    /// @notice Fast forward to the start of the current step and return the number of `mps` sold since the last checkpoint
    /// @param _blockNumber The current block number
    /// @param _lastCheckpointedBlock The block number of the last checkpointed block
    /// @return step The current step in the auction which contains `_blockNumber`
    /// @return deltaMps The number of `mps` sold between the last checkpointed block and the start of the current step
    function _advanceToStartOfCurrentStep(uint64 _blockNumber, uint64 _lastCheckpointedBlock)
        internal
        returns (AuctionStep memory step, uint24 deltaMps)
    {
        // Advance the current step until the current block is within the step
        // Start at the larger of the last checkpointed block or the start block of the current step
        step = $step;
        uint64 start = uint64(FixedPointMathLib.max(step.startBlock, _lastCheckpointedBlock));
        uint64 end = step.endBlock;

        uint24 mps = step.mps;
        while (_blockNumber > end) {
            uint64 blockDelta = end - start;
            unchecked {
                deltaMps += uint24(blockDelta * mps);
            }
            start = end;
            if (end == END_BLOCK) break;
            step = _advanceStep();
            mps = step.mps;
            end = step.endBlock;
        }
    }

    /// @notice Iterate to find the tick where the total demand at and above it is strictly less than the remaining supply in the auction
    /// @dev If the loop reaches the highest tick in the book, `nextActiveTickPrice` will be set to MAX_TICK_PTR
    /// @param _untilTickPrice The tick price to iterate until
    /// @return The new clearing price
    function _iterateOverTicksAndFindClearingPrice(uint256 _untilTickPrice) internal returns (uint256) {
        // The new clearing price can never be lower than the current clearing price
        uint256 minimumClearingPrice = $clearingPrice;

        // Place state variables on the stack to save gas
        bool updateStateVariables;
        uint256 sumCurrencyDemandAboveClearingQ96_ = $sumCurrencyDemandAboveClearingQ96;
        uint256 nextActiveTickPrice_ = $nextActiveTickPrice;

        /**
         * We have the current demand above the clearing price, and we want to see if it is enough to fully purchase
         * all of the remaining supply being sold at the nextActiveTickPrice. We only need to check `nextActiveTickPrice`
         * because we know that there are no bids in between the current clearing price and that price.
         *
         * Observe that we need a certain amount of collective demand to increase the auction from the floor price.
         * - This is equal to `totalSupply * floorPrice`
         *
         * If the auction was fully subscribed in the first block which it was active, then the total CURRENCY REQUIRED
         * at any given price is equal to totalSupply * p', where p' is that price.
         */
        uint256 clearingPrice_ = sumCurrencyDemandAboveClearingQ96_.divUp(TOTAL_SUPPLY);
        while (
            // Loop while the currency amount above the clearing price is greater than the required currency at `nextActiveTickPrice_`
            (nextActiveTickPrice_ != _untilTickPrice
                    && sumCurrencyDemandAboveClearingQ96_ >= TOTAL_SUPPLY * nextActiveTickPrice_)
                // If the demand above clearing rounds up to the `nextActiveTickPrice`, we need to keep iterating over ticks
                // This ensures that the `nextActiveTickPrice` is always the next initialized tick strictly above the clearing price
                || clearingPrice_ == nextActiveTickPrice_
        ) {
            Tick storage $nextActiveTick = _getTick(nextActiveTickPrice_);
            // Subtract the demand at the current nextActiveTick from the total demand
            sumCurrencyDemandAboveClearingQ96_ -= $nextActiveTick.currencyDemandQ96;
            // Save the previous next active tick price
            minimumClearingPrice = nextActiveTickPrice_;
            // Advance to the next tick
            nextActiveTickPrice_ = $nextActiveTick.next;
            clearingPrice_ = sumCurrencyDemandAboveClearingQ96_.divUp(TOTAL_SUPPLY);
            updateStateVariables = true;
        }
        // Set the values into storage if we found a new next active tick price
        if (updateStateVariables) {
            $sumCurrencyDemandAboveClearingQ96 = sumCurrencyDemandAboveClearingQ96_;
            $nextActiveTickPrice = nextActiveTickPrice_;
            emit NextActiveTickUpdated(nextActiveTickPrice_);
        }

        // The minimum clearing price is either the floor price or the last tick we iterated over.
        // With the exception of the first iteration, the minimum price is a lower bound on the clearing price
        // because we already verified that we had enough demand to purchase all of the remaining supply at that price.
        if (clearingPrice_ < minimumClearingPrice) {
            return minimumClearingPrice;
        }
        // Otherwise, return the calculated clearing price
        return clearingPrice_;
    }

    /// @notice Internal function for checkpointing at a specific block number
    /// @dev This updates the state of the auction accounting for the bids placed after the last checkpoint
    ///      Checkpoints are created at the top of each block with a new bid and does NOT include that bid
    ///      Because of this, we need to calculate what the new state of the Auction should be before updating
    ///      purely on the supply we will sell to the potentially updated `sumCurrencyDemandAboveClearingQ96` value
    /// @param _blockNumber The block number to checkpoint at
    function _checkpointAtBlock(uint64 _blockNumber) internal returns (Checkpoint memory _checkpoint) {
        uint64 lastCheckpointedBlock = $lastCheckpointedBlock;
        if (_blockNumber == lastCheckpointedBlock) return latestCheckpoint();

        _checkpoint = latestCheckpoint();

        // If there are no more remaining mps in the auction, we don't need to iterate over ticks
        // Or update the clearing price
        if (_checkpoint.remainingMpsInAuction() > 0) {
            // Iterate over all ticks until MAX_TICK_PTR to find the clearing price
            // This can revert with out of gas if there are a large number of ticks
            uint256 newClearingPrice = _iterateOverTicksAndFindClearingPrice(MAX_TICK_PTR);
            // checkpoint has the stale clearing price
            if (newClearingPrice != _checkpoint.clearingPrice) {
                // Set the new clearing price
                _checkpoint.clearingPrice = newClearingPrice;
                // Reset the currencyRaisedAtClearingPrice to zero since the clearing price has changed
                _checkpoint.currencyRaisedAtClearingPriceQ96_X7 = ValueX7.wrap(0);
                // Write the new cleraing price to storage
                $clearingPrice = newClearingPrice;
                emit ClearingPriceUpdated(_blockNumber, newClearingPrice);
            }
        }

        // Calculate the percentage of the supply that has been sold since the last checkpoint and the start of the current step
        (AuctionStep memory step, uint24 deltaMps) = _advanceToStartOfCurrentStep(_blockNumber, lastCheckpointedBlock);
        // `deltaMps` above is equal to the percentage of tokens sold up until the start of the current step.
        // If the last checkpointed block is more recent than the start of the current step, account for the percentage
        // sold since the last checkpointed block. Otherwise, add the percent sold since the start of the current step.
        uint64 blockDelta = _blockNumber - uint64(FixedPointMathLib.max(step.startBlock, lastCheckpointedBlock));
        unchecked {
            deltaMps += uint24(blockDelta * step.mps);
        }

        // Sell the percentage of outstanding tokens since the last checkpoint at the current clearing price
        _checkpoint = _sellTokensAtClearingPrice(_checkpoint, deltaMps);
        // Insert the checkpoint into storage, updating latest pointer and the linked list
        _insertCheckpoint(_checkpoint, _blockNumber);

        emit CheckpointUpdated(_blockNumber, _checkpoint.clearingPrice, _checkpoint.cumulativeMps);
    }

    /// @notice Return the final checkpoint of the auction
    /// @dev Only called when the auction is over
    function _getFinalCheckpoint() internal returns (Checkpoint memory) {
        return _checkpointAtBlock(END_BLOCK);
    }

    /// @notice Internal function for bid submission
    /// @dev Validates `maxPrice`, calls the validation hook (if set) and updates global state variables
    ///      For gas efficiency, `prevTickPrice` should be the price of the tick immediately before `maxPrice`.
    /// @dev Implementing functions must check that the actual value `amount` is received by the contract
    /// @return bidId The id of the created bid
    function _submitBid(
        uint256 _maxPrice,
        uint128 _amount,
        address _owner,
        uint256 _prevTickPrice,
        bytes calldata _hookData
    ) internal returns (uint256 bidId) {
        // Reject bids which would cause TOTAL_SUPPLY * maxPrice to overflow a uint256
        if (_maxPrice > MAX_BID_PRICE) revert InvalidBidPriceTooHigh(_maxPrice, MAX_BID_PRICE);

        // Call the validation hook and bubble up the revert reason if it reverts
        VALIDATION_HOOK.handleValidate(_maxPrice, _amount, _owner, msg.sender, _hookData);

        // Get the latest checkpoint before validating the bid
        uint64 currentBlockNumberIsh = uint64(_getBlockNumberish());
        Checkpoint memory _checkpoint = _checkpointAtBlock(currentBlockNumberIsh);
        // Revert if there are no more tokens to be sold
        if (_checkpoint.remainingMpsInAuction() == 0) revert AuctionSoldOut();
        // We don't allow bids to be submitted at or below the clearing price
        if (_maxPrice <= $clearingPrice) revert BidMustBeAboveClearingPrice();

        // Initialize the tick if needed. This will no-op if the tick is already initialized.
        _initializeTickIfNeeded(_prevTickPrice, _maxPrice);

        Bid memory bid;
        uint256 amountQ96 = uint256(_amount) << FixedPoint96.RESOLUTION;
        (bid, bidId) = _createBid(currentBlockNumberIsh, amountQ96, _owner, _maxPrice, _checkpoint.cumulativeMps);

        // Scale the amount according to the rest of the supply schedule, accounting for past blocks
        // This is only used in demand related internal calculations
        uint256 bidEffectiveAmountQ96 = bid.toEffectiveAmount();
        // Update the tick demand with the bid's scaled amount
        _updateTickDemand(_maxPrice, bidEffectiveAmountQ96);
        // Update the global sum of currency demand above the clearing price tracker
        // Per the validation checks above this bid must be above the clearing price
        $sumCurrencyDemandAboveClearingQ96 += bidEffectiveAmountQ96;

        // If the sum of demand above clearing price becomes large enough to overflow a multiplication an X7 value,
        // revert to prevent the bid from being submitted.
        if ($sumCurrencyDemandAboveClearingQ96 >= ConstantsLib.X7_UPPER_BOUND) {
            revert InvalidBidUnableToClear();
        }

        emit BidSubmitted(bidId, _owner, _maxPrice, _amount);
    }

    /// @notice Internal function for processing the exit of a bid
    /// @dev Given a bid, tokens filled and refund, process the transfers and refund
    ///      `exitedBlock` MUST be checked by the caller to prevent double spending
    /// @param _bidId The id of the bid to exit
    /// @param _tokensFilled The number of tokens filled
    /// @param _currencySpentQ96 The amount of currency the bid spent
    function _processExit(uint256 _bidId, uint256 _tokensFilled, uint256 _currencySpentQ96) internal {
        Bid storage $bid = _getBid(_bidId);
        address owner = $bid.owner;

        uint256 bidAmountQ96 = $bid.amountQ96;
        // In edge cases where a bid spends all of its currency across fully filled and partially filled checkpoints,
        // the sum of currencySpent can be rounded up to one wei more than the bid amount. We clamp the refund to the bid amount.
        uint256 refund = FixedPointMathLib.saturatingSub(bidAmountQ96, _currencySpentQ96) >> FixedPoint96.RESOLUTION;

        $bid.tokensFilled = _tokensFilled;
        $bid.exitedBlock = uint64(_getBlockNumberish());

        if (refund > 0) {
            CURRENCY.transfer(owner, refund);
        }

        emit BidExited(_bidId, owner, _tokensFilled, refund);
    }

    /// @inheritdoc IContinuousClearingAuction
    function checkpoint() public onlyActiveAuction returns (Checkpoint memory) {
        uint64 currentBlockNumberIsh = uint64(_getBlockNumberish());
        if (currentBlockNumberIsh > END_BLOCK) {
            return _getFinalCheckpoint();
        } else {
            return _checkpointAtBlock(currentBlockNumberIsh);
        }
    }

    /// @notice Manually iterate over ticks to update the clearing price
    /// @dev This is used to prevent DoS attacks which initialize a large number of ticks
    /// @param _untilTickPrice The tick price to iterate until
    function forceIterateOverTicks(uint256 _untilTickPrice) external onlyActiveAuction nonReentrant returns (uint256) {
        if (_untilTickPrice != MAX_TICK_PTR) {
            // Ensure that the price is at a tick boundary
            Tick storage $tick = _getTick(_untilTickPrice);
            // The tick must be initialized otherwise it will be an infinite loop
            if ($tick.next == 0) revert TickNotInitialized();
            // The untilTickPrice must be greater than the current next active tick price
            if (_untilTickPrice <= $nextActiveTickPrice) {
                revert TickHintMustBeGreaterThanNextActiveTickPrice(_untilTickPrice, $nextActiveTickPrice);
            }
        }
        uint256 newClearingPrice = _iterateOverTicksAndFindClearingPrice(_untilTickPrice);
        // Update the clearing price in storage if it has changed
        if (newClearingPrice != $clearingPrice) {
            $clearingPrice = newClearingPrice;
            emit ClearingPriceUpdated(_getBlockNumberish(), newClearingPrice);
        }
        return newClearingPrice;
    }

    /// @inheritdoc IContinuousClearingAuction
    /// @dev Bids can be submitted anytime between the startBlock and the endBlock.
    function submitBid(
        uint256 _maxPrice,
        uint128 _amount,
        address _owner,
        uint256 _prevTickPrice,
        bytes calldata _hookData
    ) public payable onlyActiveAuction nonReentrant returns (uint256) {
        // Bids cannot be submitted at the endBlock or after
        if (_getBlockNumberish() >= END_BLOCK) revert AuctionIsOver();
        if (_amount == 0) revert BidAmountTooSmall();
        if (_owner == address(0)) revert BidOwnerCannotBeZeroAddress();
        if (CURRENCY.isAddressZero()) {
            if (msg.value != _amount) revert InvalidAmount();
        } else {
            if (msg.value != 0) revert CurrencyIsNotNative();
            SafeTransferLib.permit2TransferFrom(Currency.unwrap(CURRENCY), msg.sender, address(this), _amount);
        }
        return _submitBid(_maxPrice, _amount, _owner, _prevTickPrice, _hookData);
    }

    /// @inheritdoc IContinuousClearingAuction
    /// @dev The call to `submitBid` checks `onlyActiveAuction` so it's not required on this function
    function submitBid(uint256 _maxPrice, uint128 _amount, address _owner, bytes calldata _hookData)
        external
        payable
        returns (uint256)
    {
        return submitBid(_maxPrice, _amount, _owner, FLOOR_PRICE, _hookData);
    }

    /// @inheritdoc IContinuousClearingAuction
    function exitBid(uint256 _bidId) external onlyAfterAuctionIsOver {
        Bid memory bid = _getBid(_bidId);
        if (bid.exitedBlock != 0) revert BidAlreadyExited();
        Checkpoint memory finalCheckpoint = _getFinalCheckpoint();
        if (!_isGraduated()) {
            // Fully refund the bid if the auction did not graduate, since it is over
            return _processExit(_bidId, 0, 0);
        }
        // Only bids with a maxPrice strictly above the final clearing price can be exited in this function
        if (bid.maxPrice <= finalCheckpoint.clearingPrice) revert CannotExitBid();

        // Calculate the tokens and currency spent from the fully filled checkpoints
        (uint256 tokensFilled, uint256 currencySpentQ96) =
            _accountFullyFilledCheckpoints(finalCheckpoint, _getCheckpoint(bid.startBlock), bid);

        _processExit(_bidId, tokensFilled, currencySpentQ96);
    }

    /// @inheritdoc IContinuousClearingAuction
    function exitPartiallyFilledBid(uint256 _bidId, uint64 _lastFullyFilledCheckpointBlock, uint64 _outbidBlock)
        external
    {
        // Checkpoint first as the validity of the hints depend on the latest state
        Checkpoint memory currentBlockCheckpoint = checkpoint();
        // Cache the current block number
        uint256 currentBlockNumberIsh = _getBlockNumberish();

        Bid memory bid = _getBid(_bidId);
        if (bid.exitedBlock != 0) revert BidAlreadyExited();

        // Prevent bids from being exited before graduation
        if (!_isGraduated()) {
            if (currentBlockNumberIsh >= END_BLOCK) {
                // If the auction is over, fully refund the bid
                return _processExit(_bidId, 0, 0);
            }
            revert CannotPartiallyExitBidBeforeGraduation();
        }

        uint256 bidMaxPrice = bid.maxPrice;
        uint64 bidStartBlock = bid.startBlock;

        Checkpoint memory lastFullyFilledCheckpoint = _getCheckpoint(_lastFullyFilledCheckpointBlock);
        // Since `lastFullyFilledCheckpointBlock` must be the last fully filled Checkpoint, it must be < bid.maxPrice
        // And the bid must be partially filled or outbid (clearingPrice >= bid.maxPrice) in the next Checkpoint.
        // `lastFullyFilledCheckpoint` MUST be at least the bid's startCheckpoint since new bids must be at or above the current clearing price.
        if (
            lastFullyFilledCheckpoint.clearingPrice >= bidMaxPrice
                || _getCheckpoint(lastFullyFilledCheckpoint.next).clearingPrice < bidMaxPrice
                || _lastFullyFilledCheckpointBlock < bidStartBlock
        ) {
            revert InvalidLastFullyFilledCheckpointHint();
        }

        // Calculate the tokens and currency spent for the fully filled checkpoints
        // If the bid is outbid in the same block it is submitted in, these two checkpoints will be identical.
        // The extra gas to check for this isn't worth it since the returned values will be 0.
        (uint256 tokensFilled, uint256 currencySpentQ96) =
            _accountFullyFilledCheckpoints(lastFullyFilledCheckpoint, _getCheckpoint(bidStartBlock), bid);

        // Upper checkpoint is the last checkpoint where the bid is partially filled
        Checkpoint memory upperCheckpoint;
        // If outbidBlock is not zero, the bid was outbid and the bidder is requesting an early exit before the end of the auction
        if (_outbidBlock != 0) {
            // If the provided hint is the current block, use the checkpoint on the stack instead of getting it from storage
            Checkpoint memory outbidCheckpoint;
            if (_outbidBlock == currentBlockNumberIsh) {
                outbidCheckpoint = currentBlockCheckpoint;
            } else {
                outbidCheckpoint = _getCheckpoint(_outbidBlock);
            }

            upperCheckpoint = _getCheckpoint(outbidCheckpoint.prev);
            // We require that the outbid checkpoint is > bid max price AND the checkpoint before it is <= bid max price, revert if either of these conditions are not met
            if (outbidCheckpoint.clearingPrice <= bidMaxPrice || upperCheckpoint.clearingPrice > bidMaxPrice) {
                revert InvalidOutbidBlockCheckpointHint();
            }
        } else {
            // The only other valid partial exit case is if the final clearing price is equal to the bid's maxPrice.
            // These bids can only be exited after the auction ends
            if (currentBlockNumberIsh < END_BLOCK) revert CannotPartiallyExitBidBeforeEndBlock();
            // Set the upper checkpoint to the current checkpoint, which is also the final checkpoint since we already validated that the auction is over
            upperCheckpoint = currentBlockCheckpoint;
            // Revert if the final checkpoint's clearing price is not equal to the bid's max price
            if (upperCheckpoint.clearingPrice != bidMaxPrice) {
                revert CannotExitBid();
            }
        }

        // If there is an `upperCheckpoint` that means that the bid had a period where it was partially filled.
        // From the logic above, `upperCheckpoint` now points to the last checkpoint where the clearingPrice == bidMaxPrice.
        // Because the clearing price can never decrease between checkpoints, and the fact that you cannot enter a bid
        // at or below the current clearing price, the bid MUST have been active during the entire partial fill period.
        // And `upperCheckpoint` tracks the cumulative currency raised at that clearing price since the first partially filled checkpoint.
        if (upperCheckpoint.clearingPrice == bidMaxPrice) {
            uint256 tickDemandQ96 = _getTick(bidMaxPrice).currencyDemandQ96;
            (uint256 partialTokensFilled, uint256 partialCurrencySpentQ96) = _accountPartiallyFilledCheckpoints(
                bid, tickDemandQ96, upperCheckpoint.currencyRaisedAtClearingPriceQ96_X7
            );
            // Add the tokensFilled and currencySpentQ96 from the partially filled checkpoints to the total
            tokensFilled += partialTokensFilled;
            currencySpentQ96 += partialCurrencySpentQ96;
        }

        _processExit(_bidId, tokensFilled, currencySpentQ96);
    }

    /// @inheritdoc IContinuousClearingAuction
    function claimTokens(uint256 _bidId) external onlyAfterClaimBlock ensureEndBlockIsCheckpointed {
        // Tokens cannot be claimed if the auction did not graduate
        if (!_isGraduated()) revert NotGraduated();

        (address owner, uint256 tokensFilled) = _internalClaimTokens(_bidId);

        if (tokensFilled > 0) {
            Currency.wrap(address(TOKEN)).transfer(owner, tokensFilled);
            emit TokensClaimed(_bidId, owner, tokensFilled);
        }
    }

    /// @inheritdoc IContinuousClearingAuction
    function claimTokensBatch(address _owner, uint256[] calldata _bidIds)
        external
        onlyAfterClaimBlock
        ensureEndBlockIsCheckpointed
    {
        // Tokens cannot be claimed if the auction did not graduate
        if (!_isGraduated()) revert NotGraduated();

        uint256 tokensFilled = 0;
        for (uint256 i = 0; i < _bidIds.length; i++) {
            (address bidOwner, uint256 bidTokensFilled) = _internalClaimTokens(_bidIds[i]);

            if (bidOwner != _owner) {
                revert BatchClaimDifferentOwner(bidOwner, _owner);
            }

            tokensFilled += bidTokensFilled;

            if (bidTokensFilled > 0) {
                emit TokensClaimed(_bidIds[i], bidOwner, bidTokensFilled);
            }
        }

        if (tokensFilled > 0) {
            Currency.wrap(address(TOKEN)).transfer(_owner, tokensFilled);
        }
    }

    /// @notice Internal function to claim tokens for a single bid
    /// @param _bidId The id of the bid
    /// @return owner The owner of the bid
    /// @return tokensFilled The amount of tokens filled
    function _internalClaimTokens(uint256 _bidId) internal returns (address owner, uint256 tokensFilled) {
        Bid storage $bid = _getBid(_bidId);
        if ($bid.exitedBlock == 0) revert BidNotExited();

        // Set return values
        owner = $bid.owner;
        tokensFilled = $bid.tokensFilled;

        // Set the tokens filled to 0
        $bid.tokensFilled = 0;
    }

    /// @inheritdoc IContinuousClearingAuction
    function sweepCurrency() external onlyAfterAuctionIsOver ensureEndBlockIsCheckpointed {
        // Cannot sweep if already swept
        if (sweepCurrencyBlock != 0) revert CannotSweepCurrency();
        // Cannot sweep currency if the auction has not graduated, as all of the Currency must be refunded
        if (!_isGraduated()) revert NotGraduated();
        _sweepCurrency(_getBlockNumberish(), _currencyRaised());
    }

    /// @inheritdoc IContinuousClearingAuction
    function sweepUnsoldTokens() external onlyAfterAuctionIsOver ensureEndBlockIsCheckpointed {
        if (sweepUnsoldTokensBlock != 0) revert CannotSweepTokens();
        uint256 unsoldTokens;
        if (_isGraduated()) {
            uint256 totalSupplyQ96 = uint256(TOTAL_SUPPLY) << FixedPoint96.RESOLUTION;
            unsoldTokens = totalSupplyQ96.scaleUpToX7().saturatingSub($totalClearedQ96_X7).divUint256(FixedPoint96.Q96)
                .scaleDownToUint256();
        } else {
            unsoldTokens = TOTAL_SUPPLY;
        }
        _sweepUnsoldTokens(_getBlockNumberish(), unsoldTokens);
    }

    // Getters
    /// @inheritdoc IContinuousClearingAuction
    function currency() external view returns (address) {
        return Currency.unwrap(CURRENCY);
    }

    /// @inheritdoc IContinuousClearingAuction
    function token() external view returns (address) {
        return address(TOKEN);
    }

    /// @inheritdoc IContinuousClearingAuction
    function totalSupply() external view returns (uint128) {
        return TOTAL_SUPPLY;
    }

    /// @inheritdoc IContinuousClearingAuction
    function tokensRecipient() external view returns (address) {
        return TOKENS_RECIPIENT;
    }

    /// @inheritdoc IContinuousClearingAuction
    function fundsRecipient() external view returns (address) {
        return FUNDS_RECIPIENT;
    }

    /// @inheritdoc IContinuousClearingAuction
    function startBlock() external view returns (uint64) {
        return START_BLOCK;
    }

    /// @inheritdoc IContinuousClearingAuction
    function endBlock() external view returns (uint64) {
        return END_BLOCK;
    }

    /// @inheritdoc IContinuousClearingAuction
    function claimBlock() external view returns (uint64) {
        return CLAIM_BLOCK;
    }

    /// @inheritdoc IContinuousClearingAuction
    function validationHook() external view returns (IValidationHook) {
        return VALIDATION_HOOK;
    }

    /// @inheritdoc IContinuousClearingAuction
    function currencyRaisedQ96_X7() external view returns (ValueX7) {
        return $currencyRaisedQ96_X7;
    }

    /// @inheritdoc IContinuousClearingAuction
    function sumCurrencyDemandAboveClearingQ96() external view returns (uint256) {
        return $sumCurrencyDemandAboveClearingQ96;
    }

    /// @inheritdoc IContinuousClearingAuction
    function totalClearedQ96_X7() external view returns (ValueX7) {
        return $totalClearedQ96_X7;
    }

    /// @inheritdoc IContinuousClearingAuction
    function totalCleared() public view returns (uint256) {
        return $totalClearedQ96_X7.divUint256(FixedPoint96.Q96).scaleDownToUint256();
    }
}
