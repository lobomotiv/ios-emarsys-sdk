//
// Copyright (c) 2019 Emarsys. All rights reserved.
//
#import "EMSRequestFactory.h"
#import "EMSRequestModel.h"
#import "MERequestContext.h"
#import "MEEndpoints.h"
#import "EMSDeviceInfo+MEClientPayload.h"
#import "NSDate+EMSCore.h"
#import "EmarsysSDKVersion.h"
#import "EMSNotification.h"
#import "EMSAuthentication.h"

@interface EMSRequestFactory ()

@property(nonatomic, strong) MERequestContext *requestContext;
@property(nonatomic, strong) NSString *applicationCode;
@property(nonatomic, strong) EMSDeviceInfo *deviceInfo;

@end

@implementation EMSRequestFactory

- (instancetype)initWithRequestContext:(MERequestContext *)requestContext {
    NSParameterAssert(requestContext);
    if (self = [super init]) {
        _requestContext = requestContext;
        _applicationCode = requestContext.config.applicationCode;
        _deviceInfo = requestContext.deviceInfo;
    }
    return self;
}

- (EMSRequestModel *)createDeviceInfoRequestModel {
    __weak typeof(self) weakSelf = self;
    return [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
            [builder setUrl:CLIENT_URL(weakSelf.applicationCode)];
            [builder setMethod:HTTPMethodPOST];
            [builder setPayload:[weakSelf.deviceInfo clientPayload]];
        }
                          timestampProvider:self.requestContext.timestampProvider
                               uuidProvider:self.requestContext.uuidProvider];
}

- (EMSRequestModel *)createPushTokenRequestModelWithPushToken:(NSString *)pushToken {
    __weak typeof(self) weakSelf = self;
    return [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
            [builder setUrl:PUSH_TOKEN_URL(weakSelf.applicationCode)];
            [builder setMethod:HTTPMethodPUT];
            [builder setPayload:@{@"pushToken": pushToken}];
        }
                          timestampProvider:self.requestContext.timestampProvider
                               uuidProvider:self.requestContext.uuidProvider];
}

- (EMSRequestModel *)createClearPushTokenRequestModel {
    __weak typeof(self) weakSelf = self;
    return [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
            [builder setUrl:PUSH_TOKEN_URL(weakSelf.applicationCode)];
            [builder setMethod:HTTPMethodDELETE];
            [builder setPayload:@{}];
        }
                          timestampProvider:self.requestContext.timestampProvider
                               uuidProvider:self.requestContext.uuidProvider];
}

- (EMSRequestModel *)createContactRequestModel {
    __weak typeof(self) weakSelf = self;
    return [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
            [builder setMethod:HTTPMethodPOST];
            BOOL anonymousLogin = NO;
            NSDictionary *payload = @{};
            if (weakSelf.requestContext.contactFieldId && weakSelf.requestContext.contactFieldValue) {
                payload = @{
                    @"contactFieldId": weakSelf.requestContext.contactFieldId,
                    @"contactFieldValue": weakSelf.requestContext.contactFieldValue
                };
            } else {
                anonymousLogin = YES;
            }
            [builder setUrl:CONTACT_URL(weakSelf.applicationCode)
            queryParameters:@{@"anonymous": anonymousLogin ? @"true" : @"false"}];
            [builder setPayload:payload];
        }
                          timestampProvider:self.requestContext.timestampProvider
                               uuidProvider:self.requestContext.uuidProvider];
}

- (EMSRequestModel *)createEventRequestModelWithEventName:(NSString *)eventName
                                          eventAttributes:(nullable NSDictionary<NSString *, NSString *> *)eventAttributes
                                                eventType:(EventType)eventType {
    __weak typeof(self) weakSelf = self;
    return [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
            [builder setMethod:HTTPMethodPOST];
            [builder setUrl:EVENT_URL(weakSelf.applicationCode)];

            NSMutableDictionary *mutableEvent = [NSMutableDictionary dictionary];
            mutableEvent[@"type"] = [weakSelf eventTypeStringRepresentationFromEventType:eventType];
            mutableEvent[@"name"] = eventName;
            mutableEvent[@"timestamp"] = [[weakSelf.requestContext.timestampProvider provideTimestamp] stringValueInUTC];
            mutableEvent[@"attributes"] = eventAttributes;

            NSMutableDictionary *mutablePayload = [NSMutableDictionary dictionary];
            mutablePayload[@"clicks"] = @[];
            mutablePayload[@"viewedMessages"] = @[];
            mutablePayload[@"events"] = @[
                [NSDictionary dictionaryWithDictionary:mutableEvent]
            ];
            [builder setPayload:[NSDictionary dictionaryWithDictionary:mutablePayload]];
        }
                          timestampProvider:self.requestContext.timestampProvider
                               uuidProvider:self.requestContext.uuidProvider];
}

- (EMSRequestModel *)createRefreshTokenRequestModel {
    __weak typeof(self) weakSelf = self;
    return [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
            [builder setMethod:HTTPMethodPOST];
            [builder setUrl:CONTACT_TOKEN_URL(weakSelf.applicationCode)];
            NSMutableDictionary *mutablePayload = [NSMutableDictionary dictionary];
            mutablePayload[@"refreshToken"] = weakSelf.requestContext.refreshToken;
            [builder setPayload:[NSDictionary dictionaryWithDictionary:mutablePayload]];
        }
                          timestampProvider:self.requestContext.timestampProvider
                               uuidProvider:self.requestContext.uuidProvider];
}

- (EMSRequestModel *)createDeepLinkRequestModelWithTrackingId:(NSString *)trackingId {
    NSString *userAgent = [NSString stringWithFormat:@"Emarsys SDK %@ %@ %@", EMARSYS_SDK_VERSION,
                                                     self.requestContext.deviceInfo.deviceType,
                                                     self.requestContext.deviceInfo.osVersion];
    return [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
            [builder setMethod:HTTPMethodPOST];
            [builder setUrl:@"https://deep-link.eservice.emarsys.net/api/clicks"];
            [builder setHeaders:@{@"User-Agent": userAgent}];
            [builder setPayload:@{@"ems_dl": trackingId}];
        }
                          timestampProvider:self.requestContext.timestampProvider
                               uuidProvider:self.requestContext.uuidProvider];
}

- (EMSRequestModel *)createMessageOpenWithNotification:(EMSNotification *)notification {
    EMSRequestModel *requestModel = [EMSRequestModel makeWithBuilder:^(EMSRequestModelBuilder *builder) {
            [builder setUrl:@"https://push.eservice.emarsys.net/api/mobileengage/v2/events/message_open"];
            [builder setMethod:HTTPMethodPOST];

            NSMutableDictionary *payload = [NSMutableDictionary dictionary];
            payload[@"application_id"] = self.requestContext.config.applicationCode;
            payload[@"hardware_id"] = self.requestContext.deviceInfo.hardwareId;
            payload[@"sid"] = notification.sid;
            payload[@"source"] = @"inbox";

            if (self.requestContext.contactFieldId && self.requestContext.contactFieldValue) {
                payload[@"contact_field_id"] = self.requestContext.contactFieldId;
                payload[@"contact_field_value"] = self.requestContext.contactFieldValue;
            }

            [builder setPayload:[NSDictionary dictionaryWithDictionary:payload]];
            [builder setHeaders:@{@"Authorization": [EMSAuthentication createBasicAuthWithUsername:self.requestContext.config.applicationCode]}];
        }
                                                   timestampProvider:self.requestContext.timestampProvider
                                                        uuidProvider:self.requestContext.uuidProvider];
    return requestModel;
}


- (NSString *)eventTypeStringRepresentationFromEventType:(EventType)eventType {
    NSString *result = @"custom";
    if (eventType == EventTypeInternal) {
        result = @"internal";
    }
    return result;
}

@end