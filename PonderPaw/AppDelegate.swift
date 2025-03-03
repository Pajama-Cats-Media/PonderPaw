//
//  AppDelegate.swift
//  PonderPaw
//
//  Created by Homer Quan on 1/6/25.
//

import UIKit
import UserNotifications

import FirebaseCore
import FirebaseMessaging
import FirebaseDynamicLinks

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    let gcmMessageIDKey = "gcm.message_id"
    
    func handleIncomingDynamicLink(_ url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let storyId = components?.queryItems?.first(where: { $0.name == "storyId" })?.value {
            print("Story ID: \(storyId)")
            DispatchQueue.main.async {
                DeepLinkManager.shared.storyID = storyId
            }
        }
    }
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication
                        .LaunchOptionsKey: Any]?) -> Bool {
                            FirebaseApp.configure()
                            
                            // [START set_messaging_delegate]
                            Messaging.messaging().delegate = self
                            // [END set_messaging_delegate]
                            
                            // Register for remote notifications. This shows a permission dialog on first run, to
                            // show the dialog at a more appropriate time move this registration accordingly.
                            // [START register_for_notifications]
                            
                            UNUserNotificationCenter.current().delegate = self
                            
                            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
                            UNUserNotificationCenter.current().requestAuthorization(
                                options: authOptions,
                                completionHandler: { _, _ in }
                            )
                            
                            application.registerForRemoteNotifications()
                            
                            // [END register_for_notifications]
                            
                            return true
                        }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard let incomingURL = userActivity.webpageURL else { return false }
        print("Incoming URL is \(incomingURL)")
        
        let handled = DynamicLinks.dynamicLinks().handleUniversalLink(incomingURL) { [weak self] (dynamicLink, error) in
            if let error = error {
                print("Failed to handle dynamic link: \(error.localizedDescription)")
                return
            }
            
            if let dynamicLink = dynamicLink, let url = dynamicLink.url {
                self?.handleIncomingDynamicLink(url)
            }
        }
        
        return handled
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
    }
    
    // [START receive_message]
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async
    -> UIBackgroundFetchResult {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        
        return UIBackgroundFetchResult.newData
    }
    
    // [END receive_message]
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Unable to register for remote notifications: \(error.localizedDescription)")
    }
    
    // This function is added here only for debugging purposes, and can be removed if swizzling is enabled.
    // If swizzling is disabled then this function must be implemented so that the APNs token can be paired to
    // the FCM registration token.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("APNs token retrieved: \(deviceToken)")
        
        // With swizzling disabled you must set the APNs token here.
        // Messaging.messaging().apnsToken = deviceToken
    }
}

// [START ios_10_message_handling]

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
    -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // [START_EXCLUDE]
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        // [END_EXCLUDE]
        
        // Print full message.
        print(userInfo)
        
        // Extract dynamic title and body from the notification content.
        let title = notification.request.content.title
        let body = notification.request.content.body
        
        // Use AlertPresenter to show the alert with the actual notification content.
        AlertPresenter.showAlert(title: title, message: body)
        
        // Change this to your preferred presentation option
        return [[.alert, .sound]]
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        
        // [START_EXCLUDE]
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        // [END_EXCLUDE]
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // Print full message.
        print(userInfo)
    }
}

// [END ios_10_message_handling]

extension AppDelegate: MessagingDelegate {
    // [START refresh_token]
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        
        
        
        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )
        // TODO: If necessary send token to application server.
        // Note: This callback is fired at each app startup and whenever a new token is generated.
        
    }
    
    // [END refresh_token]
}
