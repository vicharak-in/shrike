#include "model_data.h"
#include "vocab_data.h"

// keeps track of the best scoring candidates for top-k sampling
struct TokenCandidate {
    int id;
    float score;
};

float fast_sqrt(float x) {
    if (x <= 0.0f) return 0.0f;
    float guess = (x >= 1.0f) ? x * 0.5f : x * 2.0f;
    guess = 0.5f * (guess + x / guess);
    guess = 0.5f * (guess + x / guess);
    return guess;
}

// decodes a token index back into text and prints it
void print_embedded_token(int target_token_id) {
    uint16_t total_vocab = (vocab_bin_array[1] << 8) | vocab_bin_array[0];
    if (target_token_id >= total_vocab) return;

    const uint8_t *ptr = vocab_bin_array + 2;
    for (int current_id = 0; current_id < total_vocab; current_id++) {
        uint8_t token_length = *ptr;
        ptr++;

        if (current_id == target_token_id) {
            if (token_length > 0) {
                for (uint8_t i = 0; i < token_length; i++) {
                    Serial.print((char)ptr[i]);
                }
            }
            return;
        }
        ptr += token_length;
    }
}

void setup() {
    Serial.begin(115200);
    while (!Serial) { delay(10); }
    delay(500);

    // seed the random generator using noise picked up from an unconnected analog pin
    randomSeed(analogRead(0) + micros());

    Serial.println(F("Shrike 512p Fully Interactive Generator Engine"));
}

void loop() {
    Serial.println(F("Enter an input parameter number (0 to 511) in the box above and press Send:"));
    while (Serial.available() == 0) {
        delay(50);
    }
    int user_input_token = Serial.parseInt();
    while (Serial.available() > 0) { Serial.read(); }

    if (user_input_token < 0 || user_input_token >= MODEL_VOCAB_SIZE) {
        Serial.print(F("Error: ")); Serial.print(user_input_token);
        Serial.println(F(" is outside our 0-511 vocabulary limit. Try again."));
        return;
    }

    Serial.println(F("Enter text generation mode (0 for absolute strict math, 1 for normal, 2 for highly creative):"));
    while (Serial.available() == 0) {
        delay(50);
    }
    int choice_mode = Serial.parseInt();
    while (Serial.available() > 0) { Serial.read(); }

    Serial.print(F("Seed token accepted: ID ")); Serial.print(user_input_token);
    Serial.print(F(" (\"")); print_embedded_token(user_input_token); Serial.println(F("\")"));
    Serial.print(F("Generation Mode Setting: ")); Serial.println(choice_mode);
    Serial.println(F("Running matrix loops, generation streaming below:"));

    print_embedded_token(user_input_token);
    Serial.print(F(" "));

    int active_token = user_input_token;

    // tracks the last 5 tokens used to enforce long-range pattern variation
    int recent_history[5] = { user_input_token, -1, -1, -1, -1 };

    // generate 12 tokens, feeding each output back in as the next input
    for (int word_count = 0; word_count < 12; word_count++) {
        const float *x = token_embedding[active_token];

        // layer normalization
        float sum = 0.0f;
        for (int j = 0; j < MODEL_DIM; j++) { sum += x[j]; }
        float mean = sum / MODEL_DIM;

        float var_sum = 0.0f;
        for (int j = 0; j < MODEL_DIM; j++) {
            float diff = x[j] - mean;
            var_sum += diff * diff;
        }
        float variance = var_sum / MODEL_DIM;
        float std_dev = fast_sqrt(variance + 1e-6f);

        float normalized_vector[MODEL_DIM];
        for (int j = 0; j < MODEL_DIM; j++) {
            normalized_vector[j] = (x[j] - mean) / std_dev;
        }

        // score every token in the vocab and keep the top 3
        TokenCandidate top_candidates[3] = {
            {-1, -999999.0f},
            {-1, -999999.0f},
            {-1, -999999.0f}
        };

        for (int i = 0; i < MODEL_VOCAB_SIZE; i++) {
            float current_dot_product = 0.0f;
            float candidate_norm_sq = 0.0f;
            for (int j = 0; j < MODEL_DIM; j++) {
                float candidate_value = token_embedding[i][j];
                current_dot_product += normalized_vector[j] * candidate_value;
                candidate_norm_sq += candidate_value * candidate_value;
            }

            // turn this into a true cosine similarity
            float candidate_norm = fast_sqrt(candidate_norm_sq);
            if (candidate_norm > 1e-6f) {
                current_dot_product /= candidate_norm;
            }

            // check context window tracking array to penalize recent tokens
            for (int h = 0; h < 5; h++) {
                if (i == recent_history[h]) {
                    current_dot_product -= 12.0f;
                    break;
                }
            }

            if (current_dot_product > top_candidates[0].score) {
                top_candidates[2] = top_candidates[1];
                top_candidates[1] = top_candidates[0];
                top_candidates[0].id = i;
                top_candidates[0].score = current_dot_product;
            } else if (current_dot_product > top_candidates[1].score) {
                top_candidates[2] = top_candidates[1];
                top_candidates[1].id = i;
                top_candidates[1].score = current_dot_product;
            } else if (current_dot_product > top_candidates[2].score) {
                top_candidates[2].id = i;
                top_candidates[2].score = current_dot_product;
            }
        }

        // select outcome based on chosen randomness parameters
        int next_predicted_token = -1;
        if (choice_mode == 0) {
            // strict math configuration overrides randomization loops completely
            next_predicted_token = top_candidates[0].id;
        } else if (choice_mode == 2) {
            // high randomness splits distribution opportunities wider across candidates
            int higher_variance_index = random(0, 3);
            next_predicted_token = top_candidates[higher_variance_index].id;
        } else {
            // default balanced selection logic routine
            int default_variance_index = random(0, 2);
            next_predicted_token = top_candidates[default_variance_index].id;
        }

        if (next_predicted_token == -1) {
            next_predicted_token = top_candidates[0].id;
        }

        print_embedded_token(next_predicted_token);
        Serial.print(F(" "));

        active_token = next_predicted_token;

        // shift the 5-item history context window sequentially
        recent_history[4] = recent_history[3];
        recent_history[3] = recent_history[2];
        recent_history[2] = recent_history[1];
        recent_history[1] = recent_history[0];
        recent_history[0] = next_predicted_token;

        delay(150);
    }

    Serial.println(F("\nGeneration block finished."));
}
