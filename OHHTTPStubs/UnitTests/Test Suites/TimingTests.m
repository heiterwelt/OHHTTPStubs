/***********************************************************************************
 *
 * Copyright (c) 2012 Olivier Halligon
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 ***********************************************************************************/


#import <XCTest/XCTest.h>
#import "OHHTTPStubs.h"

@interface TimingTests : XCTestCase
{
    NSMutableData* _data;
    NSError* _error;
    XCTestExpectation* _connectionFinishedExpectation;
    
//    NSDate* _didReceiveResponseTS;
    NSDate* _didFinishLoadingTS;
}
@end

@implementation TimingTests

-(void)setUp
{
    _data = [NSMutableData new];
    _error = nil;
//    _didReceiveResponseTS = nil;
    _didFinishLoadingTS = nil;
    [OHHTTPStubs removeAllStubs];
}
-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [_data setLength:0U];
    // NOTE: This timing info is not reliable as Cocoa always calls the connection:didReceiveResponse: delegate method just before
    // calling the first "connection:didReceiveData:", even if the [id<NSURLProtocolClient> URLProtocol:didReceiveResponse:…] method was called way before. So we are not testing this
//    _didReceiveResponseTS = [NSDate date];
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_data appendData:data];
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    _error = error; // keep strong reference
    _didFinishLoadingTS = [NSDate date];
    [_connectionFinishedExpectation fulfill];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    _didFinishLoadingTS = [NSDate date];
    [_connectionFinishedExpectation fulfill];
}


///////////////////////////////////////////////////////////////////////////////////////

static NSTimeInterval const kResponseTimeTolerence = 0.3;
static NSTimeInterval const kSecurityTimeout = 5.0;

-(void)_testWithData:(NSData*)stubData requestTime:(NSTimeInterval)requestTime responseTime:(NSTimeInterval)responseTime
{
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        return [[OHHTTPStubsResponse responseWithData:stubData
                                           statusCode:200
                                              headers:nil]
                requestTime:requestTime responseTime:responseTime];
    }];
    
    _connectionFinishedExpectation = [self expectationWithDescription:@"NSURLConnection did finish (with error or success)"];
    
    NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.iana.org/domains/example/"]];
    NSDate* startTS = [NSDate date];
    
    [NSURLConnection connectionWithRequest:req delegate:self];
    
    [self waitForExpectationsWithTimeout:requestTime+responseTime+kResponseTimeTolerence+kSecurityTimeout handler:nil];

    XCTAssertEqualObjects(_data, stubData, @"Invalid data response");

//    XCTAssertEqualWithAccuracy([_didReceiveResponseTS timeIntervalSinceDate:startTS], requestTime,
//                               kResponseTimeTolerence, @"Invalid request time");
    XCTAssertEqualWithAccuracy([_didFinishLoadingTS timeIntervalSinceDate:startTS], requestTime + responseTime,
                               kResponseTimeTolerence, @"Invalid response time");
    
    [NSThread sleepForTimeInterval:0.01]; // Time for the test to wrap it all (otherwise we may have "Test did not finish" warning)
}






-(void)test_RequestTime0_ResponseTime0
{
    NSData* testData = [NSStringFromSelector(_cmd) dataUsingEncoding:NSUTF8StringEncoding];
    [self _testWithData:testData requestTime:0 responseTime:0];
}

-(void)test_SmallDataLargeTime_CumulativeAlgorithm
{
    NSData* testData = [NSStringFromSelector(_cmd) dataUsingEncoding:NSUTF8StringEncoding];
    // 21 bytes in 23/4 of a second = 0.913042 byte per slot: we need to check that the cumulative algorithm works
    [self _testWithData:testData requestTime:0 responseTime:5.75];
}

-(void)test_RequestTime1_ResponseTime0
{
    NSData* testData = [NSStringFromSelector(_cmd) dataUsingEncoding:NSUTF8StringEncoding];
    [self _testWithData:testData requestTime:1 responseTime:0];
}

-(void)test_LongData_RequestTime1_ResponseTime5
{
    static NSUInteger const kDataLength = 1024;
    NSMutableData* testData = [NSMutableData dataWithCapacity:kDataLength];
    NSData* chunk = [[NSProcessInfo.processInfo globallyUniqueString] dataUsingEncoding:NSUTF8StringEncoding];
    while(testData.length<kDataLength)
    {
        [testData appendData:chunk];
    }
    [self _testWithData:testData requestTime:1 responseTime:5];
}

-(void)test_VeryLongData_RequestTime1_ResponseTime0
{
    static NSUInteger const kDataLength = 609792;
    NSMutableData* testData = [NSMutableData dataWithCapacity:kDataLength];
    NSData* chunk = [[NSProcessInfo.processInfo globallyUniqueString] dataUsingEncoding:NSUTF8StringEncoding];
    while(testData.length<kDataLength)
    {
        [testData appendData:chunk];
    }
    [self _testWithData:testData requestTime:1 responseTime:0];
}

@end
