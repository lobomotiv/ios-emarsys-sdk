//
// Copyright (c) 2018 Emarsys. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EMSRequestModelRepositoryProtocol.h"
#import "EMSRequestModelRepository.h"

@class MEButtonClickRepository;
@class MEDisplayedIAMRepository;
@class MEInApp;
@class MERequestContext;
@class EMSDeviceInfo;

@interface MERequestRepositoryProxy : NSObject <EMSRequestModelRepositoryProtocol>

@property(nonatomic, readonly) MEInApp *inApp;
@property(nonatomic, readonly) EMSRequestModelRepository *requestModelRepository;
@property(nonatomic, readonly) MEButtonClickRepository *clickRepository;
@property(nonatomic, readonly) MEDisplayedIAMRepository *displayedIAMRepository;
@property(nonatomic, readonly) MERequestContext *requestContext;

- (instancetype)initWithRequestModelRepository:(EMSRequestModelRepository *)requestModelRepository
                         buttonClickRepository:(MEButtonClickRepository *)buttonClickRepository
                        displayedIAMRepository:(MEDisplayedIAMRepository *)displayedIAMRepository
                                         inApp:(MEInApp *)inApp
                                requestContext:(MERequestContext *)requestContext;

@end