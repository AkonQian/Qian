#import "MotoBadgeCodec.h"
#include "badge_protocol/badge_protocol.hpp"
@implementation MotoBadgeReply
@end
@implementation MotoBadgeCodec
+ (NSString*)rxUUID { return [NSString stringWithUTF8String:moto::badge::kRxUuid]; }
+ (NSString*)txUUID { return [NSString stringWithUTF8String:moto::badge::kTxUuid]; }
+ (NSData*)beginPayload:(NSData*)data {
  std::uint8_t bytes[8]{};
  moto::badge::write32(bytes, static_cast<std::uint32_t>(data.length));
  moto::badge::write32(bytes + 4, moto::badge::crc32(static_cast<const std::uint8_t*>(data.bytes), data.length));
  return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}
+ (NSData*)requestWithOperation:(uint8_t)operation requestID:(uint32_t)requestID
    slot:(uint8_t)slot kind:(uint8_t)kind offset:(uint32_t)offset payload:(NSData*)payload {
  moto::badge::Packet packet{};
  packet.op = operation; packet.id = requestID; packet.slot = slot;
  packet.kind = kind; packet.offset = offset;
  if (payload.length) {
    const auto* bytes = static_cast<const std::uint8_t*>(payload.bytes);
    packet.payload.assign(bytes, bytes + payload.length);
  }
  const auto bytes = moto::badge::encode(packet);
  return [NSData dataWithBytes:bytes.data() length:bytes.size()];
}
+ (nullable MotoBadgeReply*)decodeReply:(NSData*)data {
  moto::badge::Packet packet{};
  if (!moto::badge::decode(static_cast<const std::uint8_t*>(data.bytes), data.length, packet) ||
      !(packet.op & 0x80) || packet.payload.size() != 5 || packet.kind > 7) return nil;
  if (packet.payload[0] != 255 && packet.payload[0] >= moto::badge::kSlots) return nil;
  for (unsigned i = 1; i < 5; ++i) if (packet.payload[i] > 2) return nil;
  MotoBadgeReply* reply = [MotoBadgeReply new];
  reply.operation = packet.op & 0x7f; reply.requestID = packet.id;
  reply.slot = packet.slot; reply.status = packet.kind; reply.offset = packet.offset;
  reply.selected = packet.payload[0];
  reply.formats = @[@(packet.payload[1]), @(packet.payload[2]), @(packet.payload[3]), @(packet.payload[4])];
  return reply;
}
@end
