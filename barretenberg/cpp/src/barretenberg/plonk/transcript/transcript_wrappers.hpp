// === AUDIT STATUS ===
// internal:    { status: not started, auditors: [], date: YYYY-MM-DD }
// external_1:  { status: not started, auditors: [], date: YYYY-MM-DD }
// external_2:  { status: not started, auditors: [], date: YYYY-MM-DD }
// =====================

#pragma once

#include "./transcript.hpp"
#include "barretenberg/ecc/curves/bn254/fr.hpp"
#include "barretenberg/ecc/curves/bn254/g1.hpp"
#include <unordered_map>

namespace bb::plonk::transcript {
/**
 * Transcript extended with functions for easy
 * field element setting/getting
 */
class StandardTranscript : public Transcript {
  public:
    /**
     * Create a new standard transcript for Prover based on the manifest.
     *
     * @param input_manifest The manifest with round descriptions.
     * @param hash_type The hash to use for Fiat-Shamir.
     * @param challenge_bytes The number of bytes per challenge to generate.
     *
     * */
    StandardTranscript(const Manifest input_manifest,
                       const HashType hash_type = HashType::Keccak256,
                       const size_t challenge_bytes = 32)
        : Transcript(input_manifest, hash_type, challenge_bytes)
    {}
    /**
     * Parse a serialized version of an input_transcript into a deserialized
     * one based on the manifest.
     *
     * @param input_transcript Serialized transcript.
     * @param input_manifest The manifest which governs the parsing.
     * @param hash_type The hash used for Fiat-Shamir
     * @param challenge_bytes The number of bytes per challenge to generate.
     *
     * */
    StandardTranscript(const std::vector<uint8_t>& input_transcript,
                       const Manifest input_manifest,
                       const HashType hash_type = HashType::Keccak256,
                       const size_t challenge_bytes = 32)
        : Transcript(input_transcript, input_manifest, hash_type, challenge_bytes){};

    void add_field_element(const std::string& element_name, const bb::fr& element);

    bb::fr get_field_element(const std::string& element_name) const;
    bb::g1::affine_element get_group_element(const std::string& element_name) const;

    std::vector<bb::fr> get_field_element_vector(const std::string& element_name) const;

    bb::fr get_challenge_field_element(const std::string& challenge_name, const size_t idx = 0) const;
    bb::fr get_challenge_field_element_from_map(const std::string& challenge_name,
                                                const std::string& challenge_map_name) const;

    std::vector<uint8_t> export_transcript() const { return Transcript::export_transcript(); }

    // TODO(luke): temporary function for debugging
    bb::fr get_mock_challenge() { return bb::fr::random_element(); };
};

} // namespace bb::plonk::transcript
