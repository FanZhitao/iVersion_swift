//
//  iVersion.swift
//  iVersion
//
//  Created by Zhitao Fan on 1/26/17.
//  Copyright © 2017 Mobileware. All rights reserved.
//

import Foundation
import UIKit
import StoreKit

// TODO: is inherited from NSObject necessary?
class iVersion : NSObject {
    // singleton
    static let sharedInstance = iVersion()
    
    // public properties
    
    //app store ID - this is only needed if your
    //bundle ID is not unique between iOS and Mac app stores
    var appStoreID: UInt {
        get {
            return UserDefaults.standard.object(forKey: iVersionAppStoreIDKey) as! UInt
        }
    }
    
    //application details - these are set automatically
    var applicationVersion: String
    var applicationBundleID: String
    var appStoreCountry: String?
    
    //usage settings - these have sensible defaults
    var showOnFirstLaunch: Bool
    var groupNotesByVersion: Bool
    var checkPeriod: Float
    var remindPeriod: Float
    
    //message text - you may wish to customise these
    var inThisVersionTitle: String
    var updateAvailableTitle: String
    var versionLabelFormat: String
    var okButtonLabel: String
    var ignoreButtonLabel: String
    var remindButtonLabel: String
    var downloadButtonLabel: String
    
    //debugging and prompt overrides
    var updatePriority: iVersionUpdatePriority
    var useUIAlertControllerIfAvailable: Bool
    var useAllAvailableLanguages: Bool
    var onlyPromptIfMainWindowIsAvailable: Bool
    var useAppStoreDetailsIfNoPlistEntryFound: Bool
    var checkAtLaunch: Bool
    var verboseLogging: Bool
    var previewMode: Bool
    
    //advanced properties for implementing custom behaviour
    var remoteVersionsPlistURL: String
    var localVersionsPlistPath: String
    var ignoredVersion: String
    var lastChecked: Date
    var lastReminded: Date
    var updateURL: URL
    var viewedVersionDetails: Bool
    weak var delegate: iVersionDelegate? {
        get {
            return UIApplication.shared.delegate as! iVersionDelegate?
        }
    }
    
    
    //manually control behaviour
    func openAppPageInAppStore() -> Bool {
        // TODO
        return false
    }
    
    func checkIfNewVersion() {
        
    }
    
    func versionDetails() -> String {
        return "TODO"
    }
    
    func shouldCheckForNewVersion() -> Bool {
        // TODO
        return false
    }
    
    func checkForNewVersion() {
        
    }
    
    
    // private properties
    private var remoteVersionsDict: Dictionary<String, String> // TODO: @NSCopying necessary?
    private var downloadError: Error
    //private var versionDetails: String
    private var visibleLocalAlert: AnyObject?
    private var visibleRemoteAlert: AnyObject?
    private var checkingForNewVersion: Bool // TODO: how to deal with assign property
    
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: Notification.Name.UIApplicationWillEnterForeground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didRotate), name: Notification.Name.UIDeviceOrientationDidChange, object: nil)
        
        //get country
        self.appStoreCountry = Locale.current.currencyCode
        if (self.appStoreCountry == "150") {
            self.appStoreCountry = "eu"
            //} else if (self.appStoreCountry?.replacingOccurrences(of: "[A-Za-z]{2}", with: "", options: .regularExpression, range: nil) {
        } else if (self.appStoreCountry == "GI") {
            self.appStoreCountry = "GB"
        }
        
        //application version (use short version preferentially)
        self.applicationVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        if (self.applicationVersion.isEmpty) {
            self.applicationVersion = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
        }
        
        //bundle id
        self.applicationBundleID = Bundle.main.bundleIdentifier!
        
        //default settings
        self.updatePriority = iVersionUpdatePriority.iVersionUpdatePriorityDefault
        self.useAllAvailableLanguages = true
        self.onlyPromptIfMainWindowIsAvailable = true
        self.checkAtLaunch = true
        self.checkPeriod = 0.0
        self.remindPeriod = 1.0
        
        //enable verbose logging in debug mode
        self.verboseLogging = true
        
    }
    
    @objc func applicationWillEnterForeground() {
        
    }
    
    @objc func didRotate() {
        
    }
}


// NSString extensions at line 83 - 93 in iVersion.m

extension NSString {
    func compareVersion(version: String) -> ComparisonResult {
        //TODO: return self.compare(version: version, options: NSNumbericSearch)
        return ComparisonResult.orderedSame
    }
    
    func compareVerisonDescending(version: String) -> ComparisonResult {
        //TODO
        return ComparisonResult.orderedSame
    }
}

// TODO: is conforming to protocol <NSObject> necessary?
// Need to add @objc optional?
protocol iVersionDelegate : NSObjectProtocol {
    func iVersionShouldCheckForNewVersion() -> Bool
    func iVersionDidNotDetectNewVersion()
    func iVersionVersionCheckDidFailWithError(error: Error)
    func iVersionDidDetectNewVersion(version: String, versionDetails: String)
    func iVersionShouldDisplayNewVersion(version: String, versionDetails: String) -> Bool
    func iVersionShouldDisplayCurrentVersionDetails(versionDetails: String) -> Bool
    func iVersionUserDidAttemptToDownloadUpdate(version: String)
    func iVersionUserDidRequestReminderForUpdate(version: String)
    func iVersionUserDidIgnoreUpdate(version: String)
    func iVersionShouldOpenAppStore() -> Bool
    func iVersionDidPresentStoreKitModal()
    func iVersionDidDismissStoreKitModal()
}

