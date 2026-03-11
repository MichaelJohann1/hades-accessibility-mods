#include "audio_feedback.h"
#include "logger.h"

#include <Windows.h>
#include <mmsystem.h>
#include <cmath>
#include <mutex>

#pragma comment(lib, "winmm.lib")

namespace AudioFeedback {

static constexpr int SAMPLE_RATE = 44100;
static constexpr int BITS_PER_SAMPLE = 16;
static constexpr int NUM_CHANNELS = 1;
static constexpr int BLOCK_ALIGN = NUM_CHANNELS * (BITS_PER_SAMPLE / 8);
static constexpr int MAX_DURATION_MS = 200;
static constexpr int MAX_SAMPLES = SAMPLE_RATE * MAX_DURATION_MS / 1000;
static constexpr int BUFFER_BYTES = MAX_SAMPLES * BLOCK_ALIGN;
static constexpr int NUM_BUFFERS = 3;
static constexpr double PI = 3.14159265358979323846;

static HWAVEOUT s_hwo = nullptr;
static WAVEHDR s_headers[NUM_BUFFERS] = {};
static short s_buffers[NUM_BUFFERS][MAX_SAMPLES] = {};
static int s_currentBuffer = 0;
static std::mutex s_mutex;
static bool s_initialized = false;

bool Init()
{
    std::lock_guard<std::mutex> lock(s_mutex);

    if (s_initialized) return true;

    WAVEFORMATEX wfx = {};
    wfx.wFormatTag = WAVE_FORMAT_PCM;
    wfx.nChannels = NUM_CHANNELS;
    wfx.nSamplesPerSec = SAMPLE_RATE;
    wfx.wBitsPerSample = BITS_PER_SAMPLE;
    wfx.nBlockAlign = BLOCK_ALIGN;
    wfx.nAvgBytesPerSec = SAMPLE_RATE * BLOCK_ALIGN;

    MMRESULT res = waveOutOpen(&s_hwo, WAVE_MAPPER, &wfx, 0, 0, CALLBACK_NULL);
    if (res != MMSYSERR_NOERROR) {
        Log::Warn("[AUDIO] waveOutOpen failed: %d", (int)res);
        return false;
    }

    // Prepare both buffer headers
    for (int i = 0; i < NUM_BUFFERS; i++) {
        s_headers[i].lpData = reinterpret_cast<LPSTR>(s_buffers[i]);
        s_headers[i].dwBufferLength = BUFFER_BYTES;
        s_headers[i].dwFlags = WHDR_DONE; // Mark as done so first use doesn't need to wait
        waveOutPrepareHeader(s_hwo, &s_headers[i], sizeof(WAVEHDR));
    }

    s_initialized = true;
    Log::Info("[AUDIO] waveOut initialized (%d Hz, %d-bit, mono, %d buffers)",
              SAMPLE_RATE, BITS_PER_SAMPLE, NUM_BUFFERS);

    return true;
}

void Shutdown()
{
    std::lock_guard<std::mutex> lock(s_mutex);

    if (!s_initialized || !s_hwo) return;

    waveOutReset(s_hwo);

    for (int i = 0; i < NUM_BUFFERS; i++) {
        if (s_headers[i].dwFlags & WHDR_PREPARED) {
            waveOutUnprepareHeader(s_hwo, &s_headers[i], sizeof(WAVEHDR));
        }
    }

    waveOutClose(s_hwo);
    s_hwo = nullptr;
    s_initialized = false;
    Log::Info("[AUDIO] waveOut shut down");
}

void PlayTone(int frequencyHz, int durationMs)
{
    std::lock_guard<std::mutex> lock(s_mutex);

    if (!s_initialized || !s_hwo) return;

    // Clamp parameters
    if (frequencyHz < 20) frequencyHz = 20;
    if (frequencyHz > 20000) frequencyHz = 20000;
    if (durationMs < 1) durationMs = 1;
    if (durationMs > MAX_DURATION_MS) durationMs = MAX_DURATION_MS;

    int numSamples = SAMPLE_RATE * durationMs / 1000;
    if (numSamples > MAX_SAMPLES) numSamples = MAX_SAMPLES;
    if (numSamples < 1) return;

    // Find a free buffer (try all before resorting to waveOutReset)
    int bufIdx = -1;
    for (int attempt = 0; attempt < NUM_BUFFERS; attempt++) {
        int idx = (s_currentBuffer + attempt) % NUM_BUFFERS;
        if (s_headers[idx].dwFlags & WHDR_DONE) {
            bufIdx = idx;
            break;
        }
    }
    if (bufIdx < 0) {
        // All buffers busy — reset device as last resort
        waveOutReset(s_hwo);
        bufIdx = s_currentBuffer;
    }
    s_currentBuffer = (bufIdx + 1) % NUM_BUFFERS;

    WAVEHDR* hdr = &s_headers[bufIdx];
    short* buf = s_buffers[bufIdx];

    // Generate triangle wave with cosine fade-in/fade-out envelope
    // (approach from NVDA "Pleasant Progress Bar" addon)
    int fadeSamples = static_cast<int>(numSamples * 0.45); // 45% fade on each end
    double period = static_cast<double>(SAMPLE_RATE) / frequencyHz;
    double halfPeriod = period / 2.0;

    for (int i = 0; i < numSamples; i++) {
        // Triangle wave: linear ramp -1 to +1 to -1
        double pos = fmod(static_cast<double>(i), period);
        double sample;
        if (pos <= halfPeriod) {
            sample = (pos / halfPeriod) * 2.0 - 1.0;
        } else {
            sample = 1.0 - ((pos - halfPeriod) / halfPeriod) * 2.0;
        }

        // Raised cosine envelope (fade-in + fade-out)
        double envelope = 1.0;
        if (fadeSamples > 0) {
            if (i < fadeSamples) {
                envelope = (1.0 - cos(PI * i / fadeSamples)) / 2.0;
            } else if (i >= numSamples - fadeSamples) {
                int fadeIndex = numSamples - i - 1;
                envelope = (1.0 - cos(PI * fadeIndex / fadeSamples)) / 2.0;
            }
        }

        buf[i] = static_cast<short>(10000.0 * envelope * sample);
    }

    // Update header for actual size and write
    hdr->dwBufferLength = numSamples * BLOCK_ALIGN;
    hdr->dwFlags &= ~WHDR_DONE; // Clear done flag
    MMRESULT res = waveOutWrite(s_hwo, hdr, sizeof(WAVEHDR));
    if (res != MMSYSERR_NOERROR) {
        Log::Warn("[AUDIO] waveOutWrite failed: %d", (int)res);
    }
}

void PlayNoiseTone(int frequencyHz, int durationMs)
{
    std::lock_guard<std::mutex> lock(s_mutex);

    if (!s_initialized || !s_hwo) return;

    // Clamp parameters
    if (frequencyHz < 20) frequencyHz = 20;
    if (frequencyHz > 20000) frequencyHz = 20000;
    if (durationMs < 1) durationMs = 1;
    if (durationMs > MAX_DURATION_MS) durationMs = MAX_DURATION_MS;

    int numSamples = SAMPLE_RATE * durationMs / 1000;
    if (numSamples > MAX_SAMPLES) numSamples = MAX_SAMPLES;
    if (numSamples < 1) return;

    // Find a free buffer (try all before resorting to waveOutReset)
    int bufIdx = -1;
    for (int attempt = 0; attempt < NUM_BUFFERS; attempt++) {
        int idx = (s_currentBuffer + attempt) % NUM_BUFFERS;
        if (s_headers[idx].dwFlags & WHDR_DONE) {
            bufIdx = idx;
            break;
        }
    }
    if (bufIdx < 0) {
        waveOutReset(s_hwo);
        bufIdx = s_currentBuffer;
    }
    s_currentBuffer = (bufIdx + 1) % NUM_BUFFERS;

    WAVEHDR* hdr = &s_headers[bufIdx];
    short* buf = s_buffers[bufIdx];

    // Generate triangle wave mixed with white noise (for armor feedback)
    static unsigned int s_rng = 12345; // Simple LCG PRNG state
    constexpr double TONE_MIX = 0.60;
    constexpr double NOISE_MIX = 0.40;

    int fadeSamples = static_cast<int>(numSamples * 0.45);
    double period = static_cast<double>(SAMPLE_RATE) / frequencyHz;
    double halfPeriod = period / 2.0;

    for (int i = 0; i < numSamples; i++) {
        // Triangle wave
        double pos = fmod(static_cast<double>(i), period);
        double toneSample;
        if (pos <= halfPeriod) {
            toneSample = (pos / halfPeriod) * 2.0 - 1.0;
        } else {
            toneSample = 1.0 - ((pos - halfPeriod) / halfPeriod) * 2.0;
        }

        // White noise via LCG PRNG
        s_rng = s_rng * 1103515245 + 12345;
        double noise = ((s_rng >> 16) & 0x7FFF) / 16383.5 - 1.0;

        // Mix tone + noise
        double sample = TONE_MIX * toneSample + NOISE_MIX * noise;

        // Raised cosine envelope (same as PlayTone)
        double envelope = 1.0;
        if (fadeSamples > 0) {
            if (i < fadeSamples) {
                envelope = (1.0 - cos(PI * i / fadeSamples)) / 2.0;
            } else if (i >= numSamples - fadeSamples) {
                int fadeIndex = numSamples - i - 1;
                envelope = (1.0 - cos(PI * fadeIndex / fadeSamples)) / 2.0;
            }
        }

        buf[i] = static_cast<short>(10000.0 * envelope * sample);
    }

    hdr->dwBufferLength = numSamples * BLOCK_ALIGN;
    hdr->dwFlags &= ~WHDR_DONE;
    MMRESULT res = waveOutWrite(s_hwo, hdr, sizeof(WAVEHDR));
    if (res != MMSYSERR_NOERROR) {
        Log::Warn("[AUDIO] waveOutWrite (noise) failed: %d", (int)res);
    }
}

} // namespace AudioFeedback
