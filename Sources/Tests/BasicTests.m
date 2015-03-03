//
//  BasicTests.m
//  DAVKit
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "BasicTests.h"
#import "KMSServer.h"

@implementation BasicTests

#pragma mark - Support


- (NSData*)noDirectoryListingData
{
    NSString* xml = @"<D:multistatus xmlns:D=\"DAV:\"/>";
    NSData* data = [xml dataUsingEncoding:NSUTF8StringEncoding];
    
    return data;
}

- (NSData*)emptyDirectoryListingData
{
    NSString* path = [self fullPathForPath:@"davkittest"];
    NSString* xml = [NSString stringWithFormat:
        @"<D:response xmlns:lp1=\"DAV:\">"
        "<D:href>%@</D:href>"
        "<D:propstat>"
        "<D:prop>"
        "<lp1:resourcetype><D:collection/></lp1:resourcetype>"
        "</D:prop>"
        "<D:status>HTTP/1.1 200 OK</D:status>"
        "</D:propstat>"
        "</D:response>", path];

    NSData* data = [xml dataUsingEncoding:NSUTF8StringEncoding];

    return data;
}

- (NSData*)directoryListingData
{
    NSString* rootPath = [self fullPathForPath:@"davkittest"];
    NSString* path1 = [self fullPathForPath:@"davkittest/filetest22.txt"];
    NSString* path2 = [self fullPathForPath:@"davkittest/filetest23.txt"];
    NSString* path3 = [self fullPathForPath:@"davkittest/filetest24.txt"];
    NSString* xml = [NSString stringWithFormat:
                     @"<D:multistatus xmlns:D=\"DAV:\" xmlns:ns0=\"DAV:\">"
                     
                     "<D:response xmlns:lp1=\"DAV:\">"
                     "<D:href>%@</D:href>"
                     "<D:propstat>"
                     "<D:prop>"
                     "<lp1:resourcetype><D:collection/></lp1:resourcetype>"
                     "</D:prop>"
                     "<D:status>HTTP/1.1 200 OK</D:status>"
                     "</D:propstat>"
                     "</D:response>"

                     "<D:response xmlns:lp1=\"DAV:\">"
                     "<D:href>%@</D:href>"
                     "<D:propstat>"
                     "<D:prop>"
                     "<lp1:resourcetype/>"
                     "</D:prop>"
                     "<D:status>HTTP/1.1 200 OK</D:status>"
                     "</D:propstat>"
                     "</D:response>"

                     "<D:response xmlns:lp1=\"DAV:\">"
                     "<D:href>%@</D:href>"
                     "<D:propstat>"
                     "<D:prop>"
                     "<lp1:resourcetype/>"
                     "</D:prop>"
                     "<D:status>HTTP/1.1 200 OK</D:status>"
                     "</D:propstat>"
                     "</D:response>"

                     "<D:response xmlns:lp1=\"DAV:\">"
                     "<D:href>%@</D:href>"
                     "<D:propstat>"
                     "<D:prop>"
                     "<lp1:resourcetype/>"
                     "</D:prop>"
                     "<D:status>HTTP/1.1 200 OK</D:status>"
                     "</D:propstat>"
                     "</D:response>"

                     "</D:multistatus>\r\n", rootPath, path1, path2, path3];
    
    NSData* data = [xml dataUsingEncoding:NSUTF8StringEncoding];
    
    return data;
}

- (void)makeTestDirectory
{
    DAVMakeCollectionRequest *createRequest = [self requestOfClass:[DAVMakeCollectionRequest class] withPath:@"davkittest"];
    [self queueAndWaitForRequest:createRequest];
}

- (void)removeTestDirectory
{
    DAVMakeCollectionRequest *deleteRequest = [self requestOfClass:[DAVDeleteRequest class] withPath:@"davkittest"];
    [self queueAndWaitForRequest:deleteRequest];
}

- (void)makeTestFile
{
    [self makeTestFileWithPath:@"davkittest/filetest22.txt"];
}

- (NSString*)testText
{
    return @"blah";
}

- (NSData*)testData
{
    return [self.testText dataUsingEncoding:NSUTF8StringEncoding];
}
- (void)makeTestFileWithPath:(NSString*)path
{
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:self.url];
    request.HTTPBody = [self testData];
    NSString* fullPath = [self fullPathForPath:path];
	DAVPutRequest *req = [[DAVPutRequest alloc] initWithPath:fullPath originalRequest:request session:self.session delegate:self];
    [self queueAndWaitForRequest:req];
	[req release];
}

#pragma mark - Tests

- (void)testKMCOL {
    if ([self isEnabled])
    {
        // delete the directory if it exists - we don't really care if this fails - it's just to attempt to clean up
        [self removeTestDirectory];

        // try to make the directory
        [self makeTestDirectory];

        // did we get an error?
        XCTAssertNil(self.error, @"unexpected error for MKCOL %@", self.error);
        XCTAssertNil(self.result, @"unexpected result for MKCOL %@", self.result);

        // try to make the directory again - we should get back a 405, which we ignore
        [self useResponseSet:@"make fails"];
        [self makeTestDirectory];

        XCTAssertTrue(self.error.code == 405, @"unexpected error for MKCOL %@", self.error);
        XCTAssertNil(self.result, @"unexpected result for MKCOL %@", self.result);

        [self removeTestDirectory];
    }
}

- (void)testPUT {
    if ([self isEnabled])
    {
        // make test dir - ignore errors, as they aren't part of this test
        [self makeTestDirectory];

        [self makeTestFile];

        XCTAssertNil(self.error, @"Unexpected error for PUT %@", self.error);
        XCTAssertNil(self.result, @"Unexpected result for PUT %@", self.result);

        [self removeTestDirectory];
    }
}

- (void)testGET {
    if ([self isEnabled])
    {
        [self makeTestDirectory];
        [self makeTestFile];

        DAVGetRequest *req = [self requestOfClass:[DAVGetRequest class] withPath:@"davkittest/filetest22.txt"];
        self.server.data = [self testData];
        [self queueAndWaitForRequest:req];

        XCTAssertNil(self.error, @"Unexpected error for GET %@", self.error);
        XCTAssertTrue([self.result isKindOfClass:[NSData class]], @"Expecting a NSData object for GET requests");
        XCTAssertTrue([self.result length] == [self.testText length], @"Invalid length (string should be %@)", self.testText);

        [self removeTestDirectory];
    }
}

- (void)testCOPY {
    if ([self isEnabled])
    {
        [self makeTestDirectory];
        [self makeTestFile];

        DAVCopyRequest *req = [self requestOfClass:[DAVCopyRequest class] withPath:@"davkittest/filetest22.txt"];
        req.destinationPath = @"davkittest/filetest23.txt";
        req.overwrite = YES;
        [self queueAndWaitForRequest:req];

        XCTAssertNil(self.error, @"Unexpected error for COPY %@", self.error);
        XCTAssertNil(self.result, @"Unexpected result for COPY %@", self.result);

        [self removeTestDirectory];
    }
}

- (void)testMOVE {
    if ([self isEnabled])
    {
        [self makeTestDirectory];
        [self makeTestFile];

        DAVMoveRequest *req = [self requestOfClass:[DAVMoveRequest class] withPath:@"davkittest/filetest22.txt"];
        req.destinationPath = [self fullPathForPath:@"davkittest/filetest24.txt"];
        [self queueAndWaitForRequest:req];

        XCTAssertNil(self.error, @"Unexpected error for MOVE %@", self.error);
        XCTAssertNil(self.result, @"Unexpected result for MOVE %@", self.result);

        [self removeTestDirectory];
    }
}

- (BOOL)path:(NSString*)path1 matchesPath:(NSString*)path2
{
    NSUInteger lastChar1 = [path1 length] - 1;
    if ([path1 characterAtIndex:lastChar1] == '/')
        path1 = [path1 substringToIndex:lastChar1];

    NSUInteger lastChar2 = [path2 length] - 1;
    if ([path2 characterAtIndex:lastChar2] == '/')
        path2 = [path2 substringToIndex:lastChar2];

    return [path1 isEqualToString:path2];
}

- (void)testPROPFIND {
    if ([self isEnabled])
    {
        [self removeTestDirectory];
        [self makeTestDirectory];

        DAVListingRequest *req = [self requestOfClass:[DAVListingRequest class] withPath:@"davkittest"];
        self.server.data = [self emptyDirectoryListingData];
        [self queueAndWaitForRequest:req];

        XCTAssertNil(self.error, @"Unexpected error for PROPFIND %@", self.error);
        XCTAssertTrue([self.result isKindOfClass:[NSArray class]], @"Expecting a NSArray object for PROPFIND requests");
        XCTAssertEqual([self.result count], 1UL, @"Unexpected result count %lu %@", [self.result count], self.result);

        NSString* path1 = @"davkittest/filetest22.txt";
        NSString* path2 = @"davkittest/filetest23.txt";
        NSString* path3 = @"davkittest/filetest24.txt";
        [self makeTestFileWithPath:path1];
        [self makeTestFileWithPath:path2];
        [self makeTestFileWithPath:path3];

        DAVListingRequest *req2 = [self requestOfClass:[DAVListingRequest class] withPath:@"davkittest"];
        req.depth = 1;
        self.server.data = [self directoryListingData];
        [self queueAndWaitForRequest:req2];

        XCTAssertNil(self.error, @"Unexpected error for PROPFIND %@", self.error);
        XCTAssertTrue([self.result isKindOfClass:[NSArray class]], @"Expecting a NSArray object for PROPFIND requests");
        XCTAssertEqual([self.result count], 4UL, @"Unexpected result count %lu %@", [self.result count], self.result);

        NSUInteger n = 0;
        NSArray* names = @[@"davkittest/", path1, path2, path3];
        for (DAVResponseItem* item in self.result)
        {
            NSString* expected = [self fullPathForPath:names[n++]];
            XCTAssertTrue([self path:item.href matchesPath:expected], @"expected %@ got %@", expected, item.href);
        }

        [self removeTestDirectory];
    }
}

- (void)testDELETE {
    if ([self isEnabled])
    {
        [self makeTestDirectory];
        
        [self removeTestDirectory];
        XCTAssertNil(self.error, @"Unexpected error for DELETE %@", self.error);
        XCTAssertNil(self.result, @"Unexpected result for DELETE %@", self.result);
    }
}

@end
