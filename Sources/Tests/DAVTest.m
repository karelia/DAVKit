//
//  DAVTest.m
//  DAVKit
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "DAVTest.h"
#import "KMSServer.h"

@interface DAVTest()

@end

@implementation DAVTest

@synthesize session = _session;
@synthesize url = _url;
@synthesize queue = _queue;
@synthesize error = _error;
@synthesize result = _result;

- (void)setUp {
    
    // Use MockServer out of the box
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"DAVTestURL" : @"MockServer" }];
    
	_done = NO;

    _queue = [[NSOperationQueue alloc] init];
    _queue.suspended = YES;
    _queue.name = @"DAVTest";
    _queue.maxConcurrentOperationCount = 1;

    // We read the server to use from a defaults setting.
    // If nothing is set, we assert with an error (so that people know they need to set something).
    // If the server is set to "Off" though, we suppress the tests. This lets you at least verify that the tests build.
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* setting = [defaults stringForKey:@"DAVTestURL"];
    if (![setting isEqualToString:@"Off"])
    {
        BOOL ok;
        if ([setting isEqualToString:@"MockServer"])
        {
            _usingMockServer = YES;
            ok = [self setupServerWithResponseFileNamed:@"webdav"];
            [KMSServer setLoggingLevel:KMSLoggingDetail];
        }
        else
        {
            NSURL* url = [NSURL URLWithString:setting];
            self.user = url.user;
            self.password = url.password;
            self.url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@%@", url.scheme, url.host, url.path]];

            ok = self.url != nil;
            XCTAssertNotNil(self.url, @"You need to set a test server address. Use the defaults command on the command line: defaults write otest DAVTestURL \"server-url-here\".\n\nNote that the iOS tests read from the otest.plist in ~/Library/Application Support/iPhone Simulator/Library/Preferences, so you'll need to edit that one manually.");
        }

        if (ok)
        {
            NSLog(@"Testing %@ as %@ %@", self.url, self.user, self.password);

            _session = [[DAVSession alloc] initWithRootURL:self.url delegate:self];
            XCTAssertNotNil(_session, @"Couldn't create DAV session");
        }
    }
}

- (BOOL)isEnabled
{
    BOOL enabled = self.session != nil;
    if (!enabled)
    {
        NSLog(@"WARNING: Test %@ is disabled.", self.name);
    }

    return enabled;
}

- (void)notifyDone {
    if (_usingMockServer)
    {
        [self pause];
    }
    else
    {
        _done = YES;
    }
}

- (void)waitUntilWeAreDone {
    self.queue.suspended = NO;
    if (_usingMockServer)
    {
        [self runUntilPaused];
    }
    else
    {
        while (!_done) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
    }
}

#define USE_FULL_PATH 1

- (NSString*)fullPathForPath:(NSString*)path
{
    NSString* result;


#if USE_FULL_PATH

    if (_usingMockServer)
    {
        result = [self URLForPath:path].path;
    }
    else
    {
        result = [[self.url path] stringByAppendingPathComponent:path];
    }

#else
        result = path;
#endif

    return result;
}

- (id)requestOfClass:(Class)class withPath:(NSString *)path
{
    NSString* fullPath = [self fullPathForPath:path];
    id request = [[class alloc] initWithPath:fullPath session:self.session delegate:self];

    return [request autorelease];
}

- (void)queueAndWaitForRequest:(DAVRequest*)request
{
	XCTAssertNotNil(request, @"Couldn't create the request");

    _done = NO;
    self.error = nil;
    self.result = nil;

    [self.queue addOperation:request];
    [self waitUntilWeAreDone];

    
}

- (void)request:(DAVRequest *)aRequest didSucceedWithResult:(id)result
{
    // store the result - the test case will check it
    _result = [result retain];
    [self notifyDone];
}

- (void)request:(DAVRequest *)aRequest didFailWithError:(NSError *)error {
    // store the error - the test case will check it
    _error = [error retain];
	[self notifyDone];
}

- (void)webDAVSession:(DAVSession *)session appendStringToTranscript:(NSString *)string sent:(BOOL)sent
{
    NSLog(@"%@ %@", sent ? @"-->" : @"<--", string);
}

- (void)tearDown {
    [_queue waitUntilAllOperationsAreFinished];
    [_queue release]; _queue = nil;
	[_session release]; _session = nil;
    self.result = nil;
    self.error = nil;
}

- (void)webDAVSession:(DAVSession *)session didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if ([challenge previousFailureCount] > 0)
    {
        [[challenge sender] cancelAuthenticationChallenge:challenge];
    }
    else
    {
        NSURLCredential *credentials = [NSURLCredential credentialWithUser:self.user
                                                                  password:self.password
                                                               persistence:NSURLCredentialPersistenceNone];
        XCTAssertNotNil(credentials, @"Couldn't create credentials");
        XCTAssertTrue([self.user isEqualToString:credentials.user], @"Couldn't set username");
        XCTAssertTrue([self.password isEqualToString:credentials.password], @"Couldn't set password");
        
        [[challenge sender] useCredential:credentials forAuthenticationChallenge:challenge];
    }
}

@end
