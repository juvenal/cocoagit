//
//  GITPackUpload.m
//  CocoaGit
//
//  Created by Scott Chacon on 3/24/09.
//  Copyright 2009 Logical Awesome. All rights reserved.
//

#import "GITPackUpload.h"
#import "GITUtilityBelt.h"

#define PACK_SIGNATURE 0x5041434b	/* "PACK" */
#define PACK_VERSION 2

@implementation GITPackUpload

@synthesize gitRepo;
@synthesize needRefs;
@synthesize gitSocket;
@synthesize refDict;

- (id) initWithGit:(GITRepo *)git socket:(GITSocket *)gSocket refs:(NSArray *) nRefs;
{
	gitRepo = git;
	needRefs = nRefs;
	gitSocket = gSocket;
	return self;
}

- (bool) uploadPackFile
{
	NSLog(@"upload pack file");
	NSString *command, *shaValue;
	NSArray *thisRef;
	
	refDict = [[NSMutableDictionary alloc] init];
	
	NSEnumerator *e    = [[self needRefs] objectEnumerator];
	while ( (thisRef = [e nextObject]) ) {
		command  = [thisRef objectAtIndex:0];
		shaValue = [thisRef objectAtIndex:1];
		if([command isEqualToString:@"have"]) {
			[refDict setObject:@"have" forKey:shaValue];
		}
	}
	
	//NSLog(@"gathering shas");
	e    = [[self needRefs] objectEnumerator];
	while ( (thisRef = [e nextObject]) ) {
		command  = [thisRef objectAtIndex:0];
		shaValue = [thisRef objectAtIndex:1];
		//NSLog(@"getting SHA : %@", shaValue);
		if([command isEqualToString:@"want"]) {
			[self gatherObjectShasFromCommit:shaValue];
		}
	}
	
	[self sendPackData];
	return true; // TODO: make this false if fails
}

- (void) sendPackData
{
	NSLog(@"send pack data");
	NSString *current;
	NSEnumerator *e;
	
	CC_SHA1_CTX checksum;
	CC_SHA1_Init(&checksum);
	
	//NSArray *shas;
	//shas = [refDict keysSortedByValueUsingSelector:@selector(compare:)];
	
	uint8_t buffer[5];	
	
	// write pack header
	NSLog(@"write pack header");
	
	[self longVal:htonl(PACK_SIGNATURE) toByteBuffer:buffer];
	NSLog(@"write sig [%d %d %d %d]", buffer[0], buffer[1], buffer[2], buffer[3]);
	[self respondPack:buffer length:4 checkSum:&checksum];
	
	[self longVal:htonl(PACK_VERSION) toByteBuffer:buffer];
	NSLog(@"write ver [%d %d %d %d]", buffer[0], buffer[1], buffer[2], buffer[3]);
	[self respondPack:buffer length:4 checkSum:&checksum];
	
	[self longVal:htonl([refDict count]) toByteBuffer:buffer];
	NSLog(@"write len [%d %d %d %d]", buffer[0], buffer[1], buffer[2], buffer[3]);
	[self respondPack:buffer length:4 checkSum:&checksum];
	
	e = [refDict keyEnumerator];
	GITObject *obj;
	NSData *data;
	int size, btype, c;
	while ( (current = [e nextObject]) ) {
		obj = [gitRepo objectWithSha1:current];
		size = [obj size];
		btype = [GITObject objectTypeForString:[obj type]];
		//NSLog(@"curr:%@ %d %d", current, size, btype);
		
		c = (btype << 4) | (size & 15);
		size = (size >> 4);
		if(size > 0) 
			c |= 0x80;
		buffer[0] = c;
		[self respondPack:buffer length:1 checkSum:&checksum];
		
		while (size > 0) {
			c = size & 0x7f;
			size = (size >> 7);
			if(size > 0)
				c |= 0x80;
			buffer[0] = c;
			[self respondPack:buffer length:1 checkSum:&checksum];
		}
		
		// pack object data
		//objData = [NSData dataWithBytes:[obj rawContents] length:([obj rawContentLen])];
		data = [[obj rawData] zlibDeflate];
		
		int len = [data length];
		uint8_t dataBuffer[len + 1];
		[data getBytes:dataBuffer];
		
		[self respondPack:dataBuffer length:len checkSum:&checksum];
	}
	
	unsigned char finalSha[20];
	CC_SHA1_Final(finalSha, &checksum);
	
	[gitSocket writePacket:[NSData dataWithBytes:finalSha length:20]];
	NSLog(@"end sent");
}

- (void) respondPack:(uint8_t *)buffer length:(int)size checkSum:(CC_SHA1_CTX *)checksum 
{
	CC_SHA1_Update(checksum, buffer, size);
	[gitSocket writePacket:[NSData dataWithBytes:buffer length:size]];
}

- (void) gatherObjectShasFromCommit:(NSString *)shaValue 
{
	//NSLog(@"GATHER COMMIT SHAS");
	
	NSString *parentSha;
	GITCommit *commit = [gitRepo commitWithSha1:shaValue];
	
	//NSLog(@"GATHER COMMIT SHAS");
	
	if(commit) {
		[refDict setObject:@"_commit" forKey:shaValue];
		
		//NSLog(@"GATHER COMMIT SHAS: %@", shaValue);
		
		// add the tree objects
		[self gatherObjectShasFromTree:[commit treeSha1]];
		
		NSArray *parents = [commit parentShas];
		
		NSEnumerator *e = [parents objectEnumerator];
		while ( (parentSha = [e nextObject]) ) {
			//NSLog(@"parent sha:%@", parentSha);
			// check that we have not already traversed this commit
			if (![refDict valueForKey:parentSha]) {
				[self gatherObjectShasFromCommit:parentSha];
			}
		}
	}
}

- (void) gatherObjectShasFromTree:(NSString *)shaValue 
{
	//NSLog(@"GATHER TREE SHAS: %@", shaValue);
	
	GITTree *tree = [gitRepo treeWithSha1:shaValue];
	[refDict setObject:@"/" forKey:shaValue];
	
	NSArray *treeEntries = [NSArray arrayWithArray:[tree entries]];
	[tree release];
	
	NSString *name, *sha;
	int mode;
	for (GITTreeEntry *entry in treeEntries) {
		mode = [entry mode];
		name = [entry name];
		sha = [entry sha1];
		if (![refDict valueForKey:sha]) {
			[refDict setObject:name forKey:sha];
			if (mode == 40000) { // tree
				[self gatherObjectShasFromTree:sha];
			}
		}
	}	
}


@end
