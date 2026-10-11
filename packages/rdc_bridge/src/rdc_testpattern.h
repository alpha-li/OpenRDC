// Synthetic frame producer used to validate the frame ring and the Flutter
// texture path before FreeRDP is linked in, and to keep them testable
// independently afterwards.
//
// The pattern is deliberately diagnostic rather than pretty: see the .cpp for
// why the colour bands are ordered the way they are.

#ifndef RDC_TESTPATTERN_H_
#define RDC_TESTPATTERN_H_

#include <atomic>
#include <cstdint>
#include <thread>

#include "rdc_api.h"

namespace rdc {

class TestPatternSession {
 public:
  TestPatternSession() = default;
  TestPatternSession(const TestPatternSession&) = delete;
  TestPatternSession& operator=(const TestPatternSession&) = delete;
  ~TestPatternSession();

  // Starts the producer thread. Returns RDC_OK, or RDC_ERR_ALREADY_RUNNING when
  // a session is already up.
  int32_t Start(int32_t width, int32_t height);

  // Stops the producer thread and joins it. Safe to call when not running.
  void Stop();

  bool running() const { return running_.load(); }

 private:
  void Run();

  std::thread thread_;
  std::atomic<bool> running_{false};
};

}  // namespace rdc

#endif  // RDC_TESTPATTERN_H_
