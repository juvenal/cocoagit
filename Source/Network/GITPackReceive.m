//
//  GITPackReceive.m
//  CocoaGit
//
//  Created by Scott Chacon on 3/24/09.
//  Copyright 2009 Logical Awesome. All rights reserved.
//

#import "GITPackReceive.h"
#import "GITUtilityBelt.h"

@implementation GITPackReceive

@synthesize gitSocket;
@synthesize gitRepo;

- (id) initWithGit:(GITRepo *)git socket:(GITSocket *)gSocket;
{	
	gitRepo = git;
	gitSocket = gSocket;
	return self;
}

/*
 * read packfile data from the stream and expand the objects out to disk
 */
- (bool) readPackFile {
	NSLog(@"read pack");
	int n;
	int entries = [self readPackHeader];
	
	for(n = 1; n <= entries; n++) {
		NSLog(@"entry: %d", n);
		[self unpackObject];
	}
	
	// receive and process checksum
	NSMutableData *checksum = [gitSocket readData:20];
	NSLog(@"checksum: %@", checksum);
	return true; // TODO: return false if this fails
} 

- (int) readPackHeader {
	NSLog(@"read pack header");
	
	uint8_t inSig[4], inVer[4], inEntries[4];
	uint32_t version, entries;
	[gitSocket readInto:inSig length:4];
	[gitSocket readInto:inVer length:4];
	[gitSocket readInto:inEntries length:4];
	
	entries = (inEntries[0] << 24) | (inEntries[1] << 16) | (inEntries[2] << 8) | inEntries[3];
	version = (inVer[0] << 24) | (inVer[1] << 16) | (inVer[2] << 8) | inVer[3];
	if(version == 2)
		return entries;
	else
		return 0;
}

- (void) unpackObject {	
	// read in the header
	int size, type, shift;
	uint8_t byte[1];
	
	NSMutableData *header = [gitSocket readData:1];
	[header getBytes:byte length:1];
	
	size = byte[0] & 0xf;
	type = (byte[0] >> 4) & 7;
	shift = 4;
	while((byte[0] & 0x80) != 0) {
		header = [gitSocket readData:1];
		[header getBytes:byte length:1];
        size |= ((byte[0] & 0x7f) << shift);
        shift += 7;
	}
	
	NSLog(@"TYPE: %d", type);
	NSLog(@"size: %d", size);
	
	if((type == GITObjectTypeCommit) || (type == GITObjectTypeTree) || (type == GITObjectTypeBlob) || (type == GITObjectTypeTag)) {
		NSData *objectData = [gitSocket readData:size];
		NSLog(@"read: %d", size);
		[gitRepo writeObject:objectData withType:[GITObject stringForObjectType:type] size:size];
		// TODO : check saved delta objects
	} else if ((type == GITObjectTypeRefDelta) || (type == GITObjectTypeOfsDelta)) {
		[self unpackDeltified:type size:size];
	} else {
		NSLog(@"bad object type %d", type);
	}
	NSLog(@"UNPACKED");
}

- (void) unpackDeltified:(int)type size:(int)size {
	if(type == GITObjectTypeRefDelta) {
		NSString *sha1;
		NSData *objectData, *contents;
		
		sha1 = [self readServerSha];
		NSLog(@"DELTA SHA: %@", sha1);
		objectData = [gitSocket readData:size];
		
		if([gitRepo hasObject:sha1]) {
			GITObject *object;
			object = [gitRepo objectWithSha1:sha1];
			contents = [self patchDelta:objectData withObject:object];
			NSLog(@"unpacked delta: %@ : %@", contents, [object type]);
			[gitRepo writeObject:contents withType:[object type] size:[contents length]];
			//[object release];
		} else {
			// TODO : OBJECT ISN'T HERE YET, SAVE THIS DELTA FOR LATER //
			/*
			 @delta_list[sha1] ||= []
			 @delta_list[sha1] << delta
			 */
		}
	} else {
		// offset deltas not supported yet
		// this isn't returned in the capabilities, so it shouldn't be a problem
	}
}

- (NSData *) patchDelta:(NSData *)deltaData withObject:(GITObject *)gitObject
{
	unsigned long sourceSize, destSize, position;
	unsigned long cp_off, cp_size;
	unsigned char c[2], d[2];
	
	int buffLength = 1000;
	NSMutableData *buffer = [[NSMutableData alloc] initWithCapacity:buffLength];
	
	NSArray *sizePos = [self patchDeltaHeaderSize:deltaData position:0];
	sourceSize	= [[sizePos objectAtIndex:0] longValue];
	position	= [[sizePos objectAtIndex:1] longValue];
	
	NSLog(@"SS: %d  Pos:%d", sourceSize, position);
	
	sizePos = [self patchDeltaHeaderSize:deltaData position:position];
	destSize	= [[sizePos objectAtIndex:0] longValue];
	position	= [[sizePos objectAtIndex:1] longValue];
	
	NSData *source = [gitObject rawData];
	
	NSLog(@"SOURCE:%@", source);
	NSMutableData *destination = [NSMutableData dataWithCapacity:destSize];
	
	while (position < ([deltaData length])) {
		[deltaData getBytes:c range:NSMakeRange(position, 1)];
		NSLog(@"DS: %d  Pos:%d", destSize, position);
		//NSLog(@"CHR: %d", c[0]);
		
		position += 1;
		if((c[0] & 0x80) != 0) {
			position -= 1;
			cp_off = cp_size = 0;
			
			if((c[0] & 0x01) != 0) {
				[deltaData getBytes:d range:NSMakeRange(position += 1, 1)];
				cp_off = d[0];
			}
			if((c[0] & 0x02) != 0) {
				[deltaData getBytes:d range:NSMakeRange(position += 1, 1)];
				cp_off |= d[0] << 8;
			}
			if((c[0] & 0x04) != 0) {
				[deltaData getBytes:d range:NSMakeRange(position += 1, 1)];
				cp_off |= d[0] << 16;
			}
			if((c[0] & 0x08) != 0) {
				[deltaData getBytes:d range:NSMakeRange(position += 1, 1)];
				cp_off |= d[0] << 24;
			}
			if((c[0] & 0x10) != 0) {
				[deltaData getBytes:d range:NSMakeRange(position += 1, 1)];
				cp_size = d[0];
			}
			if((c[0] & 0x20) != 0) {
				[deltaData getBytes:d range:NSMakeRange(position += 1, 1)];				
				cp_size |= d[0] << 8;
			}
			if((c[0] & 0x40) != 0) {
				[deltaData getBytes:d range:NSMakeRange(position += 1, 1)];
				cp_size |= d[0] << 16;
			}
			if(cp_size == 0)
				cp_size = 0x10000;
			
			position += 1;
			//NSLog(@"pos: %d", position);
			//NSLog(@"offset: %d, %d", cp_off, cp_size);
			
			if(cp_size > buffLength) {
				buffLength = cp_size + 1;
				[buffer setLength:buffLength];
			}
			
			[source getBytes:[buffer mutableBytes] range:NSMakeRange(cp_off, cp_size)];
			[destination appendBytes:[buffer bytes]	length:cp_size];
			//NSLog(@"dest: %@", destination);
		} else if(c[0] != 0) {
			if(c[0] > destSize) 
				break;
			//NSLog(@"thingy: %d, %d", position, c[0]);
			[deltaData getBytes:[buffer mutableBytes] range:NSMakeRange(position, c[0])];
			[destination appendBytes:[buffer bytes]	length:c[0]];
			position += c[0];
			destSize -= c[0];
		} else {
			NSLog(@"invalid delta data");
		}
	}
	[buffer release];
	return destination;
}

- (NSArray *) patchDeltaHeaderSize:(NSData *)deltaData position:(unsigned long)position
{
	unsigned long size = 0;
	int shift = 0;
	unsigned char c[2];
	
	do {
		[deltaData getBytes:c range:NSMakeRange(position, 1)];
		//NSLog(@"read bytes:%d %d", c[0], position);
		position += 1;
		size |= (c[0] & 0x7f) << shift;
		shift += 7;
	} while ( (c[0] & 0x80) != 0 );
	
	return [NSArray arrayWithObjects:[NSNumber numberWithLong:size], [NSNumber numberWithLong:position], nil];
}

- (NSString *) readServerSha 
{
	NSLog(@"read server sha");
	NSMutableData *rawSha = [gitSocket readData:20];
	return unpackSHA1FromData(rawSha);
}


@end
