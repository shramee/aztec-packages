use dep::protocol_types::{address::AztecAddress, constants::L1_TO_L2_MSG_TREE_HEIGHT};

/// Returns the leaf index and sibling path of an entry in the L1 to L2 messaging tree, which can then be used to prove
/// its existence.
pub unconstrained fn get_l1_to_l2_membership_witness(
    contract_address: AztecAddress,
    message_hash: Field,
    secret: Field,
) -> (Field, [Field; L1_TO_L2_MSG_TREE_HEIGHT]) {
    get_l1_to_l2_membership_witness_oracle(contract_address, message_hash, secret)
}

// Obtains membership witness (index and sibling path) for a message in the L1 to L2 message tree.
#[oracle(getL1ToL2MembershipWitness)]
unconstrained fn get_l1_to_l2_membership_witness_oracle(
    _contract_address: AztecAddress,
    _message_hash: Field,
    _secret: Field,
) -> (Field, [Field; L1_TO_L2_MSG_TREE_HEIGHT]) {}
