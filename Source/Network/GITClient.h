//
//  GITClient.h
//  CocoaGit
//
//  Created by Scott Chacon on 1/3/09.
//  Copyright 2009 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GITSocket.h"

@interface GITClient : NSObject {
	GITSocket*	 	gitSocket;
}

@property(retain, readwrite) GITSocket *gitSocket;	

- (BOOL) clone:(NSString *) url;

@end
