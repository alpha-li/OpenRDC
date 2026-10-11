#include "rdc_testpattern.h"

#include <chrono>
#include <cstring>

#include "rdc_core.h"

namespace rdc {
namespace {

constexpr auto kFrameInterval = std::chrono::milliseconds(33);  // ~30 fps
constexpr int kSweepBarWidth = 48;
constexpr int kBandCount = 4;

// Horizontal bands, top to bottom. Read together with the note in Run().
struct Rgba {
  uint8_t r, g, b, a;
};
constexpr Rgba kBandColors[kBandCount] = {
    {255, 0, 0, 255},    // red
    {0, 255, 0, 255},    // green
    {0, 0, 255, 255},    // blue
    {255, 255, 255, 255} // white
};

}  // namespace

TestPatternSession::~TestPatternSession() { Stop(); }

int32_t TestPatternSession::Start(int32_t width, int32_t height) {
  if (running_.load()) {
    return RDC_ERR_ALREADY_RUNNING;
  }
  if (width <= 0 || height <= 0) {
    return RDC_ERR_BAD_ARGUMENT;
  }

  Ring().Reset(width, height);
  running_.store(true);
  thread_ = std::thread(&TestPatternSession::Run, this);
  return RDC_OK;
}

void TestPatternSession::Stop() {
  if (!running_.exchange(false)) {
    return;
  }
  if (thread_.joinable()) {
    thread_.join();
  }
}

void TestPatternSession::Run() {
  EmitState(RDC_STATE_CONNECTING, "test pattern");
  EmitState(RDC_STATE_CONNECTED, "test pattern");
  EmitDesktopSize(Ring().width(), Ring().height());

  int64_t frame = 0;
  while (running_.load()) {
    const auto frame_start = std::chrono::steady_clock::now();

    uint8_t* pixels = Ring().BeginWrite();
    if (pixels != nullptr) {
      const int32_t width = Ring().width();
      const int32_t height = Ring().height();
      const int32_t stride = Ring().stride();
      const int32_t band_height = height / kBandCount;

      for (int32_t y = 0; y < height; ++y) {
        // Clamp so the last band absorbs any rounding remainder.
        int32_t band = y / (band_height > 0 ? band_height : height);
        if (band >= kBandCount) {
          band = kBandCount - 1;
        }
        const Rgba color = kBandColors[band];

        uint8_t* row = pixels + static_cast<size_t>(y) * stride;
        for (int32_t x = 0; x < width; ++x) {
          uint8_t* px = row + static_cast<size_t>(x) * 4;
          px[0] = color.r;
          px[1] = color.g;
          px[2] = color.b;
          px[3] = color.a;
        }
      }

      // A bar sweeping left to right. It makes three things visible at once:
      // that frames advance, roughly how fast, and whether the engine is
      // presenting a torn mixture of two frames.
      const int32_t travel = width + kSweepBarWidth;
      const int32_t bar_x = static_cast<int32_t>(frame * 8 % travel) - kSweepBarWidth;
      for (int32_t y = 0; y < height; ++y) {
        uint8_t* row = pixels + static_cast<size_t>(y) * stride;
        for (int32_t x = bar_x; x < bar_x + kSweepBarWidth; ++x) {
          if (x < 0 || x >= width) {
            continue;
          }
          uint8_t* px = row + static_cast<size_t>(x) * 4;
          px[0] = 0;
          px[1] = 0;
          px[2] = 0;
          px[3] = 255;
        }
      }

      Ring().EndWrite();
      NotifyFrameReady();
    }

    ++frame;
    std::this_thread::sleep_until(frame_start + kFrameInterval);
  }

  EmitState(RDC_STATE_IDLE, "test pattern stopped");
}

}  // namespace rdc
