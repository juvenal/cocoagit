//
//  GITClient.m
//  CocoaGit
//
//  Created by Scott Chacon on 1/3/09.
//  Copyright 2009 GitHub. All rights reserved.
//
//  Need to move this into GitFetchProcess
//

#import "GITClient.h"
#import "GITUtilityBelt.h"
#import "GITSocket.h"

@implementation GITClient

@synthesize gitSocket;

- (BOOL) clone:(NSString *) url;
{
	NSLog(@"clone url %@", url);
	
	NSMutableData* 	response;
	NSString* 		userHostName;
	NSString* 		userPath;
	int 		userPort;
	NSURL*		userURL;
	
	NS_DURING
	
	// Parse host, port, and path out of user's URL
	
	userURL = [NSURL URLWithString:url];
	userPort = [[userURL port] intValue];
	userHostName = [userURL host];
	userPath = [userURL path];
	
	// if ([[gitURL scheme] isEqualToString:@"git"]) {

	if ( userPort == 0 )
		userPort = 9418;

	NSLog(@"cloning from [ %d : %@ : %@ ]", userPort, userHostName, userPath);
	
	// Construct request 
	// "0032git-upload-pack /project.git\000host=myserver.com\000"
	NSString *request = [[NSString alloc] initWithFormat:@"git-upload-pack %@\0host=%@\0", userPath, userHostName];
	NSLog(@"request %@", request);
	
	// Create socket, connect, and send request
	
	gitSocket = [[GITSocket alloc] init];
	[gitSocket connectToHostName:userHostName port:userPort];
	
	NSLog(@"connected");

	//[self writeServer:request];
	
	// Read response from server
	
	response = [[[NSString alloc] init] autorelease];

	NSLog(@"wrote");

	
	return true;
	
	NS_HANDLER
	
	// If an exception occurs, ...
	NSLog(@"error");

	NS_ENDHANDLER

	return false;
}

@end
