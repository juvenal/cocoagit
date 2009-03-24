//
//  GITSocket.m
//  CocoaGit
//
//  Created by Scott Chacon on 3/22/09.
//  Copyright 2009 Logical Awesome. All rights reserved.
//

#import "GITSocket.h"
#import "GITUtilityBelt.h"
#import "NSData+Hashing.h"
#import "NSData+Searching.h"
#import "NSData+Compression.h"
#import "NSData+HexDump.h"
#include <zlib.h>

@implementation GITSocket

- (NSData *) readPacket;
{
	NSMutableData *packetLen = [self readData:4];
    NSData *nullPacket = [NSData dataWithBytes:"0000" length:4];
    
    if ([packetLen isEqualToData:nullPacket])
        return [NSData dataWithBytes:"0" length:0];
    
    NSUInteger len = hexLengthToInt((NSData *)packetLen);
    
    // check for bad length
    if (len < 0) {
        NSLog(@"protocol error: bad length");
        return nil;
    }
    
    NSMutableData *packetData = [self readData:(int)len-4];
    return [NSData dataWithData:packetData];
}

- (void) readInto:(void *)readerBuffer length:(int) len;
{
	NSMutableData *header = [self readData:len];
	[header getBytes:readerBuffer length:len];
}

- (NSString *) readPacketLine;
{
    NSData *packetData = [self readPacket];
    if (! (packetData && ([packetData length] > 0)))
        return nil;
    return [[[NSString alloc] initWithData:packetData encoding:NSASCIIStringEncoding] autorelease];
}

- (NSData *) packetByRemovingCapabilitiesFromPacket:(NSData *)data;
{
    NSRange refRange = [data rangeOfNullTerminatedBytesFrom:0];
	
    if (refRange.location == NSNotFound)
        return data;
    
    return [data subdataToIndex:refRange.length-1];
}

- (NSString *) capabilitiesWithPacket:(NSData *)data;
{
    NSRange refRange = [data rangeOfNullTerminatedBytesFrom:0];
	
    if (refRange.location == NSNotFound)
        return nil;
	
    NSUInteger capStart = refRange.length+1;
    NSData *capData = [data subdataFromIndex:capStart];
	
    return [[[NSString alloc] initWithData:capData encoding:[NSString defaultCStringEncoding]] autorelease];
}

- (NSArray *) readPackets;
{
	NSMutableArray *packets = [NSMutableArray new];
    NSData *packetData = [self readPacket];
    
    // extract capabilities string and remove '\0'
    NSString *capabilities = [self capabilitiesWithPacket:packetData];
    if (capabilities) {
        packetData = [packetData subdataToIndex:([packetData length] - [capabilities length] - 1)];
        NSLog(@"remote capabilities: %@", capabilities);
    }
	
    while (packetData && [packetData length] > 0) {
        [packets addObject:packetData];
        packetData = [self readPacket];
    }
	
    NSArray *thePackets = [NSArray arrayWithArray:packets];
    [packets release];
    return thePackets;
}

- (void) packetFlush;
{
    [self writeData:[NSData dataWithBytes:"0000" length:4]];
}

- (void) writePacket:(NSData *)thePacket;
{
    [self writeData:thePacket];
}

- (void) writePacketLine:(NSString *)packetLine;
{
    [self writePacket:[self packetWithString:packetLine]];
}

- (void) sendDataWithLengthHeader:(NSData *)data;
{
    NSUInteger len = [data length] + 4;
    NSData *hexLength = intToHexLength(len);
    NSMutableData *packetData = [NSMutableData dataWithCapacity:len];
    [packetData appendData:hexLength];
    [packetData appendData:data];
	[self writePacket:packetData];
}

- (NSData *) packetWithString:(NSString *)line;
{
    NSUInteger len = [line length] + 4;
    NSData *hexLength = intToHexLength(len);
    NSMutableData *packetData = [NSMutableData dataWithCapacity:len];
    [packetData appendData:hexLength];
    [packetData appendData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    return [NSData dataWithData:packetData];
}

+ (void) longVal:(uint32_t)raw toByteBuffer:(uint8_t *)buffer
{
	buffer[3] = (raw >> 24);
	buffer[2] = (raw >> 16);
	buffer[1] = (raw >> 8);
	buffer[0] = (raw);
}

@end
