//
//  AppDelegate.swift
//  PredixMobileiOS
//
//  Created by Johns, Andy (GE Corporate) on 8/10/15.
//  Copyright © 2015 GE. All rights reserved.
//

import UIKit
import PredixMobileSDK

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var authenticationViewController : UIViewController?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        #if DEBUG
            if ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil {
                // Exit if we're running unit tests...
                Logger.debug("Detected running functional unit tests, not starting normal services or running normal UI processes")
                return true
            }
        #endif
        
        //Disable requirement to have a passcode set on the device. This is not recommended for production systems. A device passcode is a critical security feature of iOS devices.
        //PredixMobilityConfiguration.requireDevicePasscodeSet = false
        
        // Pre-load configuration. This will load any Settings bundles into NSUserDefaults and set default logging levels
        PredixMobilityConfiguration.loadConfiguration()
        
        // Add optional and custom services to the system if required
        //PredixMobilityConfiguration.additionalBootServicesToRegister = [OpenURLService.self]

        // Example of creating a view for full text search, assuming "body" is a property in some documents that contains a large amount of text.
        /*
        PredixMobilityConfiguration.appendDataViewDefinition("views/searchtext", version: "1") { (properties: [String : Any], emit: (Any, Any?) -> ()) -> () in
            
            if let body = properties["body"] as? String
            {
                emit(FullTextSearch.createKey(body), nil)
            }
        }
        */
        
        // create the PredixMobilityManager object. This object coordinates the application state, interacts with the various services, and holds closures called during authentication.
        
        let vc : ViewController = self.window?.rootViewController as! ViewController
        unowned let unownedSelf = self
        let pmm = PredixMobilityManager(packageWindow: vc, presentAuthentication: { (packageWindow) -> (PredixAppWindowProtocol) in
            
            // for this example we're using a new instance of the primary view controller to host the authentication pages.
            let authVC = vc.storyboard!.instantiateViewController(withIdentifier: "ViewController") as! ViewController
            authVC.isAuthenticationView = true
            unownedSelf.authenticationViewController = authVC
            unownedSelf.window?.rootViewController!.present(authVC, animated: true, completion: nil)
            return authVC as PredixAppWindowProtocol
            
            }, dismissAuthentication: { (authenticationWindow) -> () in
                
                if let authVC = unownedSelf.authenticationViewController
                {
                    unownedSelf.authenticationViewController = nil
                    authVC.dismiss(animated: true, completion: nil)
                }

        })

        // logging our current running environment
        Logger.debug("Started app with launchOptions: \(launchOptions)")
        
        if Logger.isInfoEnabled() {
            let versionInfo = PredixMobilityConfiguration.getVersionInfo()
            let processInfo = ProcessInfo.processInfo
            let device = UIDevice.current
            var runningEnvironment = "Running Environment:"
            runningEnvironment += "\n     locale: \(versionInfo[VersionInfoKeys.Locale] ?? "")"
            runningEnvironment += "\n     device system name:\(versionInfo[VersionInfoKeys.DeviceOS] ?? "")"
            runningEnvironment += "\n     device system version:\(versionInfo[VersionInfoKeys.DeviceOSVersion] ?? "")"
            runningEnvironment += "\n     device vendor identifier:\(device.identifierForVendor!.uuidString)"
            runningEnvironment += "\n     iOS Version/Build: \(processInfo.operatingSystemVersionString)"
            runningEnvironment += "\n     app bundle id: \(versionInfo[VersionInfoKeys.ApplicationBundleId] ?? "")"
            runningEnvironment += "\n     app version: \(versionInfo[VersionInfoKeys.ApplicationVersion] ?? "")"
            runningEnvironment += "\n     app build version: \(versionInfo[VersionInfoKeys.ApplicationBuildVersion] ?? "")"
            runningEnvironment += "\n     \(PredixMobilityConfiguration.versionInfo)"

            Logger.info(runningEnvironment)
        }
        
        if TARGET_OS_SIMULATOR == 1
        {
            //This will help you find where the build lives when running in the simulator
            Logger.info("Simulator build running from:\n \(Bundle.main.bundlePath)")
            let applicationSupportDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory,.userDomainMask,true).first!
            Logger.info("Simulator Application Support dir is here:\n \(applicationSupportDirectory))")
        }
        
        if let launchOptions = launchOptions, let notification = launchOptions[UIApplicationLaunchOptionsKey.localNotification] as? UILocalNotification
        {
            Logger.debug("Startup with local notification")
            Logger.trace("Startup local notification info: \(notification.userInfo)")
            PredixMobilityManager.sharedInstance.applicationDelegates.application(application, didReceiveLocalNotification: notification)
        }
        
        if let launchOptions = launchOptions, let userInfo = launchOptions[UIApplicationLaunchOptionsKey.remoteNotification] as? [AnyHashable: Any]
        {
            Logger.debug("Startup with remote notification")
            Logger.trace("Startup remote notification info: \(userInfo)")
            PredixMobilityManager.sharedInstance.applicationDelegates.application(application, didReceiveRemoteNotification: userInfo)
        }

        // start the application. This will spin up the PredixMobile environment and call the Boot service to start the application.
        pmm.startApp()
        
        self.setupRemoteNotifications()
        
        return true
    }

    // Registers for Remote (Push) Notifications.
    func setupRemoteNotifications()
    {
        self.setupUserNotificationSettings()
        UIApplication.shared.registerForRemoteNotifications()
    }

    // sets up the User Notification Settings, if those settings haven't already been setup.
    func setupUserNotificationSettings()
    {
        // get the current settings
        let settings = UIApplication.shared.currentUserNotificationSettings
        if settings == nil || settings!.categories == nil || settings!.categories!.isEmpty || settings!.types.isEmpty
        {
            // ensure the current settings have what we're expecting. If not, add what we want
            let action = UIMutableUserNotificationAction()
            action.activationMode = .foreground
            
            let actionCategory = UIMutableUserNotificationCategory()
            actionCategory.setActions([action], for: UIUserNotificationActionContext.default)
            
            let categorySet = Set<UIMutableUserNotificationCategory>(arrayLiteral: actionCategory)
            
            let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound] , categories: categorySet)
            UIApplication.shared.registerUserNotificationSettings(settings)
        }
    }

    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        #if DEBUG
            if ProcessInfo.processInfo.environment["XCInjectBundle"] != nil {
                // Exit if we're running unit tests...
                Logger.debug("Detected running functional unit tests, not starting normal services or running normal UI processes")
                return
            }
        #endif
    }
    
    //MARK: Notification handlers to pass to PredixMobilityManager
    
    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        PredixMobilityManager.sharedInstance.applicationDelegates.application(application, didReceiveLocalNotification: notification)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        PredixMobilityManager.sharedInstance.applicationDelegates.application(application, didReceiveRemoteNotification: userInfo)
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PredixMobilityManager.sharedInstance.applicationDelegates.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PredixMobilityManager.sharedInstance.applicationDelegates.application(application, didFailToRegisterForRemoteNotificationsWithError: error as NSError)
    }


}


