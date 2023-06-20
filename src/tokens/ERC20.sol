pragma solidity ^0.8.0;

contract ERC20 {
    string public name;
    string public symbol;
    uint256 public totalSupply;
    uint8 public decimals;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        assembly {
            // check if sender has sufficient balance
            mstore(0x00, caller())
            mstore(0x20, balanceOf.slot)
            let balanceOfSenderOffSet := keccak256(0x00, 0x40)
            let balanceOfSender := sload(balanceOfSenderOffSet)
            if iszero(gt(balanceOfSender, amount)) { if iszero(eq(balanceOfSender, amount)) { revert(0x0, 0x0) } }

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

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        assembly {
            // Check if the caller has the approval
            mstore(0x00, sender)
            mstore(0x20, allowance.slot)
            let offset := keccak256(0x00, 0x40)
            mstore(0x00, caller())
            mstore(0x20, offset)
            offset := keccak256(0x00, 0x40)

            let allowanceOfCaller := sload(offset)
            if iszero(gt(allowanceOfCaller, amount)) { if iszero(eq(allowanceOfCaller, amount)) { revert(0x0, 0x0) } }

            // Check if the sender has sufficient balance
            mstore(0x00, sender)
            mstore(0x20, balanceOf.slot)
            let senderBalanceOffset := keccak256(0x00, 0x40)
            let balanceOfSender := sload(senderBalanceOffset)
            if iszero(gt(balanceOfSender, amount)) { if iszero(eq(balanceOfSender, amount)) { revert(0x0, 0x0) } }

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
            log3(0x00, 0x20, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, sender, recipient)

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

            // Emit event
            mstore(0x00, amount)
            log3(0x00, 0x20, 0x5c52a5f2b86fd16be577188b5a83ef1165faddc00b137b10285f16162e17792a, caller(), spender)

            // Return true
            mstore(0x0, 0x01)
            return(0x0, 32)
        }
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
            log3(0x00, 0x20, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, 0x00, account)
        }
    }

    function burn(address from, uint256 amount) external {
        assembly {
            // Decrement totalSupply
            let newTotalSupply := sub(sload(totalSupply.slot), amount)
            sstore(totalSupply.slot, newTotalSupply)

            // Decrement account balance
            mstore(0x00, from)
            mstore(0x20, balanceOf.slot)
            let balanceOfFromOffSet := keccak256(0x00, 0x40)
            let balanceOfFrom := sload(balanceOfFromOffSet)
            let newBalanceOfFrom := sub(balanceOfFrom, amount)
            sstore(balanceOfFromOffSet, newBalanceOfFrom)

            // Emit Event
            mstore(0x00, amount)
            log3(0x00, 0x20, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, from, 0x00)
        }
    }
}
