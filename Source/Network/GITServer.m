//
//  GITServer.m
//  CocoaGit
//
//  Created by Scott Chacon on 1/4/09.
//  Copyright 2009 GitHub. All rights reserved.
//

#import "GITServer.h"
#import "GITServerHandler.h"
#import "GITRepo.h"
#import "GITSocket.h"

@implementation GITServer

@synthesize workingDir;

- (void) startListening:(NSString *) gitStartDir {
	uint16_t port = 9418;
	
	workingDir = gitStartDir;
	GITRepo* git = [GITRepo alloc];
	GITServerHandler *obsh = [[GITServerHandler alloc] init];

	NSLog(@"Connecting Socket");

	socket = [[GITSocket alloc] init];
	[socket listenOnPort:port];
	
	while(true) {
		[socket acceptConnection];
		
		if([socket isConnected]) {
			NSLog(@"INIT WITH GIT:  %@ : %@ : %@", obsh, git, workingDir);
			[obsh initWithGit:git gitPath:workingDir withSocket:socket];	
			NSLog(@"Server Handled");
		}
	}
	
	//NSError *error = nil;
}

@end
