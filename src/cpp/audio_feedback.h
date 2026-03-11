#pragma once

namespace AudioFeedback {

// Initialize waveOut device for tone playback.
// Call once during startup (after PathResolver::Init).
bool Init();

// Shut down waveOut device and free resources.
void Shutdown();

// Play a sine wave tone at the given frequency and duration.
// Non-blocking: waveOut plays asynchronously.
// If a previous tone is still playing, it is cut off.
void PlayTone(int frequencyHz, int durationMs);

// Play a tone with white noise mixed in (for armor damage feedback).
// 60% triangle wave + 40% white noise. Same envelope and amplitude as PlayTone.
void PlayNoiseTone(int frequencyHz, int durationMs);

}
