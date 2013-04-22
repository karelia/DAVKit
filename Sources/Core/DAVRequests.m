//
//  DAVRequests.m
//  DAVKit
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "DAVRequests.h"

#if TARGET_OS_IPHONE
#import <MobileCoreServices/MobileCoreServices.h>
#else
#import <CoreServices/CoreServices.h>
#endif

#import "DAVListingParser.h"
#import "DAVRequest+Private.h"

@implementation DAVCopyRequest

@synthesize destinationPath = _destinationPath;
@synthesize overwrite = _overwrite;

- (NSString *)method {
	return @"COPY";
}

- (NSURLRequest *)request {
	NSParameterAssert(_destinationPath != nil);
	
	NSURL *dp = [self concatenatedURLWithPath:_destinationPath];
	
	NSMutableURLRequest *req = [self newRequestWithPath:self.path
												 method:[self method]];
	
	[req setValue:[dp absoluteString] forHTTPHeaderField:@"Destination"];
	
	if (_overwrite)
		[req setValue:@"T" forHTTPHeaderField:@"Overwrite"];
	else
		[req setValue:@"F" forHTTPHeaderField:@"Overwrite"];
	
	return [req autorelease];
}

- (void)dealloc {
	[_destinationPath release];
	[super dealloc];
}

@end


@implementation DAVDeleteRequest

- (id)initWithPath:(NSString *)aPath session:(DAVSession *)session delegate:(id<DAVRequestDelegate>)delegate
{
    if ((self = [super initWithPath:aPath session:session delegate:delegate]) != nil)
    {
        self.expectedStatuses = [NSIndexSet indexSetWithIndex:204];
    }

    return self;
}

- (NSURLRequest *)request {
	return [[self newRequestWithPath:self.path method:@"DELETE"] autorelease];
}

@end


@implementation DAVGetRequest

- (NSURLRequest *)request {
	return [[self newRequestWithPath:self.path method:@"GET"] autorelease];
}

- (id)resultForData:(NSData *)data {
	return data;
}

@end


@implementation DAVListingRequest

@synthesize depth = _depth;

- (id)initWithPath:(NSString *)aPath session:(DAVSession *)session delegate:(id <DAVRequestDelegate>)delegate;
{
	self = [super initWithPath:aPath session:session delegate:delegate];
	if (self) {
		_depth = 1;
	}
	return self;
}

- (NSURLRequest *)request {
	NSMutableURLRequest *req = [self newRequestWithPath:self.path method:@"PROPFIND"];
	
	if (_depth > 1) {
		[req setValue:@"infinity" forHTTPHeaderField:@"Depth"];
	}
	else {
		[req setValue:[NSString stringWithFormat:@"%ld", (unsigned long) _depth] forHTTPHeaderField:@"Depth"];
	}
	
	[req setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
	
	NSString *xml = @"<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n"
					@"<D:propfind xmlns:D=\"DAV:\"><D:allprop/></D:propfind>";
	
	[req setHTTPBody:[xml dataUsingEncoding:NSUTF8StringEncoding]];
	
	return [req autorelease];
}

- (id)resultForData:(NSData *)data {
	DAVListingParser *p = [[DAVListingParser alloc] initWithData:data];
	
	NSError *error = nil;
	NSArray *items = [p parse:&error];
	
	if (error) {
		#ifdef DEBUG
			NSLog(@"XML Parse error: %@", error);
		#endif
	}
	
	[p release];
	
	return items;
}

@end


@implementation DAVMakeCollectionRequest

- (id)initWithPath:(NSString *)aPath session:(DAVSession *)session delegate:(id<DAVRequestDelegate>)delegate
{
    if ((self = [super initWithPath:aPath session:session delegate:delegate]) != nil)
    {
        self.expectedStatuses = [NSIndexSet indexSetWithIndex:204];
    }

    return self;
}

- (NSURLRequest *)request {
	return [[self newRequestWithPath:self.path method:@"MKCOL"] autorelease];
}

@end


@implementation DAVMoveRequest

- (NSString *)method {
	return @"MOVE";
}

@end

@implementation DAVPutRequest

+ (NSString*)MIMETypeForExtension:(NSString*)extension
{
    CFStringRef type = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)extension, NULL);
    NSString* mimeType = nil;
    if (type)
    {
        mimeType = (NSString*)UTTypeCopyPreferredTagWithClass(type, kUTTagClassMIMEType);
        CFRelease(type);
        [mimeType autorelease];
        CFMakeCollectable(mimeType);
    }
    if (!mimeType)
    {
        mimeType = @"application/octet-stream";
    }

    return mimeType;
}


- (id)initWithPath:(NSString*)path originalRequest:(NSURLRequest*)originalRequest session:(DAVSession *)session delegate:(id<DAVRequestDelegate>)delegate
{
    if ((self = [super initWithPath:path session:session delegate:delegate]))
    {

        _request = [originalRequest mutableCopy];

        if(![_request valueForHTTPHeaderField:@"Content-Length"])
        {
            NSData* data = [_request HTTPBody];
            NSAssert(data != nil, @"should have data if no length set");
            NSUInteger length = [data length];
            [_request setValue:[NSString stringWithFormat:@"%@", @(length)] forHTTPHeaderField:@"Content-Length"];
        }

        NSString* MIMEType = [DAVPutRequest MIMETypeForExtension:[path pathExtension]];
        [_request setValue:MIMEType forHTTPHeaderField:@"Content-Type"];
        [_request setValue:@"100-Continue" forHTTPHeaderField:@"Expect"];

        [_request setHTTPMethod:@"PUT"];
        [_request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        [_request setURL:[self concatenatedURLWithPath:path]];

        NSMutableIndexSet* indexes = [[NSMutableIndexSet alloc] init];
        [indexes addIndex:201]; // The resource was created successfully
        [indexes addIndex:202]; // The resource will be created or deleted, but this has not happened yet
        [indexes addIndex:204]; // The server has fulfilled the request but does not need to return an entity body, and might return updated metadata.
        self.expectedStatuses = indexes;
        [indexes release];
    }

    return self;
}

@dynamic delegate;

- (NSURLRequest *)request {
    return _request;
}

- (NSUInteger)expectedLength
{
    return [[_request valueForHTTPHeaderField:@"Content-Length"] integerValue];
}

- (void)dealloc
{
	[_request release];

	[super dealloc];
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    if ([[self delegate] respondsToSelector:@selector(webDAVRequest:didSendDataOfLength:totalBytesWritten:totalBytesExpectedToWrite:)])
    {
        [[self delegate] webDAVRequest:self didSendDataOfLength:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
    }
}

- (NSInputStream *)connection:(NSURLConnection *)connection needNewBodyStream:(NSURLRequest *)request
{
    NSInputStream* result = nil;

    if ([[self delegate] respondsToSelector:@selector(webDAVRequest:needNewBodyStream:)])
    {
        result = [[self delegate] webDAVRequest:self needNewBodyStream:request];
    }

    return result;
}

@end
