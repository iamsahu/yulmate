pragma solidity ^0.8.0;

contract ERC721 {
    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );
    event Approval(
        address indexed _owner,
        address indexed _approved,
        uint256 indexed _tokenId
    );
    event ApprovalForAll(
        address indexed _owner,
        address indexed _operator,
        bool _approved
    );

    mapping(address => uint256) internal _balanceOf;
    mapping(uint256 => address) internal _ownerOf;

    string public name;
    string public symbol;
    string public baseURI;

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseURI
    ) {
        name = _name;
        symbol = _symbol;
        baseURI = _baseURI;
    }

    function balanceOf(address _owner) external view returns (uint256) {
        assembly {
            mstore(0x00, _owner)
            mstore(0x20, _balanceOf.slot)
            let balanceOfOffset := keccak256(0x00, 0x40)

            let balanceOf := sload(balanceOfOffset)

            mstore(0x00, balanceOf)
            return(0x00, 32)
        }
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        assembly {
            mstore(0x00, _tokenId)
            mstore(0x20, _ownerOf.slot)
            let ownerOfOffset := keccak256(0x00, 0x40)
            let ownerOf := sload(ownerOfOffset)
            mstore(0x00, ownerOf)
            return(0x00, 32)
        }
    }

    function tokenURI(uint256 id) public view virtual returns (string memory) {
        // TODO: get this working
        return string(abi.encodePacked(baseURI, id));
        // assembly {
        //     mstore(0x00, 0x20)
        //     // load the length of the baseURI
        //     // load the baseURI
        //     // load the length of the id
        //     // return
        // }
    }

    function checkIfSmartContract(
        address _from,
        address _to,
        uint256 _id
    ) internal {
        assembly {
            // Check if code length is zero
            let codeLength := extcodesize(_to)
            if gt(codeLength, 0) {
                // Make the call
                // ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
                // ERC721TokenReceiver.onERC721Received.selector
                mstore(0x00, 0x150b7a02)
                mstore(0x20, caller())
                mstore(0x40, _from)
                mstore(0x60, _id)
                mstore(0x80, 0x00)
                if iszero(call(gas(), _to, selfbalance(), 0x0, 0x80, 0, 0)) {
                    revert(0x0, 0x0)
                }
                // Check if the return value is equal to the selector
                returndatacopy(0, 0, returndatasize())
            }
        }
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata data
    ) external payable {
        transferFrom(_from, _to, _tokenId);
        checkIfSmartContract(_from, _to, _tokenId);
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable {
        transferFrom(_from, _to, _tokenId);
        checkIfSmartContract(_from, _to, _tokenId);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public payable {
        assembly {
            // Check if the sender is the owner
            mstore(0x00, _tokenId)
            mstore(0x20, _ownerOf.slot)
            let ownerOfOffset := keccak256(0x00, 0x40)
            let ownerOf := sload(ownerOfOffset)
            let sender := caller()
            if iszero(eq(sender, ownerOf)) {
                revert(0x00, 0x00)
            }

            // Check if to is not zero address
            if iszero(_to) {
                revert(0x00, 0x00)
            }

            mstore(0x00, _tokenId)
            mstore(0x20, getApproved.slot)
            let getApprovedOffset := keccak256(0x00, 0x40)

            // Check if from is msg.sender or approved or approved for all
            if iszero(eq(_from, sender)) {
                // Check if the token is approved for transfer
                let approved := sload(getApprovedOffset)

                if iszero(eq(approved, _to)) {
                    // Check if the sender is approved for all
                    mstore(0x00, _from)
                    mstore(0x20, isApprovedForAll.slot)
                    let offset := keccak256(0x00, 0x40)

                    mstore(0x00, sender)
                    mstore(0x20, offset)
                    offset := keccak256(0x00, 0x40)

                    let isApprovedForAllValue := sload(offset)

                    if iszero(isApprovedForAllValue) {
                        revert(0x00, 0x00)
                    }
                }
            }

            // Reduce the balance of from
            mstore(0x00, _from)
            mstore(0x20, _balanceOf.slot)
            let balanceOfOffset := keccak256(0x00, 0x40)

            let balanceOf := sload(balanceOfOffset)
            balanceOf := sub(balanceOf, 1)
            sstore(balanceOfOffset, balanceOf)

            // Increase the balance of to
            mstore(0x00, _to)
            mstore(0x20, _balanceOf.slot)
            balanceOfOffset := keccak256(0x00, 0x40)

            balanceOf := sload(balanceOfOffset)
            balanceOf := add(balanceOf, 1)
            sstore(balanceOfOffset, balanceOf)

            // Set the owner of the token to to
            sstore(ownerOfOffset, _to)

            // delete the approval
            getApprovedOffset := keccak256(0x00, 0x40)
            sstore(getApprovedOffset, 0)

            // emit the transfer event
            mstore(0x00, _from)
            mstore(0x20, _to)
            mstore(0x40, _tokenId)
            log3(
                0x00,
                0x20,
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                _from,
                _to
            )
        }
    }

    function approve(address _approved, uint256 _tokenId) external payable {
        assembly {
            // Load owner of the token
            mstore(0x00, _tokenId)
            mstore(0x20, _ownerOf.slot)
            let ownerOfOffset := keccak256(0x00, 0x40)
            let ownerOf := sload(ownerOfOffset)

            // Check if the sender is the owner
            let sender := caller()
            let isOwner := eq(sender, ownerOf)
            if iszero(isOwner) {
                mstore(0x00, sender)
                mstore(0x20, isApprovedForAll.slot)
                let offset := keccak256(0x00, 0x40)

                mstore(0x00, _approved)
                mstore(0x20, offset)
                offset := keccak256(0x00, 0x40)

                let isApprovedForAllValue := sload(offset)
                if iszero(isApprovedForAllValue) {
                    revert(0x00, 0x00)
                }
            }

            // Set the approval
            mstore(0x00, _tokenId)
            mstore(0x20, getApproved.slot)
            let getApprovedOffset := keccak256(0x00, 0x40)

            sstore(getApprovedOffset, _approved)

            // emit the approval event
            mstore(0x00, _tokenId)
            log3(
                0x00,
                0x20,
                0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925,
                sender,
                _approved
            )
        }
    }

    function setApprovalForAll(address _operator, bool _approved) external {
        assembly {
            // Set the approval
            let sender := caller()
            mstore(0x00, sender)
            mstore(0x20, isApprovedForAll.slot)
            let offset := keccak256(0x00, 0x40)

            mstore(0x00, _operator)
            mstore(0x20, offset)
            offset := keccak256(0x00, 0x40)

            sstore(offset, _approved)

            // emit the approval event
            mstore(0x00, 0x01)
            log3(
                0x00,
                0x20,
                0x935230e68d0344049b3ab530b10aa82a70705c7069af8b4cb5f52671eb13d120,
                sender,
                _operator
            )
        }
    }

    function _mint(address _to, uint256 _id) external {
        assembly {
            // Check if not zero address
            if iszero(_to) {
                revert(0x00, 0x00)
            }

            // Check if the token already exists
            mstore(0x00, _id)
            mstore(0x20, _ownerOf.slot)
            let ownerOfOffset := keccak256(0x00, 0x40)

            let ownerOf := sload(ownerOfOffset)
            if iszero(eq(ownerOf, 0)) {
                revert(0x00, 0x00)
            }

            // Increase balance of to
            mstore(0x00, _to)
            mstore(0x20, _balanceOf.slot)
            let balanceOfOffset := keccak256(0x00, 0x40)

            let balanceOf := sload(balanceOfOffset)
            balanceOf := add(balanceOf, 1)

            sstore(balanceOfOffset, balanceOf)

            // Set the owner of the token to to
            sstore(ownerOfOffset, _to)

            // emit the transfer event
            mstore(0x00, _id)
            log3(
                0x00,
                0x20,
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                0x00,
                _to
            )
        }
    }

    function _burn(uint256 id) external {
        assembly {
            // Load owner of the token
            mstore(0x00, id)
            mstore(0x20, _ownerOf.slot)
            let ownerOfOffset := keccak256(0x00, 0x40)
            let ownerOf := sload(ownerOfOffset)

            // Check if minted
            // TODO: this is not working
            // if iszero(eq(ownerOf, 0x0000000000000000000000000000000000000000)) {
            //     revert(0x00, 0x00)
            // }

            // Reduce balance of owner
            mstore(0x00, ownerOf)
            mstore(0x20, _balanceOf.slot)
            let balanceOfOffset := keccak256(0x00, 0x40)

            let balanceOf := sload(balanceOfOffset)
            balanceOf := sub(balanceOf, 1)

            sstore(balanceOfOffset, balanceOf)

            // Set the owner of the token to 0
            sstore(ownerOfOffset, 0)

            // Set getApproved to 0
            mstore(0x00, id)
            mstore(0x20, getApproved.slot)
            let getApprovedOffset := keccak256(0x00, 0x40)

            sstore(getApprovedOffset, 0)

            // emit the transfer event
            mstore(0x00, id)
            log3(
                0x00,
                0x20,
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                ownerOf,
                0x00
            )
        }
    }
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}
