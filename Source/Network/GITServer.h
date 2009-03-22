//
//  GITServer.h
//  CocoaGit
//
//  Created by Scott Chacon on 1/4/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GITSocket.h"

@class GITServer;

@interface GITServer : NSObject {
	GITSocket	*socket;
	NSString	*workingDir;
	
	unsigned short listen_port;
}

@property(copy, readwrite) NSString *workingDir;

- (void) startListening:(NSString *) gitStartDir;

@end
