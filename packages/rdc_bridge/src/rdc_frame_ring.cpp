#include "rdc_frame_ring.h"

#include <cstring>

namespace rdc {

void FrameRing::Reset(int32_t width, int32_t height) {
  std::lock_guard<std::mutex> lock(mutex_);
  width_ = width > 0 ? width : 0;
  height_ = height > 0 ? height : 0;

  const size_t bytes = static_cast<size_t>(stride()) * static_cast<size_t>(height_);
  for (int i = 0; i < kSlotCount; ++i) {
    slots_[i].assign(bytes, 0);
    pinned_[i] = false;
  }
  published_ = -1;
  writing_ = 0;
}

bool FrameRing::IsAllocated() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return width_ > 0 && height_ > 0;
}

uint8_t* FrameRing::BeginWrite() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (width_ <= 0 || height_ <= 0) {
    return nullptr;
  }
  return slots_[writing_].data();
}

void FrameRing::EndWrite() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (width_ <= 0 || height_ <= 0) {
    return;
  }
  published_ = writing_;
  writing_ = FindWritableSlotLocked();
}

const uint8_t* FrameRing::Acquire(int32_t* out_width, int32_t* out_height, int32_t* out_stride,
                                  int32_t* out_release_token) {
  std::lock_guard<std::mutex> lock(mutex_);
  if (published_ < 0 || width_ <= 0 || height_ <= 0) {
    return nullptr;
  }
  const int slot = published_;
  pinned_[slot] = true;

  // The out parameters are named `out_*` rather than matching the members they
  // carry: a plain `stride` would shadow the member function of the same name
  // and turn the call below into an attempt to invoke a pointer.
  if (out_width != nullptr) {
    *out_width = width_;
  }
  if (out_height != nullptr) {
    *out_height = height_;
  }
  if (out_stride != nullptr) {
    *out_stride = stride();
  }
  if (out_release_token != nullptr) {
    *out_release_token = slot;
  }
  return slots_[slot].data();
}

void FrameRing::Release(int32_t release_token) {
  if (release_token < 0 || release_token >= kSlotCount) {
    return;
  }
  std::lock_guard<std::mutex> lock(mutex_);
  pinned_[release_token] = false;
}

// Called with mutex_ held.
//
// Any slot other than the published one will do, as long as the consumer is not
// currently pinning it. The consumer pins at most one slot at a time and there
// are three, so a free slot always exists; the fallback keeps the producer
// running (at the cost of one possibly torn frame) rather than stalling.
int FrameRing::FindWritableSlotLocked() const {
  for (int i = 0; i < kSlotCount; ++i) {
    if (i != published_ && !pinned_[i]) {
      return i;
    }
  }
  return writing_;
}

}  // namespace rdc
