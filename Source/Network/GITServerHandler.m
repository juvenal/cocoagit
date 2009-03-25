//
//  GITServerHandler.m
//  CocoaGit
//
//  Created by Scott Chacon on 1/3/09.
//  Copyright 2009 GitHub. All rights reserved.
//

#define NULL_SHA @"0000000000000000000000000000000000000000"
#define CAPABILITIES @" report-status delete-refs "

#define DEFAULT_GIT_PORT 9418 

#import "GITRepo.h"
#import "GITObject.h"
#import "GITCommit.h"
#import "GITTree.h"
#import "GITTreeEntry.h"
#import "GITServerHandler.h"
#import "GITUtilityBelt.h"
#import "GITSocket.h"
#import "GITPackReceive.h"
#import "GITPackUpload.h"
#import "NSData+Compression.h"
#include <zlib.h>
#include <CommonCrypto/CommonDigest.h>

@implementation GITServerHandler

@synthesize workingDir;

@synthesize gitSocket;
@synthesize gitRepo;
@synthesize gitPath;

@synthesize refsRead;
@synthesize needRefs;

@synthesize capabilitiesSent;

- (void) initWithGit:(GITRepo *)git gitPath:(NSString *)gitRepoPath withSocket:(GITSocket *)gSocket
{
	gitRepo		= git;
	gitPath 	= gitRepoPath;
	gitSocket	= gSocket;
	NSLog(@"HANDLING REQUEST");
	[self handleRequest];
	NSLog(@"REQUEST HANDLED");
}

- (void) dealloc;
{
	[gitSocket release];
	[refsRead release];
	[needRefs release];
	[gitRepo release];
	[super dealloc];
}

/* 
 * initiates communication with an incoming request
 * and passes it to the appropriate receiving function
 * either upload-pack for fetches or receive-pack for pushes
 */
- (void) handleRequest {
	NSLog(@"HANDLE REQUEST");
	NSString *header, *command, *repository, *repo, *hostpath;
	header = [gitSocket readPacketLine];
	
	NSArray *values = [header componentsSeparatedByString:@" "];
	command		= [values objectAtIndex: 0];			
	repository	= [values objectAtIndex: 1];
	
	values = [repository componentsSeparatedByCharactersInSet:[NSCharacterSet controlCharacterSet]];
	repo		= [values objectAtIndex: 0];			
	hostpath	= [values objectAtIndex: 1];
	
	NSLog(@"header: %@ : %@ : %@", command, repo, hostpath);
		
	NSError *repoError;
	NSString *dir = [[self gitPath] stringByAppendingString:repo];
	NSLog(@"initializing repo");
	GITRepo *repoObj = [[GITRepo alloc] initWithRoot:dir error:&repoError];
	NSLog(@"repo initialized");
	
	NSAssert(repoObj != nil, @"Could not initialize local Git repository");
	[self setGitRepo:repoObj];

	if([command isEqualToString: @"git-receive-pack"]) {		// git push  //
		[self receivePack:repository];
	} else if ([command isEqualToString: @"git-upload-pack"]) {	// git fetch //
		[self uploadPack:repository];
	}	
	NSLog(@"REQUEST HANDLED");
}

/*** UPLOAD-PACK FUNCTIONS ***/

- (void) uploadPack:(NSString *)repositoryName {
	[self sendRefs];
	[self receiveNeeds];
	GITPackUpload *upload = [[GITPackUpload alloc] initWithGit:gitRepo socket:gitSocket refs:needRefs];
	if([upload uploadPackFile])
		[self updateRemoteRefs];
}

- (void) updateRemoteRefs 
{
	// TODO : update remote references
}

- (void) receiveNeeds
{
	NSLog(@"receive needs");
	NSString *data;
	//NSString *cmd, *sha;
	NSArray *values;
	
	NSMutableArray *nRefs = [[NSMutableArray alloc] init];
	
	while ((data = [gitSocket readPacketLine]) && (![data isEqualToString:@"done\n"])) {
		//NSLog(@"packet: %@ => %@", data, [data dataUsingEncoding:NSASCIIStringEncoding]);
		if([data length] > 40) {
			NSLog(@"data line: %@", data);
			
			values = [data componentsSeparatedByString:@" "];
			// not using these?
			//cmd	= [values objectAtIndex: 0];			
			//sha	= [values objectAtIndex: 1];
			
			[nRefs addObject:values];
		}
	}
	
	//puts @session.recv(9)
	NSLog(@"need refs:%@", nRefs);
	[self setNeedRefs:nRefs];
	[nRefs release];
	
	NSLog(@"sending nack");
	[gitSocket writePacketLine:@"NAK"];
}

/*** UPLOAD-PACK FUNCTIONS END ***/



/*** RECEIVE-PACK FUNCTIONS ***/

/*
 * handles a push request - this involves validating the request,
 * initializing the repository if it's not there, sending the
 * refs we have, receiving the packfile form the client and unpacking
 * the packed objects (eventually we should have an option to keep the
 * packfile and build an index instead)
 */
- (void) receivePack:(NSString *)repositoryName {
	capabilitiesSent = false;
	NSLog(@"rec pack");
	[self sendRefs];
	[self readRefs];
	GITPackReceive *pack = [[GITPackReceive alloc] initWithGit:gitRepo socket:gitSocket];
	if([pack readPackFile])
		[self writeRefs];
	[gitSocket packetFlush];
}

- (void) sendRefs {
	NSLog(@"send refs");
	
	NSArray *refs = [gitRepo refs];
	NSLog(@"refs: %@", refs);
	
	NSEnumerator *e = [refs objectEnumerator];
	NSString *refName, *shaValue;
	NSDictionary *thisRef;
	while ( (thisRef = [e nextObject]) ) {
		refName  = [thisRef valueForKey:@"name"];
		shaValue = [thisRef valueForKey:@"sha"];
		[self sendRef:refName sha:shaValue];
	}
	
	// send capabilities and null sha to client if no refs //
	if(!capabilitiesSent)
		[self sendRef:@"capabilities^{}" sha:NULL_SHA];
	[gitSocket packetFlush];
}

- (void) sendRef:(NSString *)refName sha:(NSString *)shaString {
	NSMutableData *sendData = [[NSMutableData alloc] init];
  
	[sendData appendData:[[NSString stringWithFormat:@"%@ %@", shaString, refName]
						  dataUsingEncoding:NSUTF8StringEncoding]];
  
	if (!capabilitiesSent) {
		[sendData appendData:[NSData dataWithBytes:"\0" length:1]];
		[sendData appendData:[CAPABILITIES dataUsingEncoding:NSUTF8StringEncoding]];
	}
  
	[sendData appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
  
	[gitSocket sendDataWithLengthHeader:sendData];
  
	[sendData release];
	capabilitiesSent = true;
}

- (void) readRefs {
	NSString *data, *old, *new, *refName, *cap, *refStuff;
	NSLog(@"read refs");
	data = [gitSocket readPacketLine];
	NSMutableArray *refs = [[NSMutableArray alloc] init];
	while([data length] > 0) {
		
		NSArray  *values  = [data componentsSeparatedByString:@" "];
		old = [values objectAtIndex:0];
		new = [values objectAtIndex:1];
		refStuff = [values objectAtIndex:2];
		
		NSArray  *ref  = [refStuff componentsSeparatedByString:@"\0"];
		refName = [ref objectAtIndex:0];
		cap = nil;
		if([ref count] > 1) 
			cap = [ref objectAtIndex:1];
		
		NSArray *refData = [NSArray arrayWithObjects:old, new, refName, cap, nil];
		[refs addObject:refData];  // save the refs for writing later
		
		/* DEBUGGING */
		NSLog(@"ref: [%@ : %@ : %@ : %@]", old, new, refName, cap);
		
		data = [gitSocket readPacketLine];
	}
	
	[self setRefsRead:refs];
	[refs release];
}

/*
 * write refs to disk after successful read
 */
- (void) writeRefs {
	NSLog(@"write refs");
	NSEnumerator *e = [refsRead objectEnumerator];
	NSArray *thisRef;
	NSString *toSha, *refName, *sendOk;
	
	[gitSocket writePacketLine:@"unpack ok\n"];
	
	while ( (thisRef = [e nextObject]) ) {
		NSLog(@"ref: %@", thisRef);
		toSha   = [thisRef objectAtIndex:1];
		refName = [thisRef objectAtIndex:2];
		[gitRepo updateRef:refName toSha:toSha];
		sendOk = [NSString stringWithFormat:@"ok %@\n", refName];
		[gitSocket writePacketLine:sendOk];
	}	
}


@end
