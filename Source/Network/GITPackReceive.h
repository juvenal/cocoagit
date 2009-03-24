//
//  GITPackReceive.h
//  CocoaGit
//
//  Created by Scott Chacon on 3/24/09.
//  Copyright 2009 Logical Awesome. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GITServerHandler.h"
#import "GITPackFile.h"
#import "GITRepo.h"
#import "GITSocket.h"

@interface GITPackReceive : NSObject {
	GITSocket	*gitSocket;
	GITRepo		*gitRepo;
}

@property(retain, readwrite) GITSocket	*gitSocket;
@property(retain, readwrite) GITRepo	*gitRepo;

- (id) initWithGit:(GITRepo *)git socket:(GITSocket *)gSocket;

- (bool) readPackFile;
- (int) readPackHeader;

- (void) unpackObject;
- (void) unpackDeltified:(int)type size:(int)size;

- (NSData *) patchDelta:(NSData *)deltaData withObject:(GITObject *)gitObject;
- (NSArray *) patchDeltaHeaderSize:(NSData *)deltaData position:(unsigned long)position;

- (NSString *)readServerSha;

@end
