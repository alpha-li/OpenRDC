// Three-slot frame ring shared between the producer (the RDP decode thread,
// later FreeRDP's event-loop thread) and the consumer (Flutter's raster thread,
// which calls in through the platform texture presenter).
//
// Why three slots: the consumer pins the frame it is currently uploading, the
// producer owns one slot to draw into, and one slot stays spare. That leaves
// the producer a writable slot even while a frame is pinned, so it never has to
// block on the renderer. Dropping a frame is always preferable to stalling the
// protocol thread.
//
// Synchronisation is a plain mutex over the *slot bookkeeping* only. Pixel data
// is never copied under the lock; the lock is held for a handful of instructions
// once per frame on each side, so contention is not a concern. Crucially the
// producer never holds the lock while drawing, and the consumer never holds it
// while uploading.

#ifndef RDC_FRAME_RING_H_
#define RDC_FRAME_RING_H_

#include <cstdint>
#include <mutex>
#include <vector>

namespace rdc {

class FrameRing {
 public:
  static constexpr int kSlotCount = 3;
  static constexpr int kBytesPerPixel = 4;  // RGBA

  FrameRing() = default;
  FrameRing(const FrameRing&) = delete;
  FrameRing& operator=(const FrameRing&) = delete;

  // Allocates the slots. Safe to call again to change geometry (e.g. after an
  // RDP desktop resize); any pinned frame is invalidated, so the caller must
  // ensure the consumer is not mid-acquire.
  void Reset(int32_t width, int32_t height);

  bool IsAllocated() const;

  int32_t width() const { return width_; }
  int32_t height() const { return height_; }
  int32_t stride() const { return width_ * kBytesPerPixel; }

  // --- producer side -------------------------------------------------------

  // Returns the slot to draw the next frame into, or null when not allocated.
  // The previous contents are undefined; the caller must fill every pixel.
  uint8_t* BeginWrite();

  // Publishes the slot returned by BeginWrite as the current frame and selects
  // the next write slot.
  void EndWrite();

  // --- consumer side -------------------------------------------------------

  // Pins and returns the most recently published frame, or null when nothing
  // has been published yet. On success the geometry and a release token are
  // written to the out parameters.
  const uint8_t* Acquire(int32_t* width, int32_t* height, int32_t* stride, int32_t* release_token);

  // Unpins a frame returned by Acquire. Passing an invalid or already-released
  // token is a no-op.
  void Release(int32_t release_token);

 private:
  // Takes the lock.
  int FindWritableSlotLocked() const;

  mutable std::mutex mutex_;
  std::vector<uint8_t> slots_[kSlotCount];
  int32_t width_ = 0;
  int32_t height_ = 0;

  // Guarded by mutex_.
  int published_ = -1;       // slot the consumer may read, -1 before first publish
  int writing_ = 0;          // slot the producer is filling
  bool pinned_[kSlotCount] = {};
};

}  // namespace rdc

#endif  // RDC_FRAME_RING_H_
