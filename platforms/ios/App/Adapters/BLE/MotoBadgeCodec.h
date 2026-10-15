#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface MotoBadgeReply : NSObject
@property(nonatomic) uint8_t operation;
@property(nonatomic) uint32_t requestID;
@property(nonatomic) uint8_t slot;
@property(nonatomic) uint8_t status;
@property(nonatomic) uint32_t offset;
@property(nonatomic) uint8_t selected;
@property(nonatomic, copy) NSArray<NSNumber*>* formats;
@end
@interface MotoBadgeCodec : NSObject
+ (NSString*)rxUUID;
+ (NSString*)txUUID;
+ (NSData*)beginPayload:(NSData*)data NS_SWIFT_NAME(beginPayload(_:));
+ (NSData*)requestWithOperation:(uint8_t)operation requestID:(uint32_t)requestID
    slot:(uint8_t)slot kind:(uint8_t)kind offset:(uint32_t)offset payload:(NSData*)payload
    NS_SWIFT_NAME(request(operation:requestID:slot:kind:offset:payload:));
+ (nullable MotoBadgeReply*)decodeReply:(NSData*)data NS_SWIFT_NAME(decodeReply(_:));
@end
NS_ASSUME_NONNULL_END
