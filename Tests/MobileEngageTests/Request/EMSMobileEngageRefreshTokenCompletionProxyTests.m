//
//  Copyright © 2019 Emarsys. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "EMSMobileEngageRefreshTokenCompletionProxy.h"
#import "EMSResponseModel.h"
#import "EMSContactTokenResponseHandler.h"
#import "EMSTimestampProvider.h"
#import "EMSUUIDProvider.h"
#import "MEEndpoints.h"

@interface EMSMobileEngageRefreshTokenCompletionProxyTests : XCTestCase

@property(nonatomic, strong) EMSRESTClient *mockRestClient;
@property(nonatomic, strong) id <EMSRESTClientCompletionProxyProtocol> mockCompletionProxy;
@property(nonatomic, strong) EMSRequestFactory *mockRequestFactory;
@property(nonatomic, strong) EMSContactTokenResponseHandler *mockResponseHandler;
@property(nonatomic, strong) NSError *mockError;
@property(nonatomic, strong) EMSMobileEngageRefreshTokenCompletionProxy *refreshCompletionProxy;

@end

@implementation EMSMobileEngageRefreshTokenCompletionProxyTests

- (void)setUp {
    _mockRestClient = OCMClassMock([EMSRESTClient class]);
    _mockCompletionProxy = OCMProtocolMock(@protocol(EMSRESTClientCompletionProxyProtocol));
    _mockRequestFactory = OCMClassMock([EMSRequestFactory class]);
    _mockResponseHandler = OCMClassMock([EMSContactTokenResponseHandler class]);
    NSError *error = [NSError new];
    _mockError = OCMPartialMock(error);

    _refreshCompletionProxy = [[EMSMobileEngageRefreshTokenCompletionProxy alloc] initWithCompletionProxy:self.mockCompletionProxy
                                                                                               restClient:self.mockRestClient
                                                                                           requestFactory:self.mockRequestFactory
                                                                                   contactResponseHandler:self.mockResponseHandler];
}

- (void)tearDown {
    [(id) self.mockError stopMocking];
    [super tearDown];
}

- (void)testInit_completionProxy_mustNotBeNil {
    @try {
        [[EMSMobileEngageRefreshTokenCompletionProxy alloc] initWithCompletionProxy:nil
                                                                         restClient:self.mockRestClient
                                                                     requestFactory:self.mockRequestFactory
                                                             contactResponseHandler:self.mockResponseHandler];
        XCTFail(@"Expected Exception when completionProxy is nil!");
    } @catch (NSException *exception) {
        XCTAssertTrue([exception.reason isEqualToString:@"Invalid parameter not satisfying: completionProxy"]);
    }
}

- (void)testInit_restClient_mustNotBeNil {
    @try {
        [[EMSMobileEngageRefreshTokenCompletionProxy alloc] initWithCompletionProxy:self.mockCompletionProxy
                                                                         restClient:nil
                                                                     requestFactory:self.mockRequestFactory
                                                             contactResponseHandler:self.mockResponseHandler];
        XCTFail(@"Expected Exception when restClient is nil!");
    } @catch (NSException *exception) {
        XCTAssertTrue([exception.reason isEqualToString:@"Invalid parameter not satisfying: restClient"]);
    }
}

- (void)testInit_requestFactory_mustNotBeNil {
    @try {
        [[EMSMobileEngageRefreshTokenCompletionProxy alloc] initWithCompletionProxy:self.mockCompletionProxy
                                                                         restClient:self.mockRestClient
                                                                     requestFactory:nil
                                                             contactResponseHandler:self.mockResponseHandler];
        XCTFail(@"Expected Exception when requestFactory is nil!");
    } @catch (NSException *exception) {
        XCTAssertTrue([exception.reason isEqualToString:@"Invalid parameter not satisfying: requestFactory"]);
    }
}

- (void)testInit_contactResponseHandler_mustNotBeNil {
    @try {
        [[EMSMobileEngageRefreshTokenCompletionProxy alloc] initWithCompletionProxy:self.mockCompletionProxy
                                                                         restClient:self.mockRestClient
                                                                     requestFactory:self.mockRequestFactory
                                                             contactResponseHandler:nil];
        XCTFail(@"Expected Exception when contactResponseHandler is nil!");
    } @catch (NSException *exception) {
        XCTAssertTrue([exception.reason isEqualToString:@"Invalid parameter not satisfying: contactResponseHandler"]);
    }
}

- (void)testCompletionBlock_shouldDelegate_toCompletionProxy_whenOnSuccess {
    EMSRequestModel *requestModel = [self generateRequestModel];
    EMSResponseModel *responseModel = [self generateResponseWithStatusCode:200];

    __block EMSRequestModel *returnedRequestModel;
    __block EMSResponseModel *returnedResponseModel;
    __block NSError *returnedError;
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"waitForCompletionBlock"];
    OCMStub([self.mockCompletionProxy completionBlock]).andReturn(^(EMSRequestModel *requestModel, EMSResponseModel *responseModel, NSError *error) {
        returnedRequestModel = requestModel;
        returnedResponseModel = responseModel;
        returnedError = error;
        [expectation fulfill];
    });

    self.refreshCompletionProxy.completionBlock(requestModel, responseModel, self.mockError);

    XCTWaiterResult waiterResult = [XCTWaiter waitForExpectations:@[expectation]
                                                          timeout:2];
    XCTAssertEqual(waiterResult, XCTWaiterResultCompleted);
    XCTAssertEqualObjects(returnedRequestModel, requestModel);
    XCTAssertEqualObjects(returnedResponseModel, responseModel);
    XCTAssertEqualObjects(returnedError, self.mockError);
}

- (void)testCompletionBlock_delegateToCompletionProxy_when_statusCode401_andNotV3 {
    EMSRequestModel *requestModel = [self generateRequestModel];
    EMSResponseModel *responseModel = [self generateResponseWithStatusCode:401];

    OCMReject([self.mockResponseHandler processResponse:[OCMArg any]]);

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"waitForCompletionBlock"];
    OCMStub([self.mockCompletionProxy completionBlock]).andReturn(^(EMSRequestModel *requestModel, EMSResponseModel *responseModel, NSError *error) {
        [expectation fulfill];
    });

    self.refreshCompletionProxy.completionBlock(requestModel, responseModel, self.mockError);

    XCTWaiterResult waiterResult = [XCTWaiter waitForExpectations:@[expectation]
                                                          timeout:2];
    XCTAssertEqual(waiterResult, XCTWaiterResultCompleted);
}

- (void)testCompletionBlock_shouldRefreshToken_when_requestIsV3 {
    EMSRequestModel *requestModel = [self generateRequestModelWithUrlString:EVENT_URL(@"testApplicationCode")];
    EMSRequestModel *requestModelForRefresh = [self generateRequestModel];
    EMSResponseModel *responseModel = [self generateResponseWithStatusCode:401];

    OCMStub([self.mockRequestFactory createRefreshTokenRequestModel]).andReturn(requestModelForRefresh);

    self.refreshCompletionProxy.completionBlock(requestModel, responseModel, self.mockError);

    OCMVerify([self.mockRequestFactory createRefreshTokenRequestModel]);
    OCMVerify([self.mockRestClient executeWithRequestModel:requestModelForRefresh
                                       coreCompletionProxy:self.refreshCompletionProxy]);
    XCTAssertEqualObjects(self.refreshCompletionProxy.originalRequestModel, requestModel);
}

- (void)testCompletionBlock_shouldHandleResponse {
    EMSRequestModel *requestModel = [self generateRequestModel];
    EMSRequestModel *mockOriginalRequestModel = [self generateRequestModel];
    EMSResponseModel *responseModel = [self generateResponseWithStatusCode:200];

    self.refreshCompletionProxy.originalRequestModel = mockOriginalRequestModel;

    self.refreshCompletionProxy.completionBlock(requestModel, responseModel, self.mockError);

    OCMVerify([self.mockResponseHandler processResponse:responseModel]);
    OCMVerify([self.mockRestClient executeWithRequestModel:mockOriginalRequestModel
                                       coreCompletionProxy:self.refreshCompletionProxy]);
    XCTAssertNil(self.refreshCompletionProxy.originalRequestModel);
}

- (void)testCompletionBlock_shouldNotHandleResponse_when_success_and_noOriginalRequestModel {
    EMSRequestModel *requestModel = [self generateRequestModel];
    EMSResponseModel *responseModel = [self generateResponseWithStatusCode:200];

    OCMReject([self.mockResponseHandler processResponse:[OCMArg any]]);

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"waitForCompletionBlock"];
    OCMStub([self.mockCompletionProxy completionBlock]).andReturn(^(EMSRequestModel *requestModel, EMSResponseModel *responseModel, NSError *error) {
        [expectation fulfill];
    });

    self.refreshCompletionProxy.completionBlock(requestModel, responseModel, self.mockError);

    XCTWaiterResult waiterResult = [XCTWaiter waitForExpectations:@[expectation]
                                                          timeout:2];
    XCTAssertEqual(waiterResult, XCTWaiterResultCompleted);
}

- (EMSRequestModel *)generateRequestModel {
    return [self generateRequestModelWithUrlString:@"https://www.emarsys.com"];
}

- (EMSRequestModel *)generateRequestModelWithUrlString:(NSString *)url {
    return [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
            [builder setUrl:url];
            [builder setMethod:HTTPMethodPOST];
            [builder setPayload:@{@"payloadKey": @"payloadValue"}];
        }
                          timestampProvider:[EMSTimestampProvider new]
                               uuidProvider:[EMSUUIDProvider new]];
}

- (EMSResponseModel *)generateResponseWithStatusCode:(int)statusCode {
    return [[EMSResponseModel alloc] initWithHttpUrlResponse:[[NSHTTPURLResponse alloc] initWithURL:[[NSURL alloc] initWithString:@"https://www.emarsys.com"]
                                                                                         statusCode:statusCode
                                                                                        HTTPVersion:nil
                                                                                       headerFields:@{@"responseHeaderKey": @"responseHeaderValue"}]
                                                        data:[@"data" dataUsingEncoding:NSUTF8StringEncoding]
                                                requestModel:[self generateRequestModel]
                                                   timestamp:[[EMSTimestampProvider new] provideTimestamp]];
}

@end
