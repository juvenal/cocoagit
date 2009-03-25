//
//  GITSocket.h
//  CocoaGit
//
//  Created by Scott Chacon on 3/22/09.
//  Copyright 2009 Logical Awesome. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BufferedSocket.h"

@interface GITSocket : BufferedSocket {

}

// packed I/O
- (NSData *) readPacket;
- (void) readInto:(void *)readerBuffer length:(int) len;
- (NSString *) readPacketLine;
- (NSArray *) readPackets;
- (void) packetFlush;
- (void) writePacket:(NSData *)thePacket;
- (void) writePacketLine:(NSString *)packetLine;
- (void) sendDataWithLengthHeader:(NSData *)data;
- (NSData *) packetWithString:(NSString *)line;

+ (void) longVal:(uint32_t)raw toByteBuffer:(uint8_t *)buffer;

@end
