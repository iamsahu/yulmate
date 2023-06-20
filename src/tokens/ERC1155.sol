// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

abstract contract ERC1155 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TransferSingle(
        address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount
    );

    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] amounts
    );

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    event URI(string value, uint256 indexed id);

    /*//////////////////////////////////////////////////////////////
                             ERC1155 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => mapping(uint256 => uint256)) public balanceOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                             METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    function uri(uint256 id) public view virtual returns (string memory) {}

    /*//////////////////////////////////////////////////////////////
                              ERC1155 LOGIC
    //////////////////////////////////////////////////////////////*/

    function setApprovalForAll(address operator, bool approved) public virtual {
        assembly {
            // Set the approval
            let sender := caller()
            mstore(0x00, sender)
            mstore(0x20, isApprovedForAll.slot)
            let offset := keccak256(0x00, 0x40)
            mstore(0x00, operator)
            mstore(0x20, offset)
            offset := keccak256(0x00, 0x40)
            sstore(offset, approved)

            // emit the approval event
            mstore(0x00, 0x01)
            log3(0x00, 0x20, 0x935230e68d0344049b3ab530b10aa82a70705c7069af8b4cb5f52671eb13d120, sender, operator)
        }
    }

    function checkIfSmartContract(address from, address to, uint256 id, uint256 amount, bytes memory data) internal {
        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, amount, data)
                    == ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );

        // assembly {
        //     // Check if code length is zero
        //     let codeLength := extcodesize(to)
        //     if eq(codeLength, 0) {
        //         // Check if to is not zero address
        //         if eq(to,0) {
        //             revert(0x0, 0x0)
        //         }
        //     }
        //     if gt(codeLength, 0) {
        //         // Make the call
        //         // ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
        //         // ERC721TokenReceiver.onERC721Received.selector
        //         mstore(0x00, 0xf23a6e61)
        //         mstore(0x20, caller())
        //         mstore(0x40, from)
        //         mstore(0x60, id)
        //         mstore(0x80, amount)
        //         mstore(0xa0, data)
        //         let result := call(gas(), to, 0, 28, 160, 0xc0, 0x20)

        //         // if iszero(eq(mload(0xc0), 0x00000000000000000000000000000000000000000000000000000000f23a6e61)) {
        //         //     revert(0xa0, 0x80)
        //         // }
        //         // Check if the return value is equal to the selector
        //         returndatacopy(0, 0, returndatasize())
        //     }
        // }
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data)
        public
        virtual
    {
        assembly {
            let sender := caller()
            // Check if msg.sender is from
            if iszero(eq(from, sender)) {
                // Check if msg.sender is approved
                mstore(0x00, from)
                mstore(0x20, isApprovedForAll.slot)
                let offset := keccak256(0x00, 0x40)
                mstore(0x00, sender)
                mstore(0x20, offset)
                offset := keccak256(0x00, 0x40)
                if iszero(sload(offset)) { revert(0x0, 0x0) }
            }

            // Update the balances
            mstore(0x00, from)
            mstore(0x20, balanceOf.slot)
            let offset := keccak256(0x00, 0x40)
            mstore(0x00, id)
            mstore(0x20, offset)
            offset := keccak256(0x00, 0x40)
            let oldBalance := sload(offset)
            if lt(oldBalance, amount) { revert(0x0, 0x0) }
            let newBalance := sub(oldBalance, amount)
            sstore(offset, newBalance)

            mstore(0x00, to)
            mstore(0x20, balanceOf.slot)
            offset := keccak256(0x00, 0x40)
            mstore(0x00, id)
            mstore(0x20, offset)
            offset := keccak256(0x00, 0x40)
            oldBalance := sload(offset)
            // TODO: Check for overflow
            newBalance := add(oldBalance, amount)
            sstore(offset, newBalance)

            // Emit the transfer single event
            mstore(0x00, id)
            mstore(0x20, amount)
            log4(
                0x00,
                0x20,
                0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62, //TransferSingle(address,address,address,uint256,uint256)
                caller(),
                from,
                to
            )
        }

        checkIfSmartContract(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual {
        assembly {
            let idsLength := ids.length
            let amountsLength := amounts.length

            // Check if lengths of arrays are equal
            if iszero(eq(idsLength, amountsLength)) { revert(0x0, 0x0) } // LENGTH_MISMATCH

            let sender := caller()

            // Check if msg.sender is from
            if iszero(eq(from, sender)) {
                // Check if msg.sender is approved
                mstore(0x00, from)
                mstore(0x20, isApprovedForAll.slot)
                let offset := keccak256(0x00, 0x40)
                mstore(0x00, sender)
                mstore(0x20, offset)
                offset := keccak256(0x00, 0x40)
                if iszero(sload(offset)) { revert(0x0, 0x0) } // NOT_AUTHORIZED
            }

            // Update the balances
            let id := 0
            let amount := 0

            // Calculate the offset for amounts array
            let amountOffset := add(0xE4, mul(idsLength, 0x20))
            // let amountStart := add(0x44, mul(ids.length, 0x20))

            for { let i := 0 } lt(i, ids.length) { i := add(i, 1) } {
                id := calldataload(add(0xC4, mul(i, 0x20)))
                amount := calldataload(add(amountOffset, mul(i, 0x20)))

                mstore(0x00, from)
                mstore(0x20, balanceOf.slot)
                let offset := keccak256(0x00, 0x40)
                mstore(0x00, id)
                mstore(0x20, offset)
                offset := keccak256(0x00, 0x40)
                let oldBalance := sload(offset)
                if lt(oldBalance, amount) { revert(0x0, 0x0) }
                let newBalance := sub(oldBalance, amount)
                sstore(offset, newBalance)

                mstore(0x00, to)
                mstore(0x20, balanceOf.slot)
                offset := keccak256(0x00, 0x40)
                mstore(0x00, id)
                mstore(0x20, offset)
                offset := keccak256(0x00, 0x40)
                oldBalance := sload(offset)
                // TODO: check for overflow
                newBalance := add(oldBalance, amount)
                sstore(offset, newBalance)
            }
        }

        // TODO: Emit the transfer batch event
        emit TransferBatch(msg.sender, from, to, ids, amounts);

        // checkIfSmartContract(from, to, ids, amounts, data);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data)
                    == ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        assembly {
            let ownersLength := owners.length
            let idsLength := ids.length

            // Check if lengths of arrays are equal
            if iszero(eq(ownersLength, idsLength)) { revert(0x0, 0x0) } // LENGTH_MISMATCH

            let idsOffset := add(0x84, mul(ownersLength, 0x20))

            let freememPointer := mload(0x40)

            for { let i := 0 } lt(i, ownersLength) { i := add(i, 1) } {
                let owner := calldataload(add(0x64, mul(i, 0x20)))
                let id := calldataload(add(idsOffset, mul(i, 0x20)))

                mstore(0x00, owner)
                mstore(0x20, balanceOf.slot)
                let offset := keccak256(0x00, 0x40)
                mstore(0x00, id)
                mstore(0x20, offset)
                offset := keccak256(0x00, 0x40)
                mstore(add(add(freememPointer, 0x40), mul(i, 0x20)), sload(offset))
            }
            mstore(freememPointer, 2)
            mstore(add(freememPointer, 0x20), ownersLength)
            return(freememPointer, add(mul(ownersLength, 0x20), 0x40))
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        assembly {
            if eq(interfaceId, 0x01ffc9a7) {
                // ERC165 Interface ID for ERC165
                mstore(0x00, 0x01)
                return(0x00, 0x04)
            }
            if eq(interfaceId, 0xd9b67a26) {
                // ERC165 Interface ID for ERC1155
                mstore(0x00, 0x01)
                return(0x00, 0x04)
            }
            if eq(interfaceId, 0x0e89341c) {
                // ERC165 Interface ID for ERC1155MetadataURI
                mstore(0x00, 0x01)
                return(0x00, 0x04)
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal virtual {
        assembly {
            mstore(0x00, to)
            mstore(0x20, balanceOf.slot)
            let offset := keccak256(0x00, 0x40)
            mstore(0x00, id)
            mstore(0x20, offset)
            offset := keccak256(0x00, 0x40)
            let oldBalance := sload(offset)
            let newBalance := add(oldBalance, amount)
            sstore(offset, newBalance)

            // Emit event
            mstore(0x00, id)
            mstore(0x20, amount)
            log4(
                0x00,
                0x20,
                0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62, //TransferSingle(address,address,address,uint256,uint256)
                caller(),
                0x00,
                to
            )
        }

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, address(0), id, amount, data)
                    == ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _batchMint(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        virtual
    {
        assembly {
            let idsLength := calldataload(0x84) // Get length of first array
            let amountsLength := calldataload(add(0xA4, mul(idsLength, 0x20))) // Get length of second array

            // Check if lengths of arrays are equal
            if iszero(eq(idsLength, amountsLength)) { revert(0x0, 0x0) } // LENGTH_MISMATCH

            let amountOffset := add(0xC4, mul(idsLength, 0x20))

            for { let i := 0 } lt(i, idsLength) { i := add(i, 1) } {
                let id := calldataload(add(0xA4, mul(i, 0x20)))
                let amount := calldataload(add(amountOffset, mul(i, 0x20)))
                mstore(0x00, to)
                mstore(0x20, balanceOf.slot)
                let offset := keccak256(0x00, 0x40)
                mstore(0x00, id)
                mstore(0x20, offset)
                offset := keccak256(0x00, 0x40)
                let oldBalance := sload(offset)
                // todo: check for overflow
                let newBalance := add(oldBalance, amount)
                sstore(offset, newBalance)
            }
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, address(0), ids, amounts, data)
                    == ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _batchBurn(address from, uint256[] memory ids, uint256[] memory amounts) internal virtual {
        assembly {
            let idsLength := calldataload(0x64) // Get length of first array
            let amountsLength := calldataload(add(0x84, mul(idsLength, 0x20))) // Get length of second array

            // Check if lengths of arrays are equal
            if iszero(eq(idsLength, amountsLength)) { revert(0x0, 0x0) } // LENGTH_MISMATCH

            let amountOffset := add(0xA4, mul(idsLength, 0x20))

            for { let i := 0 } lt(i, idsLength) { i := add(i, 1) } {
                let id := calldataload(add(0x84, mul(i, 0x20)))
                let amount := calldataload(add(amountOffset, mul(i, 0x20)))
                mstore(0x00, from)
                mstore(0x20, balanceOf.slot)
                let offset := keccak256(0x00, 0x40)
                mstore(0x00, id)
                mstore(0x20, offset)
                offset := keccak256(0x00, 0x40)
                let oldBalance := sload(offset)
                if lt(oldBalance, amount) { revert(0x0, 0x0) }
                let newBalance := sub(oldBalance, amount)
                sstore(offset, newBalance)
            }
        }

        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
    }

    function _burn(address from, uint256 id, uint256 amount) internal virtual {
        assembly {
            mstore(0x00, from)
            mstore(0x20, balanceOf.slot)
            let offset := keccak256(0x00, 0x40)
            mstore(0x00, id)
            mstore(0x20, offset)
            offset := keccak256(0x00, 0x40)
            let oldBalance := sload(offset)
            if lt(oldBalance, amount) { revert(0x0, 0x0) }
            let newBalance := sub(oldBalance, amount)
            sstore(offset, newBalance)

            // Emit event
            mstore(0x00, id)
            mstore(0x20, amount)
            log4(
                0x00,
                0x20,
                0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62, //TransferSingle(address,address,address,uint256,uint256)
                caller(),
                from,
                0x00
            )
        }
    }
}

/// @notice A generic interface for a contract which properly accepts ERC1155 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155TokenReceiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}
