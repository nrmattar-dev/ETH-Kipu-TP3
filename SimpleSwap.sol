// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

contract SimpleSwap is ERC20{

    uint DECIMALS_FACTOR = 10**18;
    uint MINIMUM_LIQUIDITY = 1000;    
    bool locked;
    struct DataForSwap {
        address tokenA;
        address tokenB;
        uint reserveA;
        uint reserveB;
        uint amountA;
        uint amountB;
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
        require(tokenA < tokenB, "Token order must be canonical");
    
        uint reserveA = reserve[tokenA][tokenB];
        uint reserveB = reserve[tokenB][tokenA];
        bool isInitialLiquidity = false;

        require((reserveA == 0 && reserveB == 0) || (reserveA > 0 && reserveB > 0), "Invalid reserve amount");

         if (reserveA==0 && reserveB==0)
        {
            amountA = amountADesired;
            amountB = amountBDesired;
            isInitialLiquidity = true;
            liquidity = calculateInitialLiquidity(amountA,amountB);            
        }
        else 
        {
            amountB = amountBDesired;
            amountA = amountBDesired * reserveA / reserveB;

            if ((amountA < amountAMin) || (amountA > amountADesired))
            {
                amountA = amountADesired;
                amountB = amountADesired * reserveB / reserveA;

                require(
                        (amountB >= amountBMin)
                        && 
                        (amountB <= amountBDesired)
                        ,"The output do not satisfy the input requirements");

            }
            
            liquidity = calculateExistingLiquidity(amountA, reserveA, amountB, reserveB);
        }

        addLiquidityTransact(tokenA,tokenB,msg.sender, to,amountA, amountB,liquidity,isInitialLiquidity);

        return (amountA,amountB,liquidity);

    }

    event LiquidityAdded (address indexed from, address indexed to, uint amountA, uint amountB, uint liquidity);

    function addLiquidityTransact ( address tokenA,
                                    address tokenB,
                                    address from,
                                    address to,
                                    uint amountA,
                                    uint amountB,
                                    uint liquidity, 
                                    bool isInitialLiquidity
                                    ) internal
    {
        IERC20(tokenA).safeTransferFrom(from, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(from, address(this), amountB);

        _mint(to, liquidity);

        if (isInitialLiquidity)
        {
            _mint(address(this), MINIMUM_LIQUIDITY); 
        }      

        reserve[tokenA][tokenB]+=amountA;
        reserve[tokenB][tokenA]+=amountB;        

        emit LiquidityAdded (from, to, amountA, amountB, liquidity);
    }

    function calculateInitialLiquidity(uint amountA, uint amountB) internal view returns (uint liquidity)
    {
            liquidity = sqrt(amountA*amountB) - MINIMUM_LIQUIDITY;
            require(liquidity > 0,"The amounts must be higher");
    }

    function calculateExistingLiquidity(uint amountA, uint reserveA, uint amountB, uint reserveB) internal view returns (uint liquidity)
    {
            uint256 totalSupplyLTK = totalSupply();
            uint256 liquidityA = amountA * totalSupplyLTK / reserveA;
            uint256 liquidityB = amountB * totalSupplyLTK / reserveB;
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
        require(tokenA != tokenB,"tokenA and tokenB cannot be iqual");
        require(liquidity > 0, "Cannot remove zero liquidity");
        require(tokenA < tokenB, "Token order must be canonical");

        uint256 totalSupplyLTK = totalSupply();
        
        uint reserveA = reserve[tokenA][tokenB];
        uint reserveB = reserve[tokenB][tokenA];

        amountA = liquidity*reserveA/totalSupplyLTK;
        amountB = liquidity*reserveB/totalSupplyLTK;

        require(amountA >= amountAMin,"amountA is lower than amountAMin");
        require(amountB >= amountBMin,"amountB is lower than amountBMin");

        _burn(msg.sender,liquidity);
        IERC20(tokenA).safeTransfer(to, amountA);
        IERC20(tokenB).safeTransfer(to, amountB);

        reserve[tokenA][tokenB]-=amountA;
        reserve[tokenB][tokenA]-=amountB;

        emit LiquidityRemoved (msg.sender, to, liquidity, amountA, amountB );

    }    

    event LiquidityRemoved (address indexed from, address indexed to, uint256 liquidity, uint256 amountA, uint256 amountB);

    function reorderTokensForSwap (address[] calldata path, uint amountIn) internal view returns (DataForSwap memory swap)
    {
        require(path[0] != path[1],"tokenA and tokenB cannot be iqual");

        bool reversed = path[0] > path[1];

        swap.tokenA = reversed ? path[1] : path[0];
        swap.tokenB = reversed ? path[0] : path[1];

        swap.reserveA = reversed ? reserve[swap.tokenB][swap.tokenA] : reserve[swap.tokenA][swap.tokenB];
        swap.reserveB = reversed ? reserve[swap.tokenA][swap.tokenB] : reserve[swap.tokenB][swap.tokenA];

        require(swap.reserveA > 0 && swap.reserveB > 0, "Reserves are empty");

        swap.amountA = amountIn;
        swap.amountB = (amountIn * swap.reserveB) / (swap.reserveA + amountIn);
    }

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
        
        DataForSwap memory swap = reorderTokensForSwap(path, amountIn);
        
        require(swap.amountB>= amountOutMin,"amountOut is lower than amountOutMin");

        swapExactTokensForTokensTransact(swap, msg.sender, to);

        amounts = new uint[](path.length);
        amounts[0] = swap.amountA;
        amounts[1] = swap.amountB;

        emit swapExecuted (msg.sender, to, path, amounts);

    }    

    function swapExactTokensForTokensTransact (DataForSwap memory swap, address from, address to) internal
    {
        IERC20(swap.tokenA).safeTransferFrom(from, address(this), swap.amountA);
        IERC20(swap.tokenB).safeTransfer(to, swap.amountB);
        
        reserve[swap.tokenA][swap.tokenB]+=swap.amountA;
        reserve[swap.tokenB][swap.tokenA]-=swap.amountB;
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
