// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Cat
 * @author note-xin
 * @notice This contract is to undestand how DAO works
 */
contract Cat is Ownable {
    /* State Variables */
    uint256 private s_number;

    /* Events */
    event NumberSet(uint256 number);

    /* Functions */
    constructor() Ownable(msg.sender) {}

    /* Public Functions */
    function store(uint256 _number) public onlyOwner {
        s_number = _number;
        emit NumberSet(_number);
    }

    /* External Functions */
    function getNumber() external view returns (uint256) {
        return s_number;
    }

}