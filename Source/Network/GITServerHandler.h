//
//  GITServerHandler.h
//  CocoaGit
//
//  Created by Scott Chacon on 1/3/09.
//  Copyright 2009 GitHub. All rights reserved.
//

#include <CommonCrypto/CommonDigest.h>
#import "GITRepo.h"
#import "GITObject.h"
#import "GITSocket.h"

@interface GITServerHandler : NSObject {
	NSString *workingDir;

	GITSocket	*gitSocket;
	GITRepo		*gitRepo;
	NSString	*gitPath;

	NSMutableArray *refsRead;
	NSMutableArray *needRefs;
	
	bool	capabilitiesSent; 
}

@property(copy, readwrite) NSString *workingDir;

@property(retain, readwrite) GITSocket	*gitSocket;
@property(retain, readwrite) GITRepo	*gitRepo;
@property(retain, readwrite) NSString	*gitPath;

@property(copy, readwrite) NSMutableArray *refsRead;
@property(copy, readwrite) NSMutableArray *needRefs;

@property(assign, readwrite) bool capabilitiesSent;


- (void) initWithGit:(GITRepo *)git gitPath:(NSString *)gitRepoPath withSocket:(GITSocket *)gSocket;
- (void) handleRequest;

- (void) uploadPack:(NSString *)repositoryName;
- (void) receiveNeeds;
- (void) updateRemoteRefs;

- (void) receivePack:(NSString *)repositoryName;
- (void) sendRefs;
- (void) sendRef:(NSString *)refName sha:(NSString *)shaString;
- (void) readRefs;
- (void) writeRefs;

@end
