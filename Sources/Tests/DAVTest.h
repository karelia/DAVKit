//
//  DAVTest.h
//  DAVKit
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <DAVKit/DAVKit.h>
#import "KMSTestCase.h"

@interface DAVTest : KMSTestCase < DAVRequestDelegate, DAVSessionDelegate > {
  @private
	DAVSession *_session;
    NSOperationQueue *_queue;
    NSError *_error;
	BOOL _done;
    BOOL _usingMockServer;
    id _result;
}

@property (readonly) DAVSession *session;
@property (readonly) NSOperationQueue *queue;
@property (strong, nonatomic) NSError *error;
@property (strong, nonatomic) id result;

- (BOOL)isEnabled;
- (void)notifyDone;
- (void)queueAndWaitForRequest:(DAVRequest*)request;
- (void)waitUntilWeAreDone;
- (id)requestOfClass:(Class)class withPath:(NSString *)path;
- (NSString*)fullPathForPath:(NSString*)path;
@end
