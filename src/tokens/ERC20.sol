// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(
        address spender,
        uint256 amount
    ) public virtual returns (bool) {
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
            log3(
                0x00,
                0x20,
                0x5c52a5f2b86fd16be577188b5a83ef1165faddc00b137b10285f16162e17792a,
                caller(),
                spender
            )

            // Return true
            mstore(0x0, 0x01)
            return(0x0, 32)
        }
    }

    function transfer(
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        assembly {
            // check if sender has sufficient balance
            mstore(0x00, caller())
            mstore(0x20, balanceOf.slot)
            let balanceOfSenderOffSet := keccak256(0x00, 0x40)
            let balanceOfSender := sload(balanceOfSenderOffSet)
            if iszero(gt(balanceOfSender, amount)) {
                if iszero(eq(balanceOfSender, amount)) {
                    revert(0x0, 0x0)
                }
            }

            // increment recipient balance
            mstore(0x00, to)
            mstore(0x20, balanceOf.slot)
            let balanceOfRecipientOffSet := keccak256(0x00, 0x40)
            let balanceOfRecipient := sload(balanceOfRecipientOffSet)
            let newBalanceOfRecipient := add(balanceOfRecipient, amount)
            sstore(balanceOfRecipientOffSet, newBalanceOfRecipient)

            // decrement sender balance
            let newBalanceOfSender := sub(balanceOfSender, amount)
            sstore(balanceOfSenderOffSet, newBalanceOfSender)

            // emit event
            mstore(0x00, amount)
            log3(
                0x00,
                0x20,
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                caller(),
                to
            )

            // return true
            mstore(0x0, 0x01)
            return(0x0, 32)
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        assembly {
            // Check if the caller has the approval
            mstore(0x00, from)
            mstore(0x20, allowance.slot)
            let offset := keccak256(0x00, 0x40)
            mstore(0x00, caller())
            mstore(0x20, offset)
            offset := keccak256(0x00, 0x40)

            let allowanceOfCaller := sload(offset)
            if iszero(
                eq(
                    allowanceOfCaller,
                    115792089237316195423570985008687907853269984665640564039457584007913129639935
                )
            ) {
                if iszero(gt(allowanceOfCaller, amount)) {
                    if iszero(eq(allowanceOfCaller, amount)) {
                        revert(0x0, 0x0)
                    }
                }
                // Decrement allowance
                let newAllowanceOfCaller := sub(allowanceOfCaller, amount)
                sstore(offset, newAllowanceOfCaller)
            }

            // Check if the sender has sufficient balance
            mstore(0x00, from)
            mstore(0x20, balanceOf.slot)
            let senderBalanceOffset := keccak256(0x00, 0x40)
            let balanceOfSender := sload(senderBalanceOffset)
            if iszero(gt(balanceOfSender, amount)) {
                if iszero(eq(balanceOfSender, amount)) {
                    revert(0x0, 0x0)
                }
            }

            // Decrement sender balance
            let newBalanceOfSender := sub(balanceOfSender, amount)
            sstore(senderBalanceOffset, newBalanceOfSender)

            // Increment recipient balance
            mstore(0x00, to)
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
                from,
                to
            )

            // Return true
            mstore(0x0, 0x01)
            return(0x0, 32)
        }
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        // TODO: to be implemented
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(
                recoveredAddress != address(0) && recoveredAddress == owner,
                "INVALID_SIGNER"
            );

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        // TODO: to be implemented
        return
            block.chainid == INITIAL_CHAIN_ID
                ? INITIAL_DOMAIN_SEPARATOR
                : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        // TODO: to be implemented
        // assembly {
        //     let freememptr := mload(0x40)
        //     mstore(
        //         freememptr,
        //         0x454950373132446F6D61696E28737472696E67206E616D652C737472696E6720
        //     )
        //     mstore(
        //         add(freememptr, 0x20),
        //         0x76657273696F6E2C75696E7432353620636861696E49642C6164647265737320
        //     )
        //     mstore(
        //         add(freememptr, 0x40),
        //         0x766572696679696E67436F6E747261637429
        //     )
        //     let domainKeccak := keccak256(freememptr, 0x60)

        //     mstore(add(freememptr,0x60),sload(name.slot))
        //     let nameKeccak := keccak256(add(freememptr,0x60),0x20)

        //     mstore(add(freememptr,0x80),1)
        //     let versionKeccak := keccak256(add(freememptr,0x80),0x20)

        //     mstore(freememptr,domainKeccak)
        //     mstore(add(freememptr,0x20),nameKeccak)
        //     mstore(add(freememptr,0x40),versionKeccak)
        //     mstore(add(freememptr,0x60),chainid())
        //     mstore(add(freememptr,0x80),address())

        //     mstore(add(freememptr,0xC0),keccak256(freememptr,0xA0))
        //     return(add(freememptr,0xC0),0x20)
        // }
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        assembly {
            // Increment totalSupply
            let newTotalSupply := add(sload(totalSupply.slot), amount)
            sstore(totalSupply.slot, newTotalSupply)

            // Increment account balance
            mstore(0x00, to)
            mstore(0x20, balanceOf.slot)
            let balanceOfAccountOffSet := keccak256(0x00, 0x40)
            let balanceOfAccount := sload(balanceOfAccountOffSet)
            // todo: check for overflow
            let newBalanceOfAccount := add(balanceOfAccount, amount)
            sstore(balanceOfAccountOffSet, newBalanceOfAccount)

            // Emit Event
            mstore(0x00, amount)
            log3(
                0x00,
                0x20,
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                0x00,
                to
            )
        }
    }

    function _burn(address from, uint256 amount) internal virtual {
        assembly {
            // Decrement totalSupply
            let newTotalSupply := sub(sload(totalSupply.slot), amount)
            sstore(totalSupply.slot, newTotalSupply)

            // Decrement account balance
            mstore(0x00, from)
            mstore(0x20, balanceOf.slot)
            let balanceOfFromOffSet := keccak256(0x00, 0x40)
            let balanceOfFrom := sload(balanceOfFromOffSet)
            if lt(balanceOfFrom, amount) {
                revert(0x0, 0x0)
            }
            let newBalanceOfFrom := sub(balanceOfFrom, amount)
            sstore(balanceOfFromOffSet, newBalanceOfFrom)

            // Emit Event
            mstore(0x00, amount)
            log3(
                0x00,
                0x20,
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                from,
                0x00
            )
        }
    }
}
