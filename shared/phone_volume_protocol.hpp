#pragma once
#include <cstddef>
#include <cstdint>

namespace moto::media {
// Optional encrypted characteristic on the existing navigation service.
// v1 navigation frames and the four-slot badge wire format remain unchanged.
inline constexpr char kPhoneVolumeUuid[] = "7E57A005-B50C-4B6A-9C57-40A54E8E1000";
inline constexpr std::uint8_t kUnknownVolume = 255;
inline bool decode_phone_volume(const std::uint8_t* bytes, std::size_t length,
                                std::uint8_t& percent) {
  if(bytes == nullptr || length != 2 || bytes[0] != 1 ||
     (bytes[1] > 100 && bytes[1] != kUnknownVolume)) return false;
  percent = bytes[1];
  return true;
}
class VolumeTelemetry {
 public:
  void update(std::uint8_t percent, std::uint64_t now) { percent_=percent; at_=now; }
  void reset() { percent_=kUnknownVolume; at_=0; }
  bool expire(std::uint64_t now) {
    if(percent_ == kUnknownVolume || now < at_ || now-at_ < 6000) return false;
    reset(); return true;
  }
  std::uint8_t percent() const { return percent_; }
 private:
  std::uint8_t percent_=kUnknownVolume;
  std::uint64_t at_=0;
};
}
