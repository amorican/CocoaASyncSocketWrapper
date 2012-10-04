//
//  SocketCommunicationManager.m
//  SocketClientSample
//
//  Created by Frank Le Grand on 7/8/11.
//  Copyright 2011 Troppus Software. All rights reserved.
//

#import "POMCommunicationManager.h"
#import "AsyncSocket.h"
#import "POMRequest.h"
#import "POMResponse.h"


NSString * const kNotification = @"kNotification";
NSString * const kNotificationMessage = @"kNotificationMessage";


#pragma mark - 

@implementation POMCommunicationManager

@synthesize isRunning;
@synthesize delegate;

- (id) init {
    if (!(self = [super init]))
        return nil;
    
    socket = [[AsyncSocket alloc] initWithDelegate:self];
    [self setIsRunning:NO];
    notificationCenter = [NSNotificationCenter defaultCenter];
    
    return self;
}

// Needed due to Stupid Java...
// reverses the bytes in the 4 byte POM Message header
- (unsigned int)reverseBytes:(unsigned int)value
{
    return (value & 0xFF) << 24 | (value >> 8 & 0xFF) << 16 | (value >> 16 & 0xFF) << 8 | (value >> 24 & 0xFF);
}


- (void)connectToHost:(NSString *)hostName onPort:(int)port 
{
    if (![self isRunning]) {
        if (port < 0 || port > 65535)
            port = 0;
        
        NSError *error = nil;
        if (![socket connectToHost:hostName onPort:port error:&error]) {
            NSLog(@"Error connecting to server: %@", error);
            
            //Send error to delegate
            [self.delegate didReceiveError:[NSString stringWithFormat:@"Error connecting to server: %@", error]];
            return;
        }
        
        //Send Connection info to delegate
        [self.delegate didConnectToHost:hostName];
        
        [self setIsRunning:YES];
    } else {
        [socket disconnect];
        
        [self setIsRunning:false];
    }
}

- (void)disconnect 
{
    [socket disconnect];
    
    //Send Connection info to delegate
    [self.delegate didDisconnect];
}


- (void)dealloc 
{
    [super dealloc];
    [socket disconnect];
    [socket dealloc];
}

- (void)sendMessage:(NSString *)message 
{
    NSString *terminatedMessage = [message stringByAppendingString:@"\r\n"];
    NSData *terminatedMessageData = [terminatedMessage dataUsingEncoding:NSASCIIStringEncoding];
    [socket writeData:terminatedMessageData withTimeout:-1 tag:0];
}

- (void)sendMessageWithData:(NSData *)data
{
    [socket writeData:data withTimeout:-1 tag:1];
}


#pragma mark - INativeComm Protocol Methods

- (BOOL)requestTopic:(NSString *)topic Payload:(NSString *)payload
{
    POMRequest *request = [[POMRequest alloc] initWithType:POMTypeRequest 
                                                     Topic:topic 
                                                      UUID:[POMRequest stringWithUUID] 
                                                   Payload:payload];
    NSData *data = [request xmlDataWithLengthPrefix];
    [self sendMessageWithData:data];
    [request release];
    
    //TODO Implement YES/NO response as to whether the request was generated properly
    return YES;
}

- (BOOL)subscribeToTopic:(NSString *)topic
{
    POMRequest *request = [[POMRequest alloc] initWithType:POMTypeSubscribe 
                                                     Topic:topic 
                                                      UUID:[POMRequest stringWithUUID]];
    NSData *data = [request xmlDataWithLengthPrefix];
    [self sendMessageWithData:data];
    [request release];
    
    //TODO Implement YES/NO response as to whether the request was generated properly
    return YES;
}

- (BOOL)unSubscribeFromTopic:(NSString *)topic
{
    POMRequest *request = [[POMRequest alloc] initWithType:POMTypeUnsubscribe
                                                     Topic:topic 
                                                      UUID:[POMRequest stringWithUUID]];
    NSData *data = [request xmlDataWithLengthPrefix];
    [self sendMessageWithData:data];
    [request release];
    
    //TODO Implement YES/NO response as to whether the request was generated properly
    return YES;
}


#pragma mark AsyncSocket Delegate

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port 
{
    NSLog(@"Connected to server %@:%hu", host, port);
    //[sock readDataToData:[AsyncSocket LFData] withTimeout:-1 tag:0];
    [sock readDataToLength:4 withTimeout:-1 tag:1];
}


- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag 
{
    //NSLog(@"Data Received: %@", data);
    NSString *message = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    
    //Grab message header information
    if ([data length] == 4) 
    {
        unsigned int temp = *(int *)[data bytes];
        unsigned int readLen;
        readLen = [self reverseBytes:temp];
        [sock readDataToLength:readLen withTimeout:-1 tag:1];
        
    } else {
        // Debug log statement
        //NSLog(@"Received from host: %@", message);
        
        //Send message to the delegate
        [self.delegate didReceiveMessage:message OnPort:[NSNumber numberWithUnsignedInt:4502]];
       
        //Send POM Message to the delegate
        NSError *err = nil;
        [self.delegate didReceivePOMResponse:[POMResponse POMResponseWithXMLString:message Error:&err]];
        if (err) {
            NSLog(@"Unable to deserialize POM response: %@", message);
        }
        
        //Wait for the next message header
        [sock readDataToLength:4 withTimeout:-1 tag:1];
    }
}


- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag 
{
    
}

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err 
{
    NSLog(@"Client Disconnected: %@:%hu", [sock connectedHost], [sock connectedPort]);
    
    //Send Connection info to delegate
    [self.delegate didDisconnect];
    
    //Send error to delegate
    [self.delegate didReceiveError:[NSString stringWithFormat:@"Error connecting to server: %@", err]];
}


@end