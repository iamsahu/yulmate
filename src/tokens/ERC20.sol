pragma solidity ^0.8.0;

contract ERC20 {
    uint256 public totalSupply;
    uint8 public decimals;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    // function totalSupply() external view returns (uint256) {
    //     assembly {
    //         return(0x00, 0x20)
    //     }
    // }

    // function balanceOf(address account) external view returns (uint256) {
    //     assembly{
    //         let val := keccak256(account, 0x03)
    //         mstore(0x0, val)
    //         return(0x0, 32)
    //     }
    // }

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool) {
        assembly {
            // check if sender has sufficient balance
            mstore(0x00, caller())
            mstore(0x20, balanceOf.slot)
            let balanceOfSenderOffSet := keccak256(0x00, 0x40)
            let balanceOfSender := sload(balanceOfSenderOffSet)
            // if iszero(lt(balanceOfSender, amount)) {
            //     revert(0x0, 0x0)
            // }

            // increment recipient balance
            mstore(0x00, recipient)
            mstore(0x20, balanceOf.slot)
            let balanceOfRecipientOffSet := keccak256(0x00, 0x40)
            let balanceOfRecipient := sload(balanceOfRecipientOffSet)
            let newBalanceOfRecipient := add(balanceOfRecipient, amount)
            sstore(balanceOfRecipientOffSet, newBalanceOfRecipient)

            // decrement sender balance
            let newBalanceOfSender := sub(balanceOfSender, amount)
            sstore(balanceOfSenderOffSet, newBalanceOfSender)

            // return true
            mstore(0x0, 0x01)
            return(0x0, 32)
        }
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        assembly {
            // Check if the caller has the approval
            mstore(0x00, sender)
            mstore(0x20, allowance.slot)
            let offset := keccak256(0x00, 0x40)
            mstore(0x00, caller())
            mstore(0x20, offset)
            offset := keccak256(0x00, 0x40)

            let allowanceOfCaller := sload(offset)
            // let g := gt(allowanceOfCaller, amount)
            // if iszero(g) {
            //     let equalAllowance := eq(allowanceOfCaller, amount)
            //     if iszero(equalAllowance) {
            //         revert(0x0, 0x0)
            //     }
            // }

            // Check if the sender has sufficient balance
            mstore(0x00, sender)
            mstore(0x20, balanceOf.slot)
            let senderBalanceOffset := keccak256(0x00, 0x40)
            let balanceOfSender := sload(senderBalanceOffset)
            // g := gt(balanceOfSender, amount)
            // if iszero(g) {
            //     let equalBalance := eq(balanceOfSender, amount)
            //     if iszero(equalBalance) {
            //         revert(0x0, 0x0)
            //     }
            // }

            // Decrement allowance
            let newAllowanceOfCaller := sub(allowanceOfCaller, amount)
            sstore(offset, newAllowanceOfCaller)
            // Decrement sender balance
            let newBalanceOfSender := sub(balanceOfSender, amount)
            sstore(senderBalanceOffset, newBalanceOfSender)

            // Increment recipient balance
            mstore(0x00, recipient)
            mstore(0x20, balanceOf.slot)
            let balanceOfRecipientOffset := keccak256(0x00, 0x40)
            let balanceOfRecipient := sload(balanceOfRecipientOffset)
            let newBalanceOfRecipient := add(balanceOfRecipient, amount)
            sstore(balanceOfRecipientOffset, newBalanceOfRecipient)

            // Emit event
            mstore(0x00, amount)
            log3(
                0x00,
                0x20,
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                sender,
                recipient
            )

            // Return true
            mstore(0x0, 0x01)
            return(0x0, 32)
        }
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        assembly {
            // calculate allowance offset
            mstore(0x00, caller())
            mstore(0x20, allowance.slot)
            let offset := keccak256(0x00, 0x40)
            mstore(0x00, spender)
            mstore(0x20, offset)
            offset := keccak256(0x00, 0x40)
            let allowanceOfCaller := sload(offset)

            // Increment allowance
            let newAllowanceOfCaller := add(allowanceOfCaller, amount)
            sstore(offset, newAllowanceOfCaller)
        }
        return true;
    }

    function mint(address account, uint256 amount) external {
        assembly {
            // Increment totalSupply
            let newTotalSupply := add(sload(totalSupply.slot), amount)
            sstore(totalSupply.slot, newTotalSupply)

            // Increment account balance
            mstore(0x00, account)
            mstore(0x20, balanceOf.slot)
            let balanceOfAccountOffSet := keccak256(0x00, 0x40)
            let balanceOfAccount := sload(balanceOfAccountOffSet)
            let newBalanceOfAccount := add(balanceOfAccount, amount)
            sstore(balanceOfAccountOffSet, newBalanceOfAccount)

            // Emit Event
            mstore(0x00, amount)
            log3(
                0x00,
                0x20,
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                0x00,
                account
            )
        }
    }

    // function allowance(
    //     address owner,
    //     address spender
    // ) external view returns (uint256) {}

    function name() external view returns (string memory) {}

    function symbol() external view returns (string memory) {}

    // function decimals() external view returns (uint8) {}
}
