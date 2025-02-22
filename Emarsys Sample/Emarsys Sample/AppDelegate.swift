//
//  Copyright (c) 2017 Emarsys. All rights reserved.
//

import UIKit
import UserNotifications
import EmarsysSDK

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, EMSEventHandler {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        window?.tintColor = UIColor(red: 101 / 255.0, green: 151 / 255.0, blue: 207 / 255.0, alpha: 1.0)


        let config = EMSConfig.make { builder in
            builder.setMerchantId("1428C8EE286EC34B")
            builder.setContactFieldId(3)
#if DEBUG
            builder.setMobileEngageApplicationCode("EMS11-C3FD3")
#else
            builder.setMobileEngageApplicationCode("EMS4C-9A869")
#endif
        }
        Emarsys.setup(with: config)
        Emarsys.inApp.eventHandler = self

        application.registerForRemoteNotifications()

        var options: UNAuthorizationOptions = [.alert, .sound, .badge]
        if #available(iOS 12.0, *) {
            options.insert(.provisional)
        }
        UNUserNotificationCenter.current().requestAuthorization(options: options) { [unowned self] granted, error in
            print(granted, error ?? "no error")
            if (granted) {
                Emarsys.notificationCenterDelegate.eventHandler = self
                UNUserNotificationCenter.current().delegate = Emarsys.notificationCenterDelegate
            }
        }

        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        return Emarsys.trackDeepLink(with: userActivity, sourceHandler: { url in
            print(url)
        })
    }

    func handleEvent(_ eventName: String, payload: [String: NSObject]?) {
        print(eventName, payload);
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Emarsys.push.setPushToken(deviceToken)
        NotificationCenter.default.post(name: NotificationNames.pushTokenArrived.asNotificationName(), object: nil, userInfo: ["push_token": deviceToken])
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Emarsys.push.trackMessageOpen(userInfo: userInfo)
    }

}
