#pragma once
#include <cstddef>
#include <cstdint>
#include <vector>

namespace moto::badge {
constexpr std::size_t kSlots = 4;
constexpr std::uint32_t kMaximumBytes = 512 * 1024;
constexpr std::uint16_t kMaximumDimension = 466;
constexpr std::size_t kHeaderSize = 16;
constexpr char kRxUuid[] = "7e57a003-b50c-4b6a-9c57-40a54e8e1000";
constexpr char kTxUuid[] = "7e57a004-b50c-4b6a-9c57-40a54e8e1000";
enum class Op : std::uint8_t { List = 1, Begin, Chunk, Commit, Remove, Select };
enum class Format : std::uint8_t { Empty = 0, Jpeg = 1, Gif = 2 };
enum class Status : std::uint8_t {
  Ok = 0, Invalid, Busy, Storage, Order, Checksum, Image, NotReady
};
struct Packet {
  std::uint8_t op = 0;
  std::uint32_t id = 0;
  std::uint8_t slot = 0;
  std::uint8_t kind = 0;
  std::uint32_t offset = 0;
  std::vector<std::uint8_t> payload;
};
inline std::uint32_t read32(const std::uint8_t* p) {
  return std::uint32_t(p[0]) | (std::uint32_t(p[1]) << 8) |
      (std::uint32_t(p[2]) << 16) | (std::uint32_t(p[3]) << 24);
}
inline void write32(std::uint8_t* p, std::uint32_t v) {
  for (unsigned i = 0; i < 4; ++i) p[i] = std::uint8_t(v >> (8 * i));
}
inline bool decode(const std::uint8_t* data, std::size_t size, Packet& output) {
  if (data == nullptr || size < kHeaderSize || size > 240 ||
      data[0] != 'B' || data[1] != 'G' || data[2] != 1 ||
      std::size_t(data[10] | (std::uint16_t(data[11]) << 8)) != size - kHeaderSize)
    return false;
  const auto op = data[3] & 0x7f;
  if (op < 1 || op > 6) return false;
  output.op = data[3]; output.id = read32(data + 4);
  output.slot = data[8]; output.kind = data[9];
  output.offset = read32(data + 12);
  output.payload.assign(data + kHeaderSize, data + size);
  return true;
}
inline std::vector<std::uint8_t> encode(const Packet& packet) {
  if (packet.payload.size() > 240 - kHeaderSize) return {};
  std::vector<std::uint8_t> bytes(kHeaderSize + packet.payload.size(), 0);
  bytes[0] = 'B'; bytes[1] = 'G'; bytes[2] = 1; bytes[3] = packet.op;
  write32(bytes.data() + 4, packet.id);
  bytes[8] = packet.slot; bytes[9] = packet.kind;
  bytes[10] = std::uint8_t(packet.payload.size());
  bytes[11] = std::uint8_t(packet.payload.size() >> 8);
  write32(bytes.data() + 12, packet.offset);
  for (std::size_t i = 0; i < packet.payload.size(); ++i) bytes[kHeaderSize + i] = packet.payload[i];
  return bytes;
}
// Streaming IEEE CRC-32. Pass 0 initially, then the previous returned value.
inline std::uint32_t crc32(const std::uint8_t* data, std::size_t length,
                           std::uint32_t previous = 0) {
  std::uint32_t crc = ~previous;
  for (std::size_t i = 0; i < length; ++i) {
    crc ^= data[i];
    for (unsigned bit = 0; bit < 8; ++bit)
      crc = (crc >> 1) ^ ((crc & 1) ? 0xedb88320U : 0U);
  }
  return ~crc;
}
inline bool valid_format(std::uint8_t kind) { return kind == 1 || kind == 2; }
} // namespace moto::badge
