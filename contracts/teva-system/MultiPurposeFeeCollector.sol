// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MultiPurposeFeeCollector is Ownable {
    using ECDSA for bytes32;

    address public constant NATIVE_TOKEN =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // witness address
    address private witness;

    // Events
    event FeePaid(
        address indexed payer,
        address indexed token,
        uint256 amount,
        uint256 purposeId // purpose id defined by the teva system
    );

    event FeePaidSigned(
        address indexed payer,
        address indexed token,
        uint256 amount,
        uint256 purposeId // purpose id defined by the teva system
    );

    // constructor
    constructor(address _witness) {
        witness = _witness;
    }

    // Pay fee with ETH
    function payWithETH(uint256 purposeId) external payable {
        require(msg.value > 0, "Fee must be greater than zero");
        emit FeePaid(msg.sender, NATIVE_TOKEN, msg.value, purposeId);
    }

    // Pay fee with ERC20 token
    function payWithToken(
        address token,
        uint256 amount,
        uint256 purposeId
    ) external {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Fee must be greater than zero");

        // Transfer the tokens to this contract
        bool success = IERC20(token).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(success, "Token transfer failed");

        emit FeePaid(msg.sender, token, amount, purposeId);
    }

    // Pay fee with ETH
    function payWithETHSigned(
        uint256 purposeId,
        uint64 validTill,
        bytes calldata signature
    ) external payable {
        require(msg.value > 0, "Fee must be greater than zero");
        verify(
            abi.encode(msg.value, purposeId, validTill),
            validTill,
            signature
        );
        emit FeePaidSigned(msg.sender, NATIVE_TOKEN, msg.value, purposeId);
    }

    // Pay fee with ERC20 token
    function payWithTokenSigned(
        address token,
        uint256 amount,
        uint256 purposeId,
        uint64 validTill,
        bytes calldata signature
    ) external {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Fee must be greater than zero");

        verify(
            abi.encode(token, amount, purposeId, validTill),
            validTill,
            signature
        );

        // Transfer the tokens to this contract
        bool success = IERC20(token).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(success, "Token transfer failed");

        emit FeePaidSigned(msg.sender, token, amount, purposeId);
    }

    // Set witness address
    function setWitness(address _witness) external onlyOwner {
        witness = _witness;
    }

    // Verify signature
    function verify(
        bytes memory data,
        uint64 timestamp,
        bytes memory signature
    ) internal view {
        require(timestamp > block.timestamp, "Signature expired");
        require(
            keccak256(data).toEthSignedMessageHash().recover(signature) ==
                witness,
            "Invalid signature"
        );
    }

    // Withdraw ETH by the owner
    function withdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        payable(owner()).transfer(balance);
    }

    // Withdraw ERC20 tokens by the owner
    function withdrawTokens(address token) external onlyOwner {
        require(token != address(0), "Invalid token address");
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        bool success = IERC20(token).transfer(owner(), balance);
        require(success, "Token transfer failed");
    }

    // Fallback to accept ETH
    receive() external payable {
        emit FeePaid(msg.sender, NATIVE_TOKEN, msg.value, 0); // PurposeId is set to 0 for generic payments
    }
}
