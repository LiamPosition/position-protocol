pragma solidity ^0.8.0;

import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


import "./libraries/position/TickPosition.sol";
import "./libraries/position/LimitOrder.sol";
import "./libraries/position/LiquidityBitmap.sol";

import "hardhat/console.sol";

contract PositionManager is Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using TickPosition for TickPosition.Data;
    using LiquidityBitmap for mapping(int128 => uint256);
    uint256 public basisPoint = 100; //0.01
    uint256 public constant BASE_BASIC_POINT = 10000;

    struct SingleSlot {
        // percentage in point
        int128 pip;
        uint8 isFullBuy;
    }

    IERC20 quoteAsset;


    // Max finding word can be 3000
    int128 public maxFindingWordsIndex = 1000;

    SingleSlot public singleSlot;
    mapping(int128 => TickPosition.Data) public tickPosition;
    mapping(int128 => uint256) public tickStore;
    // a packed array of boolean, where liquidity is filled or not
    mapping(int128 => uint256) public liquidityBitmap;
    //    mapping(uint64 => LimitOrder.Data) orderQueue;
    event Swap(address account, uint256 indexed amountIn, uint256 indexed amountOut);
    event LimitOrderCreated(uint64 orderId, int128 pip, uint128 size, bool isBuy);
    event UpdateMaxFindingWordsIndex(int128 newMaxFindingWordsIndex);
    event UpdateBasicPoint(uint256 newBasicPoint);



    modifier whenNotPause(){
        //TODO implement
        _;
    }

    modifier onlyCounterParty(){
        //TODO implement
        _;
    }

    constructor(
        int128 initialPip,
        address _quoteAsset
    ) {
        singleSlot.pip = initialPip;
        quoteAsset = IERC20(_quoteAsset);

    }

    function getCurrentPip() public view returns (int128) {
        return singleSlot.pip;
    }

    function getPrice() public view returns (uint256) {
        return uint256(uint128(singleSlot.pip)) * BASE_BASIC_POINT / basisPoint;
    }

    function pipToPrice(int128 pip) public view returns (uint256) {
        return uint256(uint128(pip)) * BASE_BASIC_POINT / basisPoint;
    }


    function calcAdjustMargin(uint256 adjustMargin) public view returns (uint256) {
        return adjustMargin * BASE_BASIC_POINT;
    }

    function hasLiquidity(int128 pip) public view returns (bool) {
        return liquidityBitmap.hasLiquidity(pip);
    }

    function getPendingOrderDetail(int128 pip, uint64 orderId) public view returns (
        bool isFilled,
        bool isBuy,
        uint256 size,
        uint256 partialFilled
    ){
        (isFilled, isBuy, size, partialFilled) = tickPosition[pip].getQueueOrder(orderId);

        if (!liquidityBitmap.hasLiquidity(pip)) {
            isFilled = true;
            // Should return the latest partialFilled
            // in order to know how many quantity amount is filled to the limit order by market order
//            partialFilled = 0;
        }
        if (size != 0 && size == partialFilled) {
            isFilled = true;
        }
    }

    function currentPositionData(address _trader) external view returns (
        uint256 size,
        uint256 margin,
        uint256 openNotional
    ){
        //        return;
    }

    function currentPositionPrice(address _trader) internal view returns (uint256) {
        //get overage of ticks
        return 0;
    }

    function cancelLimitOrder(int128 pip, uint64 orderId) external returns (uint256) {
        tickPosition[pip].cancelLimitOrder(orderId);
        return 1;
    }

    function closeLimitOrder(int128 pip, uint64 orderId, uint256 _amountClose) external returns (uint256 amountClose) {
        amountClose = tickPosition[pip].closeLimitOrder(orderId, _amountClose);
    }


    function openLimitPosition(int128 pip, uint128 size, bool isBuy) external whenNotPause onlyCounterParty returns (uint64 orderId) {
        //        require(pip != singleSlot.pip, "!!");
        //call market order instead
        console.log("open limit position size", size);
        //        if (isBuy && singleSlot.pip != 0) {
        //            require(pip <= singleSlot.pip, "!B");
        //        } else {
        //            require(pip >= singleSlot.pip, "!S");
        //        }
        SingleSlot memory _singleSlot = singleSlot;
        //save gas
        if (isBuy && pip >= _singleSlot.pip) {
            // open market buy

        } else if (!isBuy && pip <= _singleSlot.pip) {
            //open market sell

        } else {
            // open limit only

        }
        //TODO validate pip
        // convert tick to price
        // save at that pip has how many liquidity
        bool hasLiquidity = liquidityBitmap.hasLiquidity(pip);
        orderId = tickPosition[pip].insertLimitOrder(uint120(size), hasLiquidity, isBuy);
        console.log("pip, hasLiquidity", uint256(uint128(pip)), hasLiquidity);
        if (!hasLiquidity) {
            //set the bit to mark it has liquidity
            liquidityBitmap.toggleSingleBit(pip, true);
        }
        emit LimitOrderCreated(orderId, pip, size, isBuy);
    }

    struct SwapState {
        uint256 remainingSize;
        // the tick associated with the current price
        int128 pip;
    }

    struct StepComputations {
        int128 pipNext;
    }

    enum CurrentLiquiditySide {
        NotSet,
        Buy,
        Sell
    }

    function openMarketPositionWithMaxPip(uint256 size, bool isBuy, uint128 maxPip) public whenNotPause onlyCounterParty returns (uint256 sizeOut, uint256 openNotional) {
        return _internalOpenMarketOrder(size, isBuy, maxPip);
    }

    function openMarketPosition(uint256 size, bool isBuy) external whenNotPause onlyCounterParty returns (uint256 sizeOut, uint256 openNotional) {
        return _internalOpenMarketOrder(size, isBuy, 0);
    }

    function _internalOpenMarketOrder(uint256 size, bool isBuy, uint128 maxPip) internal returns (uint256 sizeOut, uint256 openNotional) {
        console.log("gas before open market", gasleft());
        require(size != 0, "!S");
        // TODO lock
        // get current tick liquidity
        console.log("start market order, size: ", size, "is buy: ", isBuy);
        SingleSlot memory _initialSingleSlot = singleSlot;
        //save gas
        SwapState memory state = SwapState({
        remainingSize : size,
        pip : _initialSingleSlot.pip
        });
        int128 startPip;
        int128 startWord = _initialSingleSlot.pip >> 8;
        int128 wordIndex = startWord;
        bool isPartialFill;
        uint8 isFullBuy = 0;
        bool isSkipFirstPip;
        CurrentLiquiditySide currentLiquiditySide = CurrentLiquiditySide(_initialSingleSlot.isFullBuy);
        if (currentLiquiditySide != CurrentLiquiditySide.NotSet) {
            if (isBuy)
            // if buy and latest liquidity is buy. skip current pip
                isSkipFirstPip = currentLiquiditySide == CurrentLiquiditySide.Buy;
            else
            // if sell and latest liquidity is sell. skip current pip
                isSkipFirstPip = currentLiquiditySide == CurrentLiquiditySide.Sell;
        }
        while (state.remainingSize != 0) {
            console.log("while again");
            console.log("state pip", uint128(state.pip));
            StepComputations memory step;
            // find the next tick has liquidity
            (step.pipNext) = liquidityBitmap[wordIndex] != 0 ? liquidityBitmap.findHasLiquidityInOneWords(
                !isBuy ? (wordIndex < startWord ? 256 * wordIndex + 255 : state.pip) : (wordIndex > startWord ? 256 * wordIndex : state.pip),
                !isBuy
            ) : 0;
            console.log(">> wordIndex | liquidity | pipNext", uint128(wordIndex), liquidityBitmap[wordIndex], uint128(step.pipNext));

            if (step.pipNext == 0) {
                if (isBuy ? wordIndex > startWord + maxFindingWordsIndex : wordIndex < startWord - maxFindingWordsIndex) {
                    // no more next pip
                    // state pip back 1 pip
                    if (isBuy) {
                        state.pip--;
                    } else {
                        state.pip++;
                    }
                    break;
                }
                // increase word
                if (isBuy) {
                    wordIndex++;
                } else {
                    wordIndex--;
                }
            } else {
                if (!isSkipFirstPip) {
                    console.log("SWAP: state pip", uint128(state.pip));
                    console.log("SWAP: next pip", uint128(step.pipNext));
                    if (startPip == 0) startPip = step.pipNext;

                    // get liquidity at a tick index
                    uint128 liquidity = tickPosition[step.pipNext].liquidity;
                    console.log("SWAP: liquidity", uint256(liquidity));
                    console.log("SWAP: state.remainingSize", uint256(state.remainingSize));
                    //                  if (_initialSingleSlot.isFullBuy == 0 || isBuy != (_initialSingleSlot.isFullBuy == 2)) {
                    if (liquidity > state.remainingSize) {
                        // pip position will partially filled and stop here
                        console.log("partialFilled to pip | amount", uint256(uint128(step.pipNext)), uint256(state.remainingSize));
                        tickPosition[step.pipNext].partiallyFill(uint120(state.remainingSize));
                        openNotional += state.remainingSize * pipToPrice(step.pipNext);
                        state.remainingSize = 0;
                        state.pip = step.pipNext;
                        isPartialFill = true;
                        isFullBuy = uint8(!isBuy ? CurrentLiquiditySide.Buy : CurrentLiquiditySide.Sell);
                    } else if (state.remainingSize > liquidity) {
                        console.log("remain size > liquidity");
                        // order in that pip will be fulfilled
                        state.remainingSize = state.remainingSize - liquidity;
                        // NOTICE toggle current state to uninitialized after fulfill liquidity
                        //                    liquidityBitmap.toggleSingleBit(state.pip, false);
                        //                        liquidityBitmap.toggleSingleBit(step.pipNext, false);
                        // increase pip
                        openNotional += liquidity * pipToPrice(step.pipNext);
                        startWord = wordIndex;
                        state.pip = state.remainingSize > 0 ? (isBuy ? step.pipNext + 1 : step.pipNext - 1) : step.pipNext;
                    } else {
                        // remaining size = liquidity
                        // only 1 pip should be toggled, so we call it directly here
                        liquidityBitmap.toggleSingleBit(step.pipNext, false);
                        openNotional += state.remainingSize * pipToPrice(step.pipNext);
                        state.remainingSize = 0;
                        state.pip = step.pipNext;
                        isFullBuy = 0;
                    }
                } else {
                    isSkipFirstPip = false;
                    state.pip = isBuy ? step.pipNext + 1 : step.pipNext - 1;
                }
            }
        }
        if (_initialSingleSlot.pip != state.pip) {
            // all ticks in shifted range must be marked as filled
            if (!(isPartialFill && startPip == state.pip)) {
                // example pip partiallyFill in pip 200
                // current pip should be set to 200
                // but should not marked pip 200 doesn't have liquidity
                console.log("startPip > state.pip", uint256(uint128(startPip)), uint256(uint128(state.pip)));
                liquidityBitmap.unsetBitsRange(startPip, isPartialFill ? (isBuy ? state.pip - 1 : state.pip + 1) : state.pip);
            }
            // TODO write a checkpoint that we shift a range of ticks
        }
        singleSlot.pip = state.pip;
        singleSlot.isFullBuy = isFullBuy;
        sizeOut = size - state.remainingSize;
        console.log("********************************************************************************");
        console.log("Final size state: size, sizeOut, remainingSize", size, sizeOut, state.remainingSize);
        console.log("SWAP: final pip", uint256(uint128(state.pip)));
        console.log("********************************************************************************");
        console.log("gas left open market", gasleft());
        emit Swap(msg.sender, size, sizeOut);
    }

    function getQuoteAsset() public view returns (IERC20) {
        return quoteAsset;
    }


    function updateMaxFindingWordsIndex(int128 _newMaxFindingWordsIndex) public onlyOwner {
        maxFindingWordsIndex = _newMaxFindingWordsIndex;
        emit  UpdateMaxFindingWordsIndex(_newMaxFindingWordsIndex);
    }

    function updateBasicPoint(uint256 _newBasicPoint) public onlyOwner {
        basisPoint = _newBasicPoint;
        emit UpdateBasicPoint(_newBasicPoint);
    }
}
