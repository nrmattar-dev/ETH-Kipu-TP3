// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

contract SimpleSwap is ERC20{

    uint constant DECIMALS_FACTOR = 10**18;
    uint constant MINIMUM_LIQUIDITY = 1000;    
    bool locked;
    struct TokenPairData {
        address tokenA;
        address tokenB;
        uint reserveA;
        uint reserveB;
        uint amountA;
        uint amountB;
        bool reversed;
    }

    mapping(address => mapping(address => uint)) public reserve;

    constructor() ERC20("Liquidity Token ","LTK"){
    }
  

    modifier nonReentrant() {
        require(!locked, "No reentrancy");
        locked = true;
        _;
        locked = false;
    }

    modifier isNotExpired(uint deadline)
    {
        require(block.timestamp <= deadline, "Transaction expired");
        _;
    }


    function addLiquidity(  address tokenA, 
                            address tokenB, 
                            uint amountADesired, 
                            uint amountBDesired, 
                            uint amountAMin, 
                            uint amountBMin, 
                            address to, 
                            uint deadline)
                            external 
                            nonReentrant() 
                            isNotExpired(deadline) 
                            returns (
                                    uint amountA, 
                                    uint amountB, 
                                    uint liquidity)
    {        
       
        require(amountADesired>=amountAMin,"amountAMin must be less than or equal to amountADesired");
        require(amountBDesired>=amountBMin,"amountBMin must be less than or equal to amountBDesired");
        
        TokenPairData memory data = reorderTokens(tokenA,tokenB);
    
        data.reserveA = reserve[data.tokenA][data.tokenB];
        data.reserveB = reserve[data.tokenB][data.tokenA];

        bool isInitialLiquidity = false;

        require((data.reserveA == 0 && data.reserveB == 0) || (data.reserveA > 0 && data.reserveB > 0), "Invalid reserve amount");

         if (data.reserveA==0 && data.reserveB==0)
        {
            data.amountA = amountADesired;
            data.amountB = amountBDesired;
            isInitialLiquidity = true;

            liquidity = calculateInitialLiquidity(data);  

        }
        else 
        {
            data.amountB = amountBDesired;
            data.amountA = amountBDesired * data.reserveA / data.reserveB;

            if ((data.amountA < amountAMin) || (data.amountA > amountADesired))
            {
                data.amountA = amountADesired;
                data.amountB = amountADesired * data.reserveB / data.reserveA;

                require(
                        (data.amountB >= amountBMin)
                        && 
                        (data.amountB <= amountBDesired)
                        ,"The output do not satisfy the input requirements");

            }
            
            liquidity = calculateExistingLiquidity(data);
        }

        addLiquidityTransact(msg.sender, to, data, liquidity, isInitialLiquidity);

        amountA = data.amountA;
        amountB = data.amountB;

        return (amountA,amountB,liquidity);

    }

    event LiquidityAdded (address indexed from, address indexed to, uint amountA, uint amountB, uint liquidity);

    function addLiquidityTransact ( address from,
                                    address to,
                                    TokenPairData memory data,
                                    uint liquidity, 
                                    bool isInitialLiquidity
                                    ) internal
    {
        IERC20(data.tokenA).safeTransferFrom(from, address(this), data.amountA);
        IERC20(data.tokenB).safeTransferFrom(from, address(this), data.amountB);

        _mint(to, liquidity);

        if (isInitialLiquidity)
        {
            _mint(address(this), MINIMUM_LIQUIDITY); 
        }      

        reserve[data.tokenA][data.tokenB]+=data.amountA;
        reserve[data.tokenB][data.tokenA]+=data.amountB;        

        emit LiquidityAdded (from, to, data.amountA, data.amountB, liquidity);
    }

    function calculateInitialLiquidity(TokenPairData memory data) internal pure returns (uint liquidity)
    {
            liquidity = sqrt(data.amountA*data.amountB) - MINIMUM_LIQUIDITY;
            require(liquidity > 0,"The amounts must be higher");
    }

    function calculateExistingLiquidity(TokenPairData memory data) internal view returns (uint liquidity)
    {
            uint256 totalSupplyLTK = totalSupply();
            uint256 liquidityA = data.amountA * totalSupplyLTK / data.reserveA;
            uint256 liquidityB = data.amountB * totalSupplyLTK / data.reserveB;
            liquidity = (liquidityA < liquidityB) ? liquidityA : liquidityB;
        
    }

    function removeLiquidity(   address tokenA, 
                                address tokenB, 
                                uint liquidity, 
                                uint amountAMin, 
                                uint amountBMin,
                                address to, 
                                uint deadline) 
                                external 
                                    nonReentrant() 
                                    isNotExpired(deadline) 
                                    returns (
                                            uint amountA, 
                                            uint amountB)
    {
        require(liquidity > 0, "Cannot remove zero liquidity");
        
        TokenPairData memory data = reorderTokens(tokenA,tokenB);

        uint256 totalSupplyLTK = totalSupply();
        
        data.amountA = liquidity*data.reserveA/totalSupplyLTK;
        data.amountB = liquidity*data.reserveB/totalSupplyLTK;

        require(data.amountA >= amountAMin,"amountA is lower than amountAMin");
        require(data.amountB >= amountBMin,"amountB is lower than amountBMin");

        _burn(msg.sender,liquidity);
        IERC20(data.tokenA).safeTransfer(to, data.amountA);
        IERC20(data.tokenB).safeTransfer(to, data.amountB);

        reserve[data.tokenA][data.tokenB]-=data.amountA;
        reserve[data.tokenB][data.tokenA]-=data.amountB;

        amountA = data.amountA;
        amountB = data.amountB;

        emit LiquidityRemoved (msg.sender, to, liquidity, data.amountA, data.amountB );

    }    

    event LiquidityRemoved (address indexed from, address indexed to, uint256 liquidity, uint256 amountA, uint256 amountB);


    function swapExactTokensForTokens(
                            uint amountIn, 
                            uint amountOutMin, 
                            address[] calldata path, 
                            address to, 
                            uint deadline
                            ) external 
                            nonReentrant() 
                            isNotExpired(deadline) 
                            returns (uint[] memory amounts)
    {
        require(amountIn>0,"amountIn cannot be zero");
        require(amountOutMin>0,"amountOutMin cannot be zero");
        require(path.length==2,"At moment, the contract handle only one pair");
        
        TokenPairData memory data = reorderTokens(path[0],path[1]);
        
        require(data.reserveA > 0 && data.reserveB > 0, "Reserves are empty");

        uint amountOut = (amountIn * data.reserveB) / (data.reserveA + amountIn);
        data.amountA = data.reversed ? amountOut : amountIn;
        data.amountB = data.reversed ? amountIn : amountOut;

        require(data.amountB>= amountOutMin,"amountOut is lower than amountOutMin");

        swapExactTokensForTokensTransact(data, msg.sender, to);

        amounts = new uint[](path.length);
        if (data.reversed) {
            amounts[0] = data.amountB; // amountIn del token original (path[0])
            amounts[1] = data.amountA; // amountOut del token destino (path[1])
        } else {
            amounts[0] = data.amountA;
            amounts[1] = data.amountB;
        }

        emit swapExecuted (msg.sender, to, path, amounts);

    }    


    function reorderTokens (address tokenA, address tokenB) internal view returns (TokenPairData memory data)
    {
        require(tokenA != tokenB,"tokenA and tokenB cannot be iqual");

        data.reversed = tokenA > tokenB;

        data.tokenA = data.reversed ? tokenB : tokenA;
        data.tokenB = data.reversed ? tokenA : tokenB;

        data.reserveA = data.reversed ? reserve[data.tokenB][data.tokenA] : reserve[data.tokenA][data.tokenB];
        data.reserveB = data.reversed ? reserve[data.tokenA][data.tokenB] : reserve[data.tokenB][data.tokenA];

        

    }

    function swapExactTokensForTokensTransact (TokenPairData memory data, address from, address to) internal
    {

        if (data.reversed)
        {
            IERC20(data.tokenA).safeTransfer(to, data.amountA);
            IERC20(data.tokenB).safeTransferFrom(from, address(this), data.amountB);
            reserve[data.tokenA][data.tokenB]-=data.amountB;           
            reserve[data.tokenB][data.tokenA]+=data.amountA;
        }
        else 
        {       
            IERC20(data.tokenA).safeTransferFrom(from, address(this), data.amountA);
            IERC20(data.tokenB).safeTransfer(to, data.amountB);                 
            reserve[data.tokenA][data.tokenB]+=data.amountA;
            reserve[data.tokenB][data.tokenA]-=data.amountB;
        }
    }

    event swapExecuted (address indexed from,  address indexed to, address[] path, uint[] amounts);


    function getPrice(address tokenA, address tokenB) public view returns (uint price)
    {
        uint reserveA = reserve[tokenA][tokenB];
        uint reserveB = reserve[tokenB][tokenA];

        require(reserveA>0 && reserveB>0,"not enought reserves");

        return ((reserveB*DECIMALS_FACTOR)/(reserveA)); 
     }    

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut)
    {
        return (amountIn*reserveOut)/(reserveIn+amountIn);
    }       
    //This internal function returns the square root of a number
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0 || x == 1) {
            return x;
        }

        uint256 z = x / 2 + 1;
        uint256 y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }

        return y;
    }
             
}
