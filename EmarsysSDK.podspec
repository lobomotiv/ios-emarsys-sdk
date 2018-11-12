Pod::Spec.new do |spec|
	spec.name                 = 'EmarsysSDK'
	spec.version              = '2.0.0'
	spec.homepage             = 'https://help.emarsys.com/hc/en-us/articles/115002410625'
	spec.license              = 'Mozilla Public License 2.0'
    spec.author               = { 'Emarsys Technologies' => 'mobile-team@emarsys.com' }
	spec.summary              = 'Mobile Engage iOS SDK'
	spec.platform             = :ios, '9.0'
	spec.source               = { :git => 'git@github.com:emartech/ios-emarsys-sdk.git', :tag => spec.version }
	spec.source_files         = [
       'Core/**/*.{h,m}',
	   'MobileEngage/**/*.{h,m}',
       'Predict/**/*.{h,m}',
       'EmarsysSDK/**/*.{h,m}'
	]
	spec.exclude_files	  = 'MobileEngage/RichNotificationExtension/*'
	spec.public_header_files  = [
			'EmarsysSDK/Emarsys.h',
			'EmarsysSDK/EMSInAppProtocol.h',
			'EmarsysSDK/EMSInboxProtocol.h',
			'EmarsysSDK/EMSPredictProtocol.h',
			'EmarsysSDK/EMSPushNotificationProtocol.h',
			'EmarsysSDK/EMSBlocks.h',
			'Predict/EMSCartItemProtocol.h',
      'Predict/EMSCartItem.h',
			'MobileEngage/IAM/EMSEventHandler.h',
			'MobileEngage/Inbox/EMSNotification.h',
			'MobileEngage/Inbox/EMSNotificationInboxStatus.h',
			'MobileEngage/Flipper/EMSFlipperFeatures.h',
			'MobileEngage/RichNotification/EMSUserNotificationCenterDelegate.h',
			'MobileEngage/EMSConfig.h',
			'MobileEngage/EMSConfigBuilder.h'
   	]
	spec.libraries = 'z', 'c++'
end