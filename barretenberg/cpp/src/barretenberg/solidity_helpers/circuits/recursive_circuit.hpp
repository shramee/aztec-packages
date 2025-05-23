#pragma once
#include "barretenberg/ecc/curves/bn254/fq12.hpp"
#include "barretenberg/ecc/curves/bn254/pairing.hpp"
#include "barretenberg/plonk/composer/ultra_composer.hpp"
#include "barretenberg/plonk/proof_system/proving_key/serialize.hpp"
#include "barretenberg/stdlib/plonk_recursion/verifier/program_settings.hpp"
#include "barretenberg/stdlib/plonk_recursion/verifier/verifier.hpp"
#include "barretenberg/stdlib/primitives/bigfield/constants.hpp"
#include "barretenberg/stdlib/primitives/circuit_builders/circuit_builders_fwd.hpp"
#include "barretenberg/stdlib/primitives/curves/bn254.hpp"
#include "barretenberg/transcript/transcript.hpp"

using namespace bb::plonk;
using namespace stdlib;
using numeric::uint256_t;

class RecursiveCircuit {
    using InnerComposer = UltraComposer;
    using Builder = UltraCircuitBuilder;

    using inner_curve = bn254<Builder>;
    using outer_curve = bn254<Builder>;

    using verification_key_pt = recursion::verification_key<outer_curve>;
    using recursive_settings = recursion::recursive_ultra_verifier_settings<outer_curve>;
    using ultra_to_standard_recursive_settings = recursion::recursive_ultra_to_standard_verifier_settings<outer_curve>;

    using inner_scalar_field_ct = inner_curve::ScalarField;
    using inner_ground_field_ct = inner_curve::BaseField;
    using public_witness_ct = inner_curve::public_witness_ct;
    using witness_ct = inner_curve::witness_ct;
    using byte_array_ct = inner_curve::byte_array_ct;

    using inner_scalar_field = typename inner_curve::ScalarFieldNative;
    using outer_scalar_field = typename outer_curve::BaseFieldNative;
    using pairing_target_field = bb::fq12;
    using ProverOfInnerCircuit = plonk::UltraProver;
    using VerifierOfInnerProof = plonk::UltraVerifier;

    struct circuit_outputs {
        stdlib::recursion::PairingPoints<Builder> pairing_points;
        std::shared_ptr<verification_key_pt> verification_key;
    };

    static void create_inner_circuit_no_tables(Builder& builder, uint256_t public_inputs[])
    {
        // A nice Pythagorean triples circuit example: "I know a & b s.t. a^2 + b^2 = c^2".
        inner_scalar_field_ct a(witness_ct(&builder, public_inputs[0]));
        inner_scalar_field_ct b(witness_ct(&builder, public_inputs[1]));
        inner_scalar_field_ct c(witness_ct(&builder, public_inputs[2]));

        auto c_sq = c * c;

        (c).assert_equal(a + b);

        c_sq.set_public();
    };

    static circuit_outputs create_outer_circuit(Builder& inner_circuit, Builder& outer_builder)
    {
        ProverOfInnerCircuit prover;
        InnerComposer inner_composer;
        prover = inner_composer.create_prover(inner_circuit);

        const auto verification_key_native = inner_composer.compute_verification_key(inner_circuit);
        // Convert the verification key's elements into _circuit_ types, using the OUTER composer.
        std::shared_ptr<verification_key_pt> verification_key =
            verification_key_pt::from_witness(&outer_builder, verification_key_native);

        plonk::proof proof_to_recursively_verify = prover.construct_proof();

        {
            // Native check is mainly for comparison vs circuit version of the verifier.
            VerifierOfInnerProof native_verifier;

            native_verifier = inner_composer.create_verifier(inner_circuit);

            bool native_result = native_verifier.verify_proof(proof_to_recursively_verify);
            if (!native_result) {
                throw_or_abort("Native verification failed");
            }
        }

        transcript::Manifest recursive_manifest = InnerComposer::create_manifest(prover.key->num_public_inputs);

        auto output = recursion::verify_proof<outer_curve, recursive_settings>(
            &outer_builder, verification_key, recursive_manifest, proof_to_recursively_verify);

        return { output, verification_key };
    };

    static bool check_pairing_point_accum_public_inputs(Builder& builder, const bb::pairing::miller_lines* lines)
    {
        if (builder.contains_pairing_point_accumulator &&
            builder.pairing_point_accumulator_public_input_indices.size() == 16) {
            const auto& inputs = builder.public_inputs;
            const auto recover_fq_from_public_inputs =
                [&inputs, &builder](const size_t idx0, const size_t idx1, const size_t idx2, const size_t idx3) {
                    const uint256_t l0 = builder.get_variable(inputs[idx0]);
                    const uint256_t l1 = builder.get_variable(inputs[idx1]);
                    const uint256_t l2 = builder.get_variable(inputs[idx2]);
                    const uint256_t l3 = builder.get_variable(inputs[idx3]);

                    const uint256_t limb = l0 + (l1 << NUM_LIMB_BITS_IN_FIELD_SIMULATION) +
                                           (l2 << (NUM_LIMB_BITS_IN_FIELD_SIMULATION * 2)) +
                                           (l3 << (NUM_LIMB_BITS_IN_FIELD_SIMULATION * 3));
                    return outer_scalar_field(limb);
                };

            const auto x0 = recover_fq_from_public_inputs(builder.pairing_point_accumulator_public_input_indices[0],
                                                          builder.pairing_point_accumulator_public_input_indices[1],
                                                          builder.pairing_point_accumulator_public_input_indices[2],
                                                          builder.pairing_point_accumulator_public_input_indices[3]);
            const auto y0 = recover_fq_from_public_inputs(builder.pairing_point_accumulator_public_input_indices[4],
                                                          builder.pairing_point_accumulator_public_input_indices[5],
                                                          builder.pairing_point_accumulator_public_input_indices[6],
                                                          builder.pairing_point_accumulator_public_input_indices[7]);
            const auto x1 = recover_fq_from_public_inputs(builder.pairing_point_accumulator_public_input_indices[8],
                                                          builder.pairing_point_accumulator_public_input_indices[9],
                                                          builder.pairing_point_accumulator_public_input_indices[10],
                                                          builder.pairing_point_accumulator_public_input_indices[11]);
            const auto y1 = recover_fq_from_public_inputs(builder.pairing_point_accumulator_public_input_indices[12],
                                                          builder.pairing_point_accumulator_public_input_indices[13],
                                                          builder.pairing_point_accumulator_public_input_indices[14],
                                                          builder.pairing_point_accumulator_public_input_indices[15]);
            g1::affine_element P_affine[2]{
                { x0, y0 },
                { x1, y1 },
            };

            pairing_target_field result = bb::pairing::reduced_ate_pairing_batch_precomputed(P_affine, lines, 2);

            return (result == pairing_target_field::one());
        }
        if (builder.contains_pairing_point_accumulator &&
            builder.pairing_point_accumulator_public_input_indices.size() != 16) {
            return false;
        }
        return true;
    }
    static void check_pairing(const circuit_outputs& circuit_output)
    {
        auto g2_lines = bb::srs::get_bn254_crs_factory()->get_verifier_crs()->get_precomputed_g2_lines();
        g1::affine_element P[2];
        P[0].x = outer_scalar_field(circuit_output.pairing_points.P0.x.get_value().lo);
        P[0].y = outer_scalar_field(circuit_output.pairing_points.P0.y.get_value().lo);
        P[1].x = outer_scalar_field(circuit_output.pairing_points.P1.x.get_value().lo);
        P[1].y = outer_scalar_field(circuit_output.pairing_points.P1.y.get_value().lo);
        pairing_target_field inner_proof_result = bb::pairing::reduced_ate_pairing_batch_precomputed(P, g2_lines, 2);
        if (inner_proof_result != pairing_target_field::one()) {
            throw_or_abort("inner proof result != 1");
        }
    }

  public:
    static Builder generate(uint256_t inputs[])
    {
        Builder inner_circuit;
        Builder outer_circuit;

        create_inner_circuit_no_tables(inner_circuit, inputs);

        auto circuit_output = create_outer_circuit(inner_circuit, outer_circuit);

        circuit_output.pairing_points.assign_object_to_proof_outputs_for_plonk();
        if (outer_circuit.failed()) {
            throw_or_abort("outer composer failed");
        }

        return outer_circuit;
    }
};
