# SimpleSwap Contract - ETH Kipu TP Nº3 by Nahuel Ruiz Mattar  

SimpleSwap Address: https://sepolia.etherscan.io/address/0x189E5ABAC389D37F9afc573a3549a00dF6feb41b#code

Thurisaz (Token) Address: https://sepolia.etherscan.io/address/0x2966F7783663538a1265B44d4956E2e016Fc83c6#code

Uruz (Token) Address: https://sepolia.etherscan.io/address/0x29e740c900e173EAA854818343edd9b4bE75fd41#code

---

## 🧠 Project Overview

This project implements a **Simple Token Swap & Liquidity Pool Smart Contract** on Ethereum.

The goal of this project is to create a Uniswap-like decentralized exchange (DEX).

The contract is written in **Solidity 0.8.27**, and uses **OpenZeppelin's libraries** for safe ERC-20 interactions.

---

## 🔄 What Does It Do?

This contract allows:

- ✅ Adding and removing liquidity to a token pair (e.g., URUZ/THURISAZ)
- ✅ Swapping one token for another using a constant product formula
- ✅ Issuing LP tokens representing liquidity provider shares
- ✅ Querying real-time token price based on reserves

---

## 📦 Contract Architecture

The core of the contract is built around:

- A custom **ERC20 token** representing LP shares (called `Liquidity Token`)
- Internal **reserves tracking** for each token pair
- A **reentrancy guard** and **deadline checks** to secure transactions
- Support for **constant product AMM** logic similar to Uniswap V2

---

## 🔐 Security Features

- ✅ `nonReentrant` modifier to prevent reentrancy attacks  
- ✅ `isNotExpired` modifier to reject outdated transactions  
- ✅ Minimum locked liquidity to avoid divide-by-zero errors  
- ✅ Proper input validation and reserve checks

---

## 📚 Main Functions

| Function | Description |
|----------|-------------|
| `addLiquidity` | Adds tokens to the pool and mints LP tokens |
| `removeLiquidity` | Removes tokens from the pool and burns LP tokens |
| `swapExactTokensForTokens` | Swaps one token for another based on reserves |
| `getPrice` | Returns the price of token A in terms of token B |
| `getAmountOut` | Utility to estimate output for a given input |

---
