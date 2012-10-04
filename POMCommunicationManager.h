//
//  POMCommunicationManager.h
//  
//
//  Created by Frank Le Grand on 7/8/11.
//  Copyright 2011 Troppus Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "INativeComm.h"

extern NSString * const kNotification;
extern NSString * const kNotificationMessage;

@class AsyncSocket;
@class POMResponse;

/**
 *
 * Delegate Protocol
 *
**/
@protocol POMCommunicationManagerDelegate <NSObject>

@optional
- (void)didReceiveMessage:(NSString *)message OnPort:(NSNumber *)port;
- (void)didReceiveError:(NSString *)errorMsg;

@required
- (void)didConnectToHost:(NSString *)host;
- (void)didDisconnect;
- (void)didReceivePOMResponse:(POMResponse *)pomMessage;

@end


/**
 *
 * Class Interface
 *
**/
@interface POMCommunicationManager : NSObject <INativeComm> {
    AsyncSocket *socket;
    BOOL isRunning;
    NSNotificationCenter* notificationCenter;
    id <POMCommunicationManagerDelegate> delegate;
}

@property (readwrite, assign) BOOL isRunning;
@property (nonatomic, assign) id <POMCommunicationManagerDelegate> delegate;

- (void)connectToHost:(NSString *)hostName onPort:(int)port;
- (void)sendMessage:(NSString *)message;
- (void)sendMessageWithData:(NSData *)data; //Added 7/27 MTT
- (void)disconnect;

@end


