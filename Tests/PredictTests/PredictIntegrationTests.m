//
//  Copyright © 2018. Emarsys. All rights reserved.
//

#import "Kiwi.h"
#import "EMSDependencyContainer.h"
#import "EMSDependencyInjection.h"
#import "Emarsys.h"
#import "EMSResponseModel.h"
#import "EmarsysTestUtils.h"
#import "EMSCartItem.h"
#import "EMSWaiter.h"
#import "MEExperimental.h"
#import "EMSInnerFeature.h"

#define DB_PATH [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"MEDB.db"]
#define REPOSITORY_DB_PATH [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"EMSSQLiteQueueDB.db"]

@interface PredictIntegrationDependencyContainer : EMSDependencyContainer

@property(nonatomic, strong) NSMutableArray *expectations;
@property(nonatomic, strong) EMSResponseModel *lastResponseModel;

- (instancetype)initWithConfig:(EMSConfig *)config
                  expectations:(NSArray<XCTestExpectation *> *)expectations;

- (instancetype)initWithConfig:(EMSConfig *)config
                   expectation:(XCTestExpectation *)expectation;
@end

@implementation PredictIntegrationDependencyContainer

- (instancetype)initWithConfig:(EMSConfig *)config
                  expectations:(NSArray<XCTestExpectation *> *)expectations {
    if (self = [super initWithConfig:config]) {
        _expectations = expectations.mutableCopy;
    }
    return self;
}

- (instancetype)initWithConfig:(EMSConfig *)config
                   expectation:(XCTestExpectation *)expectation {
    return [[PredictIntegrationDependencyContainer alloc] initWithConfig:config
                                                            expectations:@[expectation]];
}

- (void (^)(NSString *, EMSResponseModel *))createSuccessBlock {
    return ^(NSString *requestId, EMSResponseModel *response) {
        [super createSuccessBlock](requestId, response);
        _lastResponseModel = response;
        XCTestExpectation *expectation = [self popExpectation];
        [expectation fulfill];
    };
}

- (XCTestExpectation *)popExpectation {
    XCTestExpectation *expectation = self.expectations.firstObject;
    [self.expectations removeObject:expectation];
    return expectation;
}

@end

SPEC_BEGIN(PredictIntegrationTests)

        __block NSArray<XCTestExpectation *> *expectations;
        __block PredictIntegrationDependencyContainer *dependencyContainer;

        beforeEach(^{
            [EmarsysTestUtils tearDownEmarsys];
            [[NSFileManager defaultManager] removeItemAtPath:DB_PATH
                                                       error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:REPOSITORY_DB_PATH
                                                       error:nil];

            NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.emarsys.predict"];
            [userDefaults removeObjectForKey:@"customerId"];
            [userDefaults removeObjectForKey:@"visitorId"];
            [userDefaults synchronize];


            EMSConfig *config = [EMSConfig makeWithBuilder:^(EMSConfigBuilder *builder) {
                [builder setContactFieldId:@3];
                [builder setMerchantId:@"1428C8EE286EC34B"];
            }];
            [MEExperimental enableFeature:EMSInnerFeature.predict];

            expectations = @[
                [[XCTestExpectation alloc] initWithDescription:@"waitForExpectation"]];
            dependencyContainer = [[PredictIntegrationDependencyContainer alloc] initWithConfig:config
                                                                                   expectations:expectations];
            [EMSDependencyInjection setupWithDependencyContainer:dependencyContainer];
            [Emarsys setupWithConfig:config];
        });

        afterEach(^{
            [EmarsysTestUtils tearDownEmarsys];
        });

        describe(@"trackCartWithCartItems:", ^{

            it(@"should send request with cartItems", ^{
                NSString *expectedQueryParams = @"ca=i%3A2508%2Cp%3A200.0%2Cq%3A100.0%7Ci%3A2073%2Cp%3A201.0%2Cq%3A101.0";

                [Emarsys.predict trackCartWithCartItems:@[
                    [EMSCartItem itemWithItemId:@"2508" price:200.0 quantity:100.0],
                    [EMSCartItem itemWithItemId:@"2073" price:201.0 quantity:101.0]
                ]];

                [EMSWaiter waitForExpectations:expectations
                                       timeout:10];

                [[theValue([dependencyContainer.lastResponseModel statusCode]) should] beBetween:theValue(200)
                                                                                             and:theValue(299)];
                [[dependencyContainer.lastResponseModel.requestModel.url.absoluteString should] containString:expectedQueryParams];
            });
        });

        describe(@"trackPurchaseWithOrderId:items:", ^{

            it(@"should send request with orderId and items", ^{
                NSString *expectedOrderIdQueryParams = @"oi=orderId";
                NSString *expectedItemsQueryParams = @"co=i%3A2508%2Cp%3A200.0%2Cq%3A100.0%7Ci%3A2073%2Cp%3A201.0%2Cq%3A101.0";

                [Emarsys.predict trackPurchaseWithOrderId:@"orderId"
                                                    items:@[
                                                        [EMSCartItem itemWithItemId:@"2508"
                                                                              price:200.0
                                                                           quantity:100.0],
                                                        [EMSCartItem itemWithItemId:@"2073"
                                                                              price:201.0
                                                                           quantity:101.0]
                                                    ]];

                [EMSWaiter waitForExpectations:expectations
                                       timeout:10];

                [[theValue([dependencyContainer.lastResponseModel statusCode]) should] equal:theValue(200)];
                [[dependencyContainer.lastResponseModel.requestModel.url.absoluteString should] containString:expectedOrderIdQueryParams];
                [[dependencyContainer.lastResponseModel.requestModel.url.absoluteString should] containString:expectedItemsQueryParams];
            });
        });

        describe(@"trackCategoryViewWithCategoryPath:", ^{

            it(@"should send request with category path", ^{
                NSString *expectedQueryParams = @"vc=DESIGNS%3ELiving%20Room";

                [Emarsys.predict trackCategoryViewWithCategoryPath:@"DESIGNS>Living Room"];

                [EMSWaiter waitForExpectations:expectations
                                       timeout:10];

                [[theValue([dependencyContainer.lastResponseModel statusCode]) should] equal:theValue(200)];
                [[dependencyContainer.lastResponseModel.requestModel.url.absoluteString should] containString:expectedQueryParams];
            });
        });

        describe(@"trackItemViewWithItemId:", ^{

            it(@"should send request with item id", ^{
                NSString *expectedQueryParams = @"v=i%3A2508";

                [Emarsys.predict trackItemViewWithItemId:@"2508"];

                [EMSWaiter waitForExpectations:expectations
                                       timeout:10];

                [[theValue([dependencyContainer.lastResponseModel statusCode]) should] equal:theValue(200)];
                [[dependencyContainer.lastResponseModel.requestModel.url.absoluteString should] containString:expectedQueryParams];
            });
        });

        describe(@"trackSearchWithSearchTerm:", ^{

            it(@"should send request with search term", ^{
                NSString *expectedQueryParams = @"q=searchTerm";

                [Emarsys.predict trackSearchWithSearchTerm:@"searchTerm"];

                [EMSWaiter waitForExpectations:expectations
                                       timeout:10];

                [[theValue([dependencyContainer.lastResponseModel statusCode]) should] equal:theValue(200)];
                [[dependencyContainer.lastResponseModel.requestModel.url.absoluteString should] containString:expectedQueryParams];
            });
        });

        describe(@"visitorId", ^{

            it(@"should simulate login flow", ^{
                XCTestExpectation *expectationSearchTerm1 = [[XCTestExpectation alloc] initWithDescription:@"waitForTrackSearchWithSearchTerm1"];
                XCTestExpectation *expectationSearchTerm2 = [[XCTestExpectation alloc] initWithDescription:@"waitForTrackSearchWithSearchTerm2"];
                [dependencyContainer setExpectations:[@[expectationSearchTerm1, expectationSearchTerm2] mutableCopy]];

                NSString *expectedQueryParams = @"q=searchTerm";
                NSString *visitorId;
                NSString *visitorId2;

                [Emarsys.predict trackSearchWithSearchTerm:@"searchTerm"];
                [EMSWaiter waitForExpectations:@[expectationSearchTerm1]
                                       timeout:10];

                [[theValue([dependencyContainer.lastResponseModel statusCode]) should] equal:theValue(200)];
                [[dependencyContainer.lastResponseModel.requestModel.url.absoluteString should] containString:expectedQueryParams];
                visitorId = dependencyContainer.lastResponseModel.cookies[@"cdv"].value;
                [[visitorId shouldNot] beNil];

                [Emarsys clearContact];

                [Emarsys setContactWithContactFieldValue:@"test@test.com"];

                [Emarsys.predict trackSearchWithSearchTerm:@"searchTerm"];
                [EMSWaiter waitForExpectations:@[expectationSearchTerm2]
                                       timeout:10];

                [[theValue([dependencyContainer.lastResponseModel statusCode]) should] equal:theValue(200)];
                [[dependencyContainer.lastResponseModel.requestModel.url.absoluteString should] containString:expectedQueryParams];
                visitorId2 = dependencyContainer.lastResponseModel.cookies[@"cdv"].value;
                [[visitorId2 shouldNot] beNil];
            });
        });

SPEC_END