// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/*
● Para aprobar con al menos 70 puntos:
○ Ejecutar el contrato de verificación con parámetros adecuados y optimización
de gas.
○ Consultar el smart contract de verificación si hay dudas.
○ Presentar en el formato solicitado.
○ Asegurar despliegue y verificación del contrato.
○ Incluir repositorio en GitHub con documentación en formato Markdown.

● Para notas entre 70 y 100 puntos:
○ Claridad y calidad del código.
○ Adherencia a buenas prácticas discutidas en clase y en el gitbook.
○ Comentarios en formato NatSpec.
○ Documentación, comentario, nombre de funciones y todo lo demás en inglés.
*/
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

contract SimpleSwap is ERC20{

    constructor() ERC20("Liquidity Token ","LTK"){}

    uint MINIMUM_LIQUIDITY = 1000;

    uint myDecimals = IERC20Metadata(address(this)).decimals();
    uint reserveA;
    uint reserveB;
    bool locked;

    mapping(address => uint) public reserve;

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

     function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to, uint deadline) external nonReentrant() isNotExpired(deadline) returns (uint amountA, uint amountB, uint liquidity)
    {
        require(amountADesired>=amountAMin,"amountAMin must be less than or equal to amountADesired");
        require(amountBDesired>=amountBMin,"amountBMin must be less than or equal to amountBDesired");
    
        reserveA = reserve[tokenA];
        reserveB = reserve[tokenB];

        require((reserveA == 0 && reserveB == 0) || (reserveA > 0 && reserveB > 0), "Invalid reserve amount");

         if (reserveA==0 && reserveB==0)
        {
            amountA = amountADesired;
            amountB = amountBDesired;
            
            liquidity = sqrt(amountADesired*amountBDesired) - MINIMUM_LIQUIDITY;
            require(liquidity > 0,"The amounts must be higher");
            _mint(address(0), MINIMUM_LIQUIDITY); 
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
            
            liquidity = calculateLiquidity(amountA, reserveA, amountB, reserveB);
        }

        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);

        reserve[tokenA]+=amountA;
        reserve[tokenB]+=amountB;

        _mint(to, liquidity);

        emit LiquidityAdded (msg.sender, amountA, amountB, to, liquidity);

        return (amountA,amountB,liquidity);

    }

    event LiquidityAdded (address indexed from, uint amountA, uint amountB, address to, uint liquidity);

    function calculateLiquidity(uint amountA, uint reserveA, uint amountB, uint reserveB) internal view returns (uint liquidity)
    {
            uint256 totalSupplyLTK = totalSupply();
            uint256 liquidityA = amountA * totalSupplyLTK / reserveA;
            uint256 liquidityB = amountB * totalSupplyLTK / reserveB;
            liquidity = (liquidityA < liquidityB) ? liquidityA : liquidityB;
        
    }

    function removeLiquidity(address tokenA, address tokenB, uint liquidity, uint amountAMin, uint amountBMin, address to, uint deadline) external nonReentrant() isNotExpired(deadline) returns (uint amountA, uint amountB)
    {
        require(liquidity > 0, "Cannot remove zero liquidity");

        uint256 totalSupplyLTK = totalSupply();
        
        reserveA = reserve[tokenA];
        reserveB = reserve[tokenB];

        amountA = liquidity*reserveA/totalSupplyLTK;
        amountB = liquidity*reserveB/totalSupplyLTK;

        require(amountA >= amountAMin,"amountA is lower than amountAMin");
        require(amountB >= amountBMin,"amountB is lower than amountBMin");

        _burn(msg.sender,liquidity);
        IERC20(tokenA).safeTransfer(to, amountA);
        IERC20(tokenB).safeTransfer(to, amountB);

        reserve[tokenA]-=amountA;
        reserve[tokenB]-=amountB;

        emit LiquidityRemoved (msg.sender, liquidity, to, amountA, amountB );

    }    

    event LiquidityRemoved (address indexed from,  uint256 liquidity, address to, uint256 amountA, uint256 amountB);

    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts)
    {


        /*
        ○ Tareas:
        ■ Transferir token de entrada del usuario al contrato.
        ■ Calcular intercambio según reservas.
        ■ Transferir token de salida al usuario.
        ○ Parámetros:
        ■ amountIn: Cantidad de tokens de entrada.
        ■ amountOutMin: Mínimo aceptable de tokens de salida.
        ■ path: Array de direcciones de tokens. (token entrada, token salida)
        ■ to: Dirección del destinatario.
        ■ deadline: Marca de tiempo para la transacción.
        ○ Retornos:
        ■ amounts: Array con cantidades de entrada y salida.
        */
        
    }    

    function getPrice(address tokenA, address tokenB) public view returns (uint price)
    {
        return (reserve[tokenA]==0 ? 0 : (reserve[tokenB]*myDecimals)/(reserve[tokenA])); 
     }    

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut)
    {
        return (amountIn*reserveOut)/reserveIn+amountIn;
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
