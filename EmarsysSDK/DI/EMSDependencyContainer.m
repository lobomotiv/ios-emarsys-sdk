//
// Copyright (c) 2018 Emarsys. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "EMSDependencyContainer.h"
#import "MERequestContext.h"
#import "MEInApp.h"
#import "EMSShardRepository.h"
#import "EMSSQLiteHelper.h"
#import "MERequestModelRepositoryFactory.h"
#import "EMSSqliteSchemaHandler.h"
#import "PredictInternal.h"
#import "PRERequestContext.h"
#import "EMSUUIDProvider.h"
#import "EMSSchemaContract.h"
#import "EMSPredictMapper.h"
#import "EMSAbstractResponseHandler.h"
#import "EMSVisitorIdResponseHandler.h"
#import "MEInbox.h"
#import "MENotificationCenterManager.h"
#import "EMSDefaultWorker.h"
#import "MEIAMResponseHandler.h"
#import "MEIAMCleanupResponseHandler.h"
#import "MEDefaultHeaders.h"
#import "AppStartBlockProvider.h"
#import "EMSWindowProvider.h"
#import "EMSMainWindowProvider.h"
#import "EMSViewControllerProvider.h"
#import "MEUserNotificationDelegate.h"
#import "EMSLogger.h"
#import "EMSBatchingShardTrigger.h"
#import "EMSListChunker.h"
#import "EMSCountPredicate.h"
#import "EMSFilterByTypeSpecification.h"
#import "EMSLogMapper.h"
#import "EMSDeviceInfo.h"
#import "EmarsysSDKVersion.h"
#import "EMSOperationQueue.h"
#import "EMSRESTClientCompletionProxyFactory.h"
#import "EMSClientStateResponseHandler.h"
#import "EMSRequestFactory.h"
#import "EMSV3Mapper.h"
#import "EMSPushV3Internal.h"
#import "EMSContactTokenResponseHandler.h"
#import "EMSInAppInternal.h"
#import "EMSCompletionProxyFactory.h"
#import "EMSRefreshTokenResponseHandler.h"
#import "EMSContactTokenMapper.h"
#import "EMSDeviceInfoV3ClientInternal.h"
#import "EMSDeepLinkInternal.h"
#import "EMSNotificationCache.h"
#import "EMSMobileEngageV3Internal.h"
#import "EMSCompletionMiddleware.h"
#import "EMSRequestManager.h"
#import "MEExperimental.h"
#import "EMSInnerFeature.h"
#import "EMSLoggingPredictInternal.h"
#import "EMSLoggingPushInternal.h"
#import "EMSLoggingInbox.h"
#import "EMSLoggingUserNotificationDelegate.h"
#import "EMSLoggingInApp.h"
#import "EMSLoggingMobileEngageInternal.h"
#import "EMSLoggingDeepLinkInternal.h"

#define DB_PATH [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"MEDB.db"]

@interface EMSDependencyContainer ()

@property(nonatomic, strong) MERequestContext *requestContext;
@property(nonatomic, strong) PRERequestContext *predictRequestContext;
@property(nonatomic, strong) EMSRequestFactory *requestFactory;
@property(nonatomic, strong) EMSRESTClient *restClient;
@property(nonatomic, strong) MENotificationCenterManager *notificationCenterManager;
@property(nonatomic, strong) EMSSQLiteHelper *dbHelper;
@property(nonatomic, strong) id <EMSMobileEngageProtocol> mobileEngage;
@property(nonatomic, strong) id <EMSDeepLinkProtocol> deepLink;
@property(nonatomic, strong) id <EMSPushNotificationProtocol> push;
@property(nonatomic, strong) id <EMSInboxProtocol> inbox;
@property(nonatomic, strong) id <EMSInAppProtocol, MEIAMProtocol> iam;
@property(nonatomic, strong) id <EMSPredictProtocol, EMSPredictInternalProtocol> predict;
@property(nonatomic, strong) id <EMSRequestModelRepositoryProtocol> requestRepository;
@property(nonatomic, strong) EMSNotificationCache *notificationCache;
@property(nonatomic, strong) NSArray<EMSAbstractResponseHandler *> *responseHandlers;
@property(nonatomic, strong) EMSRequestManager *requestManager;
@property(nonatomic, strong) NSOperationQueue *operationQueue;
@property(nonatomic, strong) AppStartBlockProvider *appStartBlockProvider;
@property(nonatomic, strong) id <EMSUserNotificationCenterDelegate> notificationCenterDelegate;
@property(nonatomic, strong) EMSLogger *logger;
@property(nonatomic, strong) id <EMSDBTriggerProtocol> predictTrigger;
@property(nonatomic, strong) id <EMSDBTriggerProtocol> loggerTrigger;
@property(nonatomic, strong) id <EMSDeviceInfoClientProtocol> deviceInfoClient;

- (void)initializeDependenciesWithConfig:(EMSConfig *)config;

@end

@implementation EMSDependencyContainer

- (instancetype)initWithConfig:(EMSConfig *)config {
    if (self = [super init]) {
        [self initializeDependenciesWithConfig:config];
    }
    return self;
}

- (void)initializeDependenciesWithConfig:(EMSConfig *)config {
    EMSTimestampProvider *timestampProvider = [EMSTimestampProvider new];
    EMSUUIDProvider *uuidProvider = [EMSUUIDProvider new];
    EMSDeviceInfo *deviceInfo = [[EMSDeviceInfo alloc] initWithSDKVersion:EMARSYS_SDK_VERSION
                                                       notificationCenter:[UNUserNotificationCenter currentNotificationCenter]];

    _requestContext = [[MERequestContext alloc] initWithConfig:config
                                                  uuidProvider:uuidProvider
                                             timestampProvider:timestampProvider
                                                    deviceInfo:deviceInfo];
    _predictRequestContext = [[PRERequestContext alloc] initWithTimestampProvider:timestampProvider
                                                                     uuidProvider:uuidProvider
                                                                       merchantId:config.merchantId
                                                                       deviceInfo:deviceInfo];

    _requestFactory = [[EMSRequestFactory alloc] initWithRequestContext:self.requestContext];
    _notificationCenterManager = [MENotificationCenterManager new];
    _dbHelper = [[EMSSQLiteHelper alloc] initWithDatabasePath:DB_PATH
                                               schemaDelegate:[EMSSqliteSchemaHandler new]];
    MEDisplayedIAMRepository *displayedIAMRepository = [[MEDisplayedIAMRepository alloc] initWithDbHelper:self.dbHelper];
    MEButtonClickRepository *buttonClickRepository = [[MEButtonClickRepository alloc] initWithDbHelper:self.dbHelper];

    if ([MEExperimental isFeatureEnabled:EMSInnerFeature.mobileEngage]) {
        _iam = [[MEInApp alloc] initWithWindowProvider:[[EMSWindowProvider alloc] initWithViewControllerProvider:[EMSViewControllerProvider new]]
                                    mainWindowProvider:[[EMSMainWindowProvider alloc] initWithApplication:[UIApplication sharedApplication]]
                                     timestampProvider:timestampProvider
                                displayedIamRepository:displayedIAMRepository
                                 buttonClickRepository:buttonClickRepository];
    } else {
        _iam = [EMSLoggingInApp new];
    }
    [_dbHelper open];

    EMSShardRepository *shardRepository = [[EMSShardRepository alloc] initWithDbHelper:self.dbHelper];
    MERequestModelRepositoryFactory *requestRepositoryFactory = [[MERequestModelRepositoryFactory alloc] initWithInApp:self.iam
                                                                                                        requestContext:self.requestContext
                                                                                                              dbHelper:self.dbHelper
                                                                                                 buttonClickRepository:buttonClickRepository
                                                                                                displayedIAMRepository:displayedIAMRepository];

    _requestRepository = [requestRepositoryFactory createWithBatchCustomEventProcessing:YES];

    _operationQueue = [EMSOperationQueue new];
    _operationQueue.maxConcurrentOperationCount = 1;
    _operationQueue.qualityOfService = NSQualityOfServiceUtility;
    _operationQueue.name = [NSString stringWithFormat:@"core_sdk_queue_%@", [uuidProvider provideUUIDString]];

    _logger = [[EMSLogger alloc] initWithShardRepository:shardRepository
                                          opertaionQueue:self.operationQueue
                                       timestampProvider:timestampProvider
                                            uuidProvider:uuidProvider];

    EMSCompletionMiddleware *middleware = [self createMiddleware];

    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    [sessionConfiguration setTimeoutIntervalForRequest:30.0];
    [sessionConfiguration setHTTPCookieStorage:nil];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration
                                                          delegate:nil
                                                     delegateQueue:self.operationQueue];

    EMSContactTokenResponseHandler *contactTokenResponseHandler = [[EMSContactTokenResponseHandler alloc] initWithRequestContext:self.requestContext];
    NSMutableArray<EMSAbstractResponseHandler *> *responseHandlers = [NSMutableArray array];
    [self.dbHelper open];
    [responseHandlers addObjectsFromArray:@[
        [[MEIAMResponseHandler alloc] initWithInApp:self.iam],
        [[MEIAMCleanupResponseHandler alloc] initWithButtonClickRepository:buttonClickRepository
                                                      displayIamRepository:displayedIAMRepository]]
    ];
    [responseHandlers addObject:[[EMSVisitorIdResponseHandler alloc] initWithRequestContext:self.predictRequestContext]];
    [responseHandlers addObject:[[EMSClientStateResponseHandler alloc] initWithRequestContext:self.requestContext]];
    [responseHandlers addObject:[[EMSRefreshTokenResponseHandler alloc] initWithRequestContext:self.requestContext]];
    [responseHandlers addObject:contactTokenResponseHandler];
    _responseHandlers = [NSArray arrayWithArray:responseHandlers];

    _restClient = [[EMSRESTClient alloc] initWithSession:session
                                                   queue:self.operationQueue
                                       timestampProvider:timestampProvider
                                       additionalHeaders:[MEDefaultHeaders additionalHeadersWithConfig:config]
                                     requestModelMappers:@[
                                         [[EMSContactTokenMapper alloc] initWithRequestContext:self.requestContext],
                                         [[EMSV3Mapper alloc] initWithRequestContext:self.requestContext]]
                                        responseHandlers:self.responseHandlers];

    EMSRESTClientCompletionProxyFactory *proxyFactory = [[EMSCompletionProxyFactory alloc] initWithRequestRepository:self.requestRepository
                                                                                                      operationQueue:self.operationQueue
                                                                                                 defaultSuccessBlock:middleware.successBlock
                                                                                                   defaultErrorBlock:middleware.errorBlock
                                                                                                          restClient:self.restClient
                                                                                                      requestFactory:self.requestFactory
                                                                                              contactResponseHandler:contactTokenResponseHandler];

    EMSConnectionWatchdog *watchdog = [[EMSConnectionWatchdog alloc] initWithOperationQueue:self.operationQueue];
    EMSDefaultWorker *worker = [[EMSDefaultWorker alloc] initWithOperationQueue:self.operationQueue
                                                              requestRepository:self.requestRepository
                                                             connectionWatchdog:watchdog
                                                                     restClient:self.restClient
                                                                     errorBlock:middleware.errorBlock
                                                                   proxyFactory:proxyFactory];

    _requestManager = [[EMSRequestManager alloc] initWithCoreQueue:self.operationQueue
                                              completionMiddleware:middleware
                                                        restClient:self.restClient
                                                            worker:worker
                                                 requestRepository:self.requestRepository
                                                   shardRepository:shardRepository
                                                      proxyFactory:proxyFactory];

    if ([MEExperimental isFeatureEnabled:EMSInnerFeature.predict]) {
        _predictTrigger = [[EMSBatchingShardTrigger alloc] initWithRepository:shardRepository
                                                                specification:[[EMSFilterByTypeSpecification alloc] initWitType:@"predict_%%"
                                                                                                                         column:SHARD_COLUMN_NAME_TYPE]
                                                                       mapper:[[EMSPredictMapper alloc] initWithRequestContext:self.predictRequestContext]
                                                                      chunker:[[EMSListChunker alloc] initWithChunkSize:1]
                                                                    predicate:[[EMSCountPredicate alloc] initWithThreshold:1]
                                                               requestManager:self.requestManager
                                                                   persistent:YES];
        [_dbHelper registerTriggerWithTableName:SHARD_TABLE_NAME
                                    triggerType:EMSDBTriggerType.afterType
                                   triggerEvent:EMSDBTriggerEvent.insertEvent
                                        trigger:self.predictTrigger];
    }

    _loggerTrigger = [[EMSBatchingShardTrigger alloc] initWithRepository:shardRepository
                                                           specification:[[EMSFilterByTypeSpecification alloc] initWitType:@"log_%%"
                                                                                                                    column:SHARD_COLUMN_NAME_TYPE]
                                                                  mapper:[[EMSLogMapper alloc] initWithRequestContext:self.requestContext
                                                                                                      applicationCode:config.applicationCode
                                                                                                           merchantId:config.merchantId]
                                                                 chunker:[[EMSListChunker alloc] initWithChunkSize:10]
                                                               predicate:[[EMSCountPredicate alloc] initWithThreshold:10]
                                                          requestManager:self.requestManager
                                                              persistent:NO];
    [_dbHelper registerTriggerWithTableName:SHARD_TABLE_NAME
                                triggerType:EMSDBTriggerType.afterType
                               triggerEvent:EMSDBTriggerEvent.insertEvent
                                    trigger:self.loggerTrigger];

    _notificationCache = [[EMSNotificationCache alloc] init];

    _deviceInfoClient = [[EMSDeviceInfoV3ClientInternal alloc] initWithRequestManager:self.requestManager
                                                                       requestFactory:self.requestFactory
                                                                           deviceInfo:deviceInfo
                                                                       requestContext:self.requestContext];

    _appStartBlockProvider = [[AppStartBlockProvider alloc] initWithRequestManager:self.requestManager
                                                                    requestFactory:self.requestFactory
                                                                    requestContext:self.requestContext
                                                                  deviceInfoClient:self.deviceInfoClient];

    if ([MEExperimental isFeatureEnabled:EMSInnerFeature.predict]) {
        _predict = [[PredictInternal alloc] initWithRequestContext:self.predictRequestContext
                                                    requestManager:self.requestManager];
    } else {
        _predict = [EMSLoggingPredictInternal new];
    }

    if ([MEExperimental isFeatureEnabled:EMSInnerFeature.mobileEngage]) {
        _mobileEngage = [[EMSMobileEngageV3Internal alloc] initWithRequestFactory:self.requestFactory
                                                                   requestManager:self.requestManager
                                                                   requestContext:self.requestContext];
        _deepLink = [[EMSDeepLinkInternal alloc] initWithRequestManager:self.requestManager
                                                         requestFactory:self.requestFactory];
        _push = [[EMSPushV3Internal alloc] initWithRequestFactory:self.requestFactory
                                                   requestManager:self.requestManager
                                                notificationCache:self.notificationCache
                                                timestampProvider:timestampProvider];
        _inbox = [[MEInbox alloc] initWithConfig:config
                                  requestContext:self.requestContext
                               notificationCache:self.notificationCache
                                  requestManager:self.requestManager
                                  requestFactory:self.requestFactory];
        _notificationCenterDelegate = [[MEUserNotificationDelegate alloc] initWithApplication:[UIApplication sharedApplication]
                                                                         mobileEngageInternal:self.mobileEngage
                                                                                        inApp:self.iam
                                                                            timestampProvider:timestampProvider
                                                                                 pushInternal:self.push
                                                                               requestManager:self.requestManager
                                                                               requestFactory:self.requestFactory];
    } else {
        _mobileEngage = [EMSLoggingMobileEngageInternal new];
        _deepLink = [EMSLoggingDeepLinkInternal new];
        _push = [EMSLoggingPushInternal new];
        _inbox = [EMSLoggingInbox new];
        _notificationCenterDelegate = [EMSLoggingUserNotificationDelegate new];
    }

    [self.iam setInAppTracker:[[EMSInAppInternal alloc] initWithRequestManager:self.requestManager
                                                                requestFactory:self.requestFactory]];
}

- (EMSCompletionMiddleware *)createMiddleware {
    return [[EMSCompletionMiddleware alloc] initWithSuccessBlock:[self createSuccessBlock]
                                                      errorBlock:[self createErrorBlock]];
}

- (void (^)(NSString *, EMSResponseModel *))createSuccessBlock {
    return ^(NSString *requestId, EMSResponseModel *response) {
    };
}

- (void (^)(NSString *, NSError *))createErrorBlock {
    return ^(NSString *requestId, NSError *error) {
    };
}

@end
