// SPDX-License-Identifier: MIT
pragma solidity =0.8.26 ^0.8.0 ^0.8.20 ^0.8.4;

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
            if iszero(
                gt(
                    or(iszero(x), eq(sdiv(z, x), y)),
                    lt(not(x), eq(y, shl(255, 1)))
                )
            ) {
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
    function rawMulWadUp(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256 z) {
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
    function rawDivWadUp(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256 z) {
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
            int256 k = ((x << 96) / 54916777467707473351141471128 + 2 ** 95) >>
                96;
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
                (uint256(r) *
                    3822833074963236453042738258902158003155416615667) >>
                    uint256(195 - k)
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
            r := xor(
                r,
                byte(
                    and(
                        0x1f,
                        shr(shr(r, x), 0x8421084210842108cc6318c6db6d54be)
                    ),
                    0xf8f9f9faf9fdfafbf9fdfcfdfafbfcfef9fafdfafcfcfbfefafafcfbffffffff
                )
            )

            // Reduce range of x to (1, 2) * 2**96
            // ln(2^k * x) = k * ln(2) + ln(x)
            x := shr(159, shl(r, x))

            // Evaluate using a (8, 8)-term rational approximation.
            // `p` is made monic, we will multiply by a scale factor later.
            // forgefmt: disable-next-item
            let p := sub(
                // This heavily nested expression is to avoid stack-too-deep for via-ir.
                sar(
                    96,
                    mul(
                        add(
                            43456485725739037958740375743393,
                            sar(
                                96,
                                mul(
                                    add(
                                        24828157081833163892658089445524,
                                        sar(
                                            96,
                                            mul(
                                                add(
                                                    3273285459638523848632254066296,
                                                    x
                                                ),
                                                x
                                            )
                                        )
                                    ),
                                    x
                                )
                            )
                        ),
                        x
                    )
                ),
                11111509109440967052023855526967
            )
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
            p := add(
                mul(
                    16597577552685614221487285958193947469193820559219878177908093499208371,
                    sub(159, r)
                ),
                p
            )
            // Add `ln(2**96 / 10**18) * 5**18 * 2**192`.
            p := add(
                600920179829731861736702779321621459595472258049074101567377883020018308,
                p
            )
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
                    l := add(
                        or(
                            l,
                            byte(
                                and(
                                    0x1f,
                                    shr(
                                        shr(l, v),
                                        0x8421084210842108cc6318c6db6d54be
                                    )
                                ),
                                0x0706060506020504060203020504030106050205030304010505030400000000
                            )
                        ),
                        49
                    )
                    w := sdiv(
                        shl(l, 7),
                        byte(sub(l, 31), 0x0303030303030303040506080c13)
                    )
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
                    do {
                        // If `x` is big, use Newton's so that intermediate values won't overflow.
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
            do {
                // Otherwise, use Halley's for faster convergence.
                int256 e = expWad(w);
                /// @solidity memory-safe-assembly
                assembly {
                    let t := add(w, wad)
                    let s := sub(mul(w, e), mul(x, wad))
                    w := sub(
                        w,
                        sdiv(
                            mul(s, wad),
                            sub(mul(e, t), sdiv(mul(add(t, wad), s), add(t, t)))
                        )
                    )
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
    function fullMulEq(
        uint256 a,
        uint256 b,
        uint256 x,
        uint256 y
    ) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := and(
                eq(mul(a, b), mul(x, y)),
                eq(mulmod(x, y, not(0)), mulmod(a, b, not(0)))
            )
        }
    }

    /// @dev Calculates `floor(x * y / d)` with full precision.
    /// Throws if result overflows a uint256 or when `d` is zero.
    /// Credit to Remco Bloemen under MIT license: https://2π.com/21/muldiv
    function fullMulDiv(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // 512-bit multiply `[p1 p0] = x * y`.
            // Compute the product mod `2**256` and mod `2**256 - 1`
            // then use the Chinese Remainder Theorem to reconstruct
            // the 512 bit result. The result is stored in two 256
            // variables such that `product = p1 * 2**256 + p0`.

            // Temporarily use `z` as `p0` to save gas.
            z := mul(x, y) // Lower 256 bits of `x * y`.
            for {

            } 1 {

            } {
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
                    z := mul(
                        // Divide [p1 p0] by the factors of two.
                        // Shift in bits from `p1` into `p0`. For this we need
                        // to flip `t` such that it is `2**256 / t`.
                        or(
                            mul(sub(p1, gt(r, z)), add(div(sub(0, t), t), 1)),
                            div(sub(z, r), t)
                        ),
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
    function fullMulDivUnchecked(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256 z) {
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
            z := mul(
                or(
                    mul(sub(p1, gt(r, z)), add(div(sub(0, t), t), 1)),
                    div(sub(z, r), t)
                ),
                mul(sub(2, mul(d, inv)), inv)
            )
        }
    }

    /// @dev Calculates `floor(x * y / d)` with full precision, rounded up.
    /// Throws if result overflows a uint256 or when `d` is zero.
    /// Credit to Uniswap-v3-core under MIT license:
    /// https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/FullMath.sol
    function fullMulDivUp(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256 z) {
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
    function fullMulDivN(
        uint256 x,
        uint256 y,
        uint8 n
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Temporarily use `z` as `p0` to save gas.
            z := mul(x, y) // Lower 256 bits of `x * y`. We'll call this `z`.
            for {

            } 1 {

            } {
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
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256 z) {
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
    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256 z) {
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
            for {
                let y := 1
            } 1 {

            } {
                let q := div(g, r)
                let t := g
                g := r
                r := sub(t, mul(r, q))
                let u := x
                x := y
                y := sub(u, mul(y, q))
                if iszero(r) {
                    break
                }
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
    function zeroFloorSub(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(gt(x, y), sub(x, y))
        }
    }

    /// @dev Returns `max(0, x - y)`.
    function saturatingSub(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(gt(x, y), sub(x, y))
        }
    }

    /// @dev Returns `min(2 ** 256 - 1, x + y)`.
    function saturatingAdd(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := or(sub(0, lt(add(x, y), x)), add(x, y))
        }
    }

    /// @dev Returns `min(2 ** 256 - 1, x * y)`.
    function saturatingMul(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := or(sub(or(iszero(x), eq(div(mul(x, y), x), y)), 1), mul(x, y))
        }
    }

    /// @dev Returns `condition ? x : y`, without branching.
    function ternary(
        bool condition,
        uint256 x,
        uint256 y
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), iszero(condition)))
        }
    }

    /// @dev Returns `condition ? x : y`, without branching.
    function ternary(
        bool condition,
        bytes32 x,
        bytes32 y
    ) internal pure returns (bytes32 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), iszero(condition)))
        }
    }

    /// @dev Returns `condition ? x : y`, without branching.
    function ternary(
        bool condition,
        address x,
        address y
    ) internal pure returns (address z) {
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
    function rpow(
        uint256 x,
        uint256 y,
        uint256 b
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(b, iszero(y)) // `0 ** 0 = 1`. Otherwise, `0 ** n = 0`.
            if x {
                z := xor(b, mul(xor(b, x), and(y, 1))) // `z = isEven(y) ? scale : x`
                let half := shr(1, b) // Divide `b` by 2.
                // Divide `y` by 2 every iteration.
                for {
                    y := shr(1, y)
                } y {
                    y := shr(1, y)
                } {
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
            z := div(
                shl(div(r, 3), shl(lt(0xf, shr(r, x)), 0xf)),
                xor(7, mod(r, 3))
            )
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
            for {

            } 1 {

            } {
                if iszero(shr(229, p)) {
                    if iszero(shr(199, p)) {
                        p := mul(p, 100000000000000000) // 10 ** 17.
                        break
                    }
                    p := mul(p, 100000000) // 10 ** 8.
                    break
                }
                if iszero(shr(249, p)) {
                    p := mul(p, 100)
                }
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
            for {

            } x {
                x := sub(x, 1)
            } {
                z := mul(z, x)
            }
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
            r := or(
                r,
                byte(
                    and(
                        0x1f,
                        shr(shr(r, x), 0x8421084210842108cc6318c6db6d54be)
                    ),
                    0x0706060506020504060203020504030106050205030304010505030400000000
                )
            )
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
            r := add(
                r,
                add(gt(x, 9), add(gt(x, 99), add(gt(x, 999), gt(x, 9999))))
            )
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
    function sci(
        uint256 x
    ) internal pure returns (uint256 mantissa, uint256 exponent) {
        /// @solidity memory-safe-assembly
        assembly {
            mantissa := x
            if mantissa {
                if iszero(mod(mantissa, 1000000000000000000000000000000000)) {
                    mantissa := div(
                        mantissa,
                        1000000000000000000000000000000000
                    )
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
    function unpackSci(
        uint256 packed
    ) internal pure returns (uint256 unpacked) {
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
    function clamp(
        uint256 x,
        uint256 minValue,
        uint256 maxValue
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, minValue), gt(minValue, x)))
            z := xor(z, mul(xor(z, maxValue), lt(maxValue, z)))
        }
    }

    /// @dev Returns `x`, bounded to `minValue` and `maxValue`.
    function clamp(
        int256 x,
        int256 minValue,
        int256 maxValue
    ) internal pure returns (int256 z) {
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
            for {
                z := x
            } y {

            } {
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
    function lerp(
        uint256 a,
        uint256 b,
        uint256 t,
        uint256 begin,
        uint256 end
    ) internal pure returns (uint256) {
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
    function lerp(
        int256 a,
        int256 b,
        int256 t,
        int256 begin,
        int256 end
    ) internal pure returns (int256) {
        if (begin > end) (t, begin, end) = (~t, ~begin, ~end);
        if (t <= begin) return a;
        if (t >= end) return b;
        // forgefmt: disable-next-item
        unchecked {
            if (b >= a)
                return
                    int256(
                        uint256(a) +
                            fullMulDiv(
                                uint256(b - a),
                                uint256(t - begin),
                                uint256(end - begin)
                            )
                    );
            return
                int256(
                    uint256(a) -
                        fullMulDiv(
                            uint256(a - b),
                            uint256(t - begin),
                            uint256(end - begin)
                        )
                );
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
    function rawAddMod(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := addmod(x, y, d)
        }
    }

    /// @dev Returns `(x * y) % d`, return 0 if `d` if zero.
    function rawMulMod(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256 z) {
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
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

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
    function validate(
        uint256 maxPrice,
        uint128 amount,
        address owner,
        address sender,
        bytes calldata hookData
    ) external;
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
    function parse(
        bytes8 data
    ) internal pure returns (uint24 mps, uint40 blockDelta) {
        mps = uint24(bytes3(data));
        blockDelta = uint40(uint64(data));
    }

    /// @notice Load a word at `offset` from data and parse it into mps and blockDelta
    function get(
        bytes memory data,
        uint256 offset
    ) internal pure returns (uint24 mps, uint40 blockDelta) {
        // Offset cannot be greater than the data length
        if (offset >= data.length) revert StepLib__InvalidOffsetTooLarge();
        // Offset must be a multiple of a step (uint64 -  uint24|uint40)
        if (offset % UINT64_SIZE != 0)
            revert StepLib__InvalidOffsetNotAtStepBoundary();

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
    function mpsRemainingInAuctionAfterSubmission(
        Bid memory bid
    ) internal pure returns (uint24) {
        return ConstantsLib.MPS - bid.startCumulativeMps;
    }

    /// @notice Scale a bid amount to its effective amount over the remaining percentage of the auction
    ///         This is an important normalization step to ensure that we can calculate the currencyRaised
    ///         when cumulative demand is less than supply using the original supply schedule.
    /// @param bid The bid to scale
    /// @return The scaled amount
    function toEffectiveAmount(Bid memory bid) internal pure returns (uint256) {
        uint24 mpsRemainingInAuction = bid
            .mpsRemainingInAuctionAfterSubmission();
        if (mpsRemainingInAuction == 0) revert MpsRemainingIsZero();
        return (bid.amountQ96 * ConstantsLib.MPS) / mpsRemainingInAuction;
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
            assembly ("memory-safe") {
                // Transfer the ETH and revert if it fails.
                success := call(gas(), to, amount, 0, 0, 0, 0)
            }
            // revert with NativeTransferFailed
            if (!success) {
                revert NativeTransferFailed();
            }
        } else {
            assembly ("memory-safe") {
                // Get a pointer to some free memory.
                let fmp := mload(0x40)

                // Write the abi-encoded calldata into memory, beginning with the function selector.
                mstore(
                    fmp,
                    0xa9059cbb00000000000000000000000000000000000000000000000000000000
                )
                mstore(
                    add(fmp, 4),
                    and(to, 0xffffffffffffffffffffffffffffffffffffffff)
                ) // Append and mask the "to" argument.
                mstore(add(fmp, 36), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

                success := and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(
                        and(eq(mload(0), 1), gt(returndatasize(), 31)),
                        iszero(returndatasize())
                    ),
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

    function balanceOf(
        Currency currency,
        address owner
    ) internal view returns (uint256) {
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
    error InvalidEndBlockGivenStepData(
        uint64 actualEndBlock,
        uint64 expectedEndBlock
    );

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
bytes4 constant ILBP_INITIALIZER_INTERFACE_ID = type(ILBPInitializer)
    .interfaceId;

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
    function lbpInitializationParams()
        external
        view
        returns (LBPInitializationParams memory params);

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

// src/libraries/ValueX7Lib.sol

/// @notice A ValueX7 is a uint256 value that has been multiplied by MPS
/// @dev X7 values are used for demand values to avoid intermediate division by MPS
type ValueX7 is uint256;

using {saturatingSub, divUint256} for ValueX7 global;

/// @notice Subtract two ValueX7 values, returning zero on underflow.
/// @dev Wrapper around FixedPointMathLib.saturatingSub
function saturatingSub(ValueX7 a, ValueX7 b) pure returns (ValueX7) {
    return
        ValueX7.wrap(
            FixedPointMathLib.saturatingSub(
                ValueX7.unwrap(a),
                ValueX7.unwrap(b)
            )
        );
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
    function remainingMpsInAuction(
        Checkpoint memory _checkpoint
    ) internal pure returns (uint24) {
        return ConstantsLib.MPS - _checkpoint.cumulativeMps;
    }

    /// @notice Calculate the supply to price ratio. Will return zero if `price` is zero
    /// @dev This function returns a value in Q96 form
    /// @param mps The number of supply mps sold
    /// @param price The price they were sold at
    /// @return the ratio
    function getMpsPerPrice(
        uint24 mps,
        uint256 price
    ) internal pure returns (uint256) {
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
    function checkpoints(
        uint64 blockNumber
    ) external view returns (Checkpoint memory);
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
    error FloorPriceAndTickSpacingGreaterThanMaxBidPrice(
        uint256 nextTick,
        uint256 maxBidPrice
    );
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
    error BatchClaimDifferentOwner(
        address expectedOwner,
        address receivedOwner
    );
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
    error TickHintMustBeGreaterThanNextActiveTickPrice(
        uint256 tickPrice,
        uint256 nextActiveTickPrice
    );

    /// @notice Emitted when the tokens are received
    /// @param totalSupply The total supply of tokens received
    event TokensReceived(uint256 totalSupply);

    /// @notice Emitted when a bid is submitted
    /// @param id The id of the bid
    /// @param owner The owner of the bid
    /// @param price The price of the bid
    /// @param amount The amount of the bid
    event BidSubmitted(
        uint256 indexed id,
        address indexed owner,
        uint256 price,
        uint128 amount
    );

    /// @notice Emitted when a new checkpoint is created
    /// @param blockNumber The block number of the checkpoint
    /// @param clearingPrice The clearing price of the checkpoint
    /// @param cumulativeMps The cumulative percentage of total tokens allocated across all previous steps, represented in ten-millionths of the total supply (1e7 = 100%)
    event CheckpointUpdated(
        uint256 blockNumber,
        uint256 clearingPrice,
        uint24 cumulativeMps
    );

    /// @notice Emitted when the clearing price is updated
    /// @param blockNumber The block number when the clearing price was updated
    /// @param clearingPrice The new clearing price
    event ClearingPriceUpdated(uint256 blockNumber, uint256 clearingPrice);

    /// @notice Emitted when a bid is exited
    /// @param bidId The id of the bid
    /// @param owner The owner of the bid
    /// @param tokensFilled The amount of tokens filled
    /// @param currencyRefunded The amount of currency refunded
    event BidExited(
        uint256 indexed bidId,
        address indexed owner,
        uint256 tokensFilled,
        uint256 currencyRefunded
    );

    /// @notice Emitted when a bid is claimed
    /// @param bidId The id of the bid
    /// @param owner The owner of the bid
    /// @param tokensFilled The amount of tokens claimed
    event TokensClaimed(
        uint256 indexed bidId,
        address indexed owner,
        uint256 tokensFilled
    );

    /// @notice Submit a new bid
    /// @param maxPrice The maximum price the bidder is willing to pay
    /// @param amount The amount of the bid
    /// @param owner The owner of the bid
    /// @param prevTickPrice The price of the previous tick
    /// @param hookData Additional data to pass to the hook required for validation
    /// @return bidId The id of the bid
    function submitBid(
        uint256 maxPrice,
        uint128 amount,
        address owner,
        uint256 prevTickPrice,
        bytes calldata hookData
    ) external payable returns (uint256 bidId);

    /// @notice Submit a new bid without specifying the previous tick price
    /// @dev It is NOT recommended to use this function unless you are sure that `maxPrice` is already initialized
    ///      as this function will iterate through every tick starting from the floor price if it is not.
    /// @param maxPrice The maximum price the bidder is willing to pay
    /// @param amount The amount of the bid
    /// @param owner The owner of the bid
    /// @param hookData Additional data to pass to the hook required for validation
    /// @return bidId The id of the bid
    function submitBid(
        uint256 maxPrice,
        uint128 amount,
        address owner,
        bytes calldata hookData
    ) external payable returns (uint256 bidId);

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
    function exitPartiallyFilledBid(
        uint256 bidId,
        uint64 lastFullyFilledCheckpointBlock,
        uint64 outbidBlock
    ) external;

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
    function claimTokensBatch(
        address owner,
        uint256[] calldata bidIds
    ) external;

    /// @notice Withdraw all of the currency raised
    /// @dev Can be called by anyone after the auction has ended
    function sweepCurrency() external;

    /// @notice Implements IERC165.supportsInterface to signal support for the ILBPInitializer interface
    /// @param interfaceId The interface identifier to check
    function supportsInterface(
        bytes4 interfaceId
    ) external view override(IERC165) returns (bool);

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
    function startBlock()
        external
        view
        override(ILBPInitializer)
        returns (uint64);

    /// @notice The block at which the auction ends
    /// @return The ending block number
    function endBlock()
        external
        view
        override(ILBPInitializer)
        returns (uint64);

    /// @notice The block at which the auction can be claimed
    function claimBlock() external view returns (uint64);

    /// @notice The maximum allowed bid price, derived from the total supply
    function MAX_BID_PRICE() external view returns (uint256);

    /// @notice The address of the validation hook for the auction
    function validationHook() external view returns (IValidationHook);

    /// @notice Sweep any leftover tokens to the tokens recipient
    /// @dev This function can only be called after the auction has ended
    function sweepUnsoldTokens() external;

    /// @notice The currency raised as of the last checkpoint in Q96 representation, scaled up by X7
    /// @dev Most use cases will want to use `currencyRaised()` instead
    function currencyRaisedQ96_X7() external view returns (ValueX7);

    /// @notice The sum of demand in ticks above the clearing price
    function sumCurrencyDemandAboveClearingQ96()
        external
        view
        returns (uint256);

    /// @notice The total currency raised as of the last checkpoint in Q96 representation, scaled up by X7
    /// @dev Most use cases will want to use `totalCleared()` instead
    function totalClearedQ96_X7() external view returns (ValueX7);

    /// @notice The total tokens cleared as of the last checkpoint in uint256 representation
    function totalCleared() external view returns (uint256);
}

// src/lens/AuctionStateLens.sol

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
    function state(
        IContinuousClearingAuction auction
    ) external returns (AuctionState memory) {
        try this.revertWithState(auction) {} catch (bytes memory reason) {
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
                sumCurrencyDemandAboveClearingQ96: auction
                    .sumCurrencyDemandAboveClearingQ96()
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
    function parseRevertReason(
        bytes memory reason
    ) internal pure returns (AuctionState memory) {
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
