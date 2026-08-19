// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract PolyLaunchToken is ERC20, Ownable {
    uint256 public immutable maxSupply;

    constructor(string memory name_, string memory symbol_, uint256 supply_, address owner_)
        ERC20(name_, symbol_)
        Ownable(owner_)
    {
        require(supply_ > 0, "Invalid supply");

        maxSupply = supply_;

        _mint(owner_, supply_);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
