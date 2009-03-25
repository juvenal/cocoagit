//
//  GITPackUpload.h
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

@interface GITPackUpload : NSObject {
	GITRepo		*gitRepo;
	GITSocket	*gitSocket;
	NSMutableArray		*needRefs;
	NSMutableDictionary *refDict;
}

@property(retain, readwrite) GITSocket	*gitSocket;
@property(retain, readwrite) GITRepo	*gitRepo;
@property(copy, readwrite)	 NSMutableArray	*needRefs;
@property(copy, readwrite) NSMutableDictionary *refDict;

- (id) initWithGit:(GITRepo *)gRepo socket:(GITSocket *)gSocket refs:(NSMutableArray *) nRefs;

- (bool) uploadPackFile;
- (void) sendPackData;

- (void) gatherObjectShasFromCommit:(NSString *)shaValue;
- (void) gatherObjectShasFromTree:(NSString *)shaValue;
- (void) respondPack:(uint8_t *)buffer length:(int)size checkSum:(CC_SHA1_CTX *)checksum;

@end
