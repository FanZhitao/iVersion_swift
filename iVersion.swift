//
//  iVersion.swift
//  iVersion
//
//  Created by Zhitao Fan on 1/26/17.
//  Copyright © 2017 Mobileware. All rights reserved.
//

import Foundation
#if os(iOS)
    import UIKit
    #else
    import AppKit
#endif
import StoreKit

// TODO: is inherited from NSObject necessary?
class iVersion : NSObject {
    // singleton
    static let sharedInstance = iVersion()
    
    func localizedString(forKey key: String, withDefault defaultString: String) -> String {
        struct Holder {
            static var bundle: Bundle?
        }
        if Holder.bundle == nil {
            var bundlePath: String? = Bundle(for: iVersion.self).path(forResource: "iVersion", ofType: "bundle")
            if self.useAllAvailableLanguages {
                Holder.bundle = Bundle(path: bundlePath!)
                var language: String = NSLocale.preferredLanguages().count ? NSLocale.preferredLanguages()[0] : "en"
                if !Holder.bundle?.localizations()?.contains(language) {
                    language = language.components(separatedBy: "-")[0]
                }
                if Holder.bundle?.localizations()?.contains(language) {
                    bundlePath = Holder.bundle?.path(forResource: language, ofType: "lproj")
                }
            }
            Holder.bundle = Bundle(path: bundlePath!) ?? Bundle.main
        }
        defaultString = bundle?.localizedString(forKey: key, value: defaultString, table: nil)
        return Bundle.main.localizedString(forKey: key, value: defaultString, table: nil)
    }
    
    // public properties
    
    //app store ID - this is only needed if your
    //bundle ID is not unique between iOS and Mac app stores
    var appStoreID: UInt? {
        get {
            return UserDefaults.standard.object(forKey: iVersionAppStoreIDKey) as? UInt
        }
        set(newID) {
            UserDefaults.standard.set(newID, forKey: iVersionAppStoreIDKey)
            UserDefaults.standard.synchronize()
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
    var inThisVersionTitle: String? {
        get {
            return self.localizedString(forKey: iVersionInThisVersionTitleKey, withDefault: "New in this version")
        }
    }
    var updateAvailableTitle: String? {
        get {
            return self.localizedString(forKey: iVersionUpdateAvailableTitleKey, withDefault: "New version available")
        }
    }
    var versionLabelFormat: String? {
        get {
            return self.localizedString(forKey: iVersionVersionLabelFormatKey, withDefault: "Version %@")
        }
    }
    var okButtonLabel: String? {
        get {
            return self.localizedString(forKey: iVersionOKButtonKey, withDefault: "New version available")
        }
    }
    var ignoreButtonLabel: String? {
        get {
            return self.localizedString(forKey: iVersionIgnoreVersionKey, withDefault: "Ignore")
        }
    }
    var remindButtonLabel: String? {
        get {
            return self.localizedString(forKey: iVersionRemindButtonKey, withDefault: "Remind Me Later")
        }
    }
    var downloadButtonLabel: String? {
        get {
            return self.localizedString(forKey: iVersionDownloadButtonKey, withDefault: "Download")
        }
    }
    
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
    var localVersionsPlistPath: String?
    var ignoredVersion: String? {
        get {
            return UserDefaults.standard.object(forKey: iVersionIgnoreVersionKey) as? String
        }
        set(newVersion) {
            UserDefaults.standard.setValue(newVersion, forKey: iVersionIgnoreVersionKey)
            UserDefaults.standard.synchronize()
        }
    }
    var lastChecked: Date? {
        get {
            return UserDefaults.standard.object(forKey: iVersionLastCheckedKey) as? Date
        }
        set(newLastChecked) {
            UserDefaults.standard.setValue(newLastChecked, forKey: iVersionLastCheckedKey)
            UserDefaults.standard.synchronize()
        }
    }
    var lastReminded: Date? {
        get {
            return UserDefaults.standard.object(forKey: iVersionLastRemindedKey) as? Date
        }
        set(newLastReminded) {
            UserDefaults.standard.setValue(newLastReminded, forKey: iVersionLastRemindedKey)
            UserDefaults.standard.synchronize()
        }
    }
    var updateURL: URL? {
        get {
            return URL.init(string: String.init(format: iVersioniOSAppStoreURLFormat, self.appStoreID!))
        }
    }
    var viewedVersionDetails: Bool? {
        get {
            return UserDefaults.standard.object(forKey: iVersionLastVersionKey) as? Bool
        }
        set(newDetails) {
            UserDefaults.standard.setValue(newDetails == nil ? self.applicationVersion : nil, forKey: iVersionLastVersionKey)
        }
    }
    var delegate: iVersionDelegate? { // TODO: weak?
        get {
            return UIApplication.shared.delegate as! iVersionDelegate?
        }
    }
    
    
    private var lastVersion: String? {
        get {
            return UserDefaults.standard.object(forKey: iVersionLastVersionKey) as? String
        }
        set(newVersion) {
            UserDefaults.standard.setValue(newVersion, forKey: iVersionLastVersionKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    #if os(iOS)
    
    //manually control behaviour
    func openAppPageInAppStore() -> Bool {
        if self.updateURL == nil && self.appStoreID == nil {
            print("iVersion was unable to open the App Store because the app store ID is not set.")
        }
        return false
    }
    
    func checkIfNewVersion() {
        
    }
    
    private var versionDetails: String {
        get {
            if self.viewedVersionDetails != nil {
                return
            }
        }
    }
    
    func shouldCheckForNewVersion() -> Bool {
        // TODO
        return false
    }
    
    func checkForNewVersion() {
        
    }
    
    private func mostRecentVersionInDict(dict: NSDictionary) -> String {
        (dict.allKeys as NSArray).sortedArray(using: #selector(compareVersion)).last!
    }
    
    private func versionDetailsInDict(version: String, dict: NSDictionary) -> String {
        let versionData = dict[version]
        if versionData is String {
            return versionData! as! String
        } else if versionData is [Any] {
            return (versionData as! NSArray).componentsJoined(by: "\n")
        }
    }
    
    func versionDetails(since lastVersion: String, inDict dict: [AnyHashable: Any]) -> String {
        if self.previewMode {
            lastVersion = "0"
        }
        var newVersionFound: Bool = false
        var details = String()
        var versions: [Any] = (dict.keys as NSArray).sortedArray(using: #selector(self.compareVersionDescending))
        for version: String in versions {
            if version.compare(lastVersion) == .orderedDescending {
                newVersionFound = true
                if self.groupNotesByVersion {
                    details += self.versionLabelFormat.replacingOccurrences(of: "%@", with: version)
                    details += "\n\n"
                }
                details += self.versionDetails(version, inDict: dict) ?? ""
                details += "\n"
                if self.groupNotesByVersion {
                    details += "\n"
                }
            }
        }
        return newVersionFound ? details.trimmingCharacters(in: CharacterSet.newlines) : nil
    }
    
    
    // private properties
    private var remoteVersionsDict: NSDictionary?
    private var downloadError: Error
    private var versionDetails: String? {
        get {
            if (self.viewedVersionDetails) {
                return self.versionDetailsInDict(version: self.applicationVersion, dict: self.localVersionsDict())
            } else {
                return self.versionDetails(since: self.lastVersion, inDict: self.localVersionsDict())
            }
        }
    }
    private var visibleLocalAlert: AnyObject?
    private var visibleRemoteAlert: AnyObject?
    private var checkingForNewVersion: Bool // TODO: how to deal with assign property
    
    
    private func urlEncodedString(_ string: String) -> String {
        var stringRef: CFString = CFBridgingRetain(string)
        //clang diagnostic push
        //clang diagnostic ignored "-Wdeprecated-declarations"
        var encoded: CFString = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, stringRef, nil, CFSTR("!*'\"();:@&=+$,/?%#[]% "), kCFStringEncodingUTF8)
        //clang diagnostic pop
        
        return CFBridgingRelease(encoded)
    }
    
    private func downloadedVersionsData() {
        #if !TARGET_OS_IPHONE
            //only show when main window is available
            if self.onlyPromptIfMainWindowIsAvailable && !NSApplication.shared.mainWindow() {
                self.performSelector(#selector(self.downloadedVersionsData), withObject: nil, afterDelay: 0.5)
                return
            }
        #endif
        if self.checkingForNewVersion {
            //no longer checking
            self.checkingForNewVersion = false
            //check if data downloaded
            if !self.remoteVersionsDict {
                //log the error
                if self.downloadError {
                    print("iVersion update check failed because: \(self.downloadError.localizedDescription)")
                }
                else {
                    print("iVersion update check failed because an unknown error occured")
                }
                if self.delegate.responds(to: #selector(self.iVersionVersionCheckDidFailWithError)) {
                    self.delegate.iVersionVersionCheckDidFailWithError(self.downloadError)
                }
                else if self.delegate.responds(to: #selector(self.iVersionVersionCheckFailed)) {
                    print("iVersionVersionCheckFailed: delegate method is deprecated, use iVersionVersionCheckDidFailWithError: instead")
                    self.delegate.perform(#selector(self.iVersionVersionCheckFailed), with: self.downloadError)
                }
                
                return
            }
            //get version details
            var details: String = self.versionDetails(since: self.applicationVersion, in: self.remoteVersionsDict)
            var mostRecentVersion: String = self.mostRecentVersion(in: self.remoteVersionsDict)
            if details != "" {
                //inform delegate of new version
                if self.delegate.responds(to: Selector("iVersionDidDetectNewVersion:details:")) {
                    self.delegate.iVersionDidDetectNewVersion(mostRecentVersion, details: details)
                }
                var mostRecentVersion: String = self.mostRecentVersion(in: self.remoteVersionsDict)
                if details {
                    //inform delegate of new version
                    if self.delegate.responds(to: Selector("iVersionDidDetectNewVersion:details:")) {
                        self.delegate.iVersionDidDetectNewVersion(mostRecentVersion, details: details)
                    }
                    else if self.delegate.responds(to: Selector("iVersionDetectedNewVersion:details:")) {
                        print("iVersionDetectedNewVersion:details: delegate method is deprecated, use iVersionDidDetectNewVersion:details: instead")
                        self.delegate.perform(Selector("iVersionDetectedNewVersion:details:"), withObject: mostRecentVersion, withObject: details)
                    }
                    
                    //check if ignored
                    var showDetails: Bool = !(self.ignoredVersion == mostRecentVersion) || self.previewMode
                    if showDetails {
                        if self.delegate.responds(to: Selector("iVersionShouldDisplayNewVersion:details:")) {
                            showDetails = self.delegate.iVersionShouldDisplayNewVersion(mostRecentVersion, details: details)
                            if !showDetails && self.verboseLogging {
                                print("iVersion did not display the new version because the iVersionShouldDisplayNewVersion:details: delegate method returned NO")
                            }
                        }
                    }
                    else if self.verboseLogging {
                        print("iVersion did not display the new version because it was marked as ignored")
                    }
                    
                    //show details
                    if showDetails && !self.visibleRemoteAlert {
                        var title: String = self.updateAvailableTitle
                        if !self.groupNotesByVersion {
                            title = title.appendingFormat(" (%@)", mostRecentVersion)
                        }
                        self.visibleRemoteAlert = self.showAlert(withTitle: title, details: details, defaultButton: self.downloadButtonLabel, ignoreButton: self.showIgnoreButton() ? self.ignoreButtonLabel : nil, remindButton: self.showRemindButton() ? self.remindButtonLabel : nil)
                    } else if self.delegate.responds(to: #selector(self.iVersionDidNotDetectNewVersion)) {
                        self.delegate.iVersionDidNotDetectNewVersion()
                    }
                }
            }
        }
    
    private func localVersionsDict() -> NSDictionary {
        // static var workaround
        // ref: http://stackoverflow.com/questions/25354882/static-function-variables-in-swift
        struct Holder {
            static var versionsDict: NSDictionary?
        }
        if Holder.versionsDict == nil {
            if self.localVersionsPlistPath == nil {
                Holder.versionsDict = NSDictionary() //empty dictionary
            } else {
                var versionsFile: String = URL(fileURLWithPath: (Bundle.main.resourcePath)!).appendingPathComponent(self.localVersionsPlistPath!).absoluteString
                Holder.versionsDict = NSDictionary.init(contentsOfFile: versionsFile)
                if Holder.versionsDict. {
                    // Get the path to versions plist in localized directory
                    var pathComponents: [Any] = self.localVersionsPlistPath.components(separatedBy: ".")
                    versionsFile = (pathComponents.count == 2) ? Bundle.main.path(forResource: pathComponents[0], ofType: pathComponents[1]) : nil
                    Holder.versionsDict = [AnyHashable: Any](contentsOfFile: versionsFile)
                }
            }
        }
        return Holder.versionsDict!
    }
    
    override init() {
        super.init()
        
        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: Notification.Name.UIApplicationWillEnterForeground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didRotate), name: Notification.Name.UIDeviceOrientationDidChange, object: nil)
        #endif
        
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
        
        //app launched
        self.performSelector(onMainThread: #selector(applicationLaunched), with: nil, waitUntilDone: false)
        
    }
    
    @objc func applicationLaunched() {
        if self.checkAtLaunch {
            self.checkIfNewVersion()
            if self.shouldCheckForNewVersion() {
                self.checkForNewVersion()
            }
        } else if self.verboseLogging {
            print("iVersion will not check for updates because the checkAtLaunch option is disabled")
        }
    }
    
    @objc func applicationWillEnterForeground() {
        if UIApplication.shared.applicationState == UIApplicationState.background {
            if self.checkAtLaunch {
                if self.shouldCheckForNewVersion() {
                    self.checkForNewVersion()
                }
            } else if (self.verboseLogging) {
                print("iVersion will not check for updates because the checkAtLaunch option is disabled")
            }
        }
    }
    
    @objc func didRotate() {
        
    }
}


// NSString extensions at line 83 - 93 in iVersion.m

extension String {
    @objc func compareVersion(version: String) -> ComparisonResult {
        //TODO: return self.compare(version: version, options: NSNumbericSearch)
        return ComparisonResult.orderedSame
    }
    
    @objc func compareVerisonDescending(version: String) -> ComparisonResult {
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

