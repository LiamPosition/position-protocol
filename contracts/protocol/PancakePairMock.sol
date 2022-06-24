// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "../interfaces/IUniswapV2Pair.sol";

contract PancakePairMock is IUniswapV2Pair {

    uint112 public lastReserve0;
    uint112 public lastReserve1;
    uint32 public lastBlockTimestampLast;

    function getReserves()
    external
    view
    returns (
        uint112 reserve0,
        uint112 reserve1,
        uint32 blockTimestampLast
    ) {
        return (lastReserve0, lastReserve1, lastBlockTimestampLast);
    }

    function setReserves(uint112 _reserve0, uint112 _reserve1) external {
        lastReserve0 = _reserve0;
        lastReserve1 = _reserve1;
        lastBlockTimestampLast = uint32(block.timestamp);
    }


    //    ######################################################
    //    ######################################################
    //    ######################################################
    //    ######################################################

    function name() external pure returns (string memory) {
        return "";
    }

    function symbol() external pure returns (string memory) {
        return "";
    }

    function decimals() external pure returns (uint8) {
        return 0;
    }

    function totalSupply() external view returns (uint256) {
        return 0;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return 0;
    }

    function allowance(address owner, address spender)
    external
    view
    returns (uint256) {
        return 0;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        return true;
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return 0;
    }

    function PERMIT_TYPEHASH() external pure returns (bytes32) {
        return 0;
    }

    function nonces(address owner) external view returns (uint256) {
        return 0;
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {

    }

    function MINIMUM_LIQUIDITY() external pure returns (uint256) {
        return 0;
    }

    function factory() external view returns (address) {
        return address(0);
    }

    function token0() external view returns (address) {
        return address(0);
    }

    function token1() external view returns (address) {
        return address(0);
    }

    function price0CumulativeLast() external view returns (uint256) {
        return 0;
    }

    function price1CumulativeLast() external view returns (uint256) {
        return 0;
    }

    function kLast() external view returns (uint256) {
        return 0;
    }

    function mint(address to) external returns (uint256 liquidity) {
        return 0;
    }

    function burn(address to)
    external
    returns (uint256 amount0, uint256 amount1) {
        return (0, 0);
    }

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external {

    }

    function skim(address to) external {

    }

    function sync() external {

    }

    function initialize(address, address) external {

    }
}
