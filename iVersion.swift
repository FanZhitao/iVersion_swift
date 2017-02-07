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

class iVersion : NSObject, SKStoreProductViewControllerDelegate {
    // singleton
    static let sharedInstance = iVersion()
    
    func localizedString(key: String, defaultString: String) -> String? {
        var defaultString = defaultString
        struct Holder {
            static var bundle: Bundle?
        }
        if Holder.bundle == nil {
            var bundlePath: String? = Bundle(for: iVersion.self).path(forResource: "iVersion", ofType: "bundle")
            if self.useAllAvailableLanguages {
                Holder.bundle = Bundle(path: bundlePath!)
                var language: String = NSLocale.preferredLanguages.count > 0 ? NSLocale.preferredLanguages[0] : "en"
                if Holder.bundle?.localizations.contains(language) == false {
                    language = language.components(separatedBy: "-")[0]
                }
                if Holder.bundle?.localizations.contains(language) == true {
                    bundlePath = Holder.bundle?.path(forResource: language, ofType: "lproj")
                }
            }
            Holder.bundle = Bundle(path: bundlePath!) ?? Bundle.main
        }
        defaultString = (Holder.bundle?.localizedString(forKey: key, value: defaultString, table: nil))!
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
    var applicationVersion: String?
    var applicationBundleID: String?
    var appStoreCountry: String?
    
    //usage settings - these have sensible defaults
    var showOnFirstLaunch: Bool
    var groupNotesByVersion: Bool
    var checkPeriod: Double
    var remindPeriod: Double
    
    //message text - you may wish to customise these
    lazy var inThisVersionTitle : String? = self.localizedString(key: iVersionInThisVersionTitleKey, defaultString: "New in this version")
    lazy var updateAvailableTitle: String? = self.localizedString(key: iVersionUpdateAvailableTitleKey, defaultString: "New version available")
    lazy var versionLabelFormat: String? = self.localizedString(key: iVersionVersionLabelFormatKey, defaultString: "Version %@")

    lazy var okButtonLabel: String? = self.localizedString(key: iVersionOKButtonKey, defaultString: "New version available")
    lazy var ignoreButtonLabel: String? = self.localizedString(key: iVersionIgnoreVersionKey, defaultString: "Ignore")
    lazy var remindButtonLabel: String? = self.localizedString(key: iVersionRemindButtonKey, defaultString: "Remind Me Later")
    lazy var downloadButtonLabel: String? = self.localizedString(key: iVersionDownloadButtonKey, defaultString: "Download")
    
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
    weak var delegate: iVersionDelegate?    
    private var lastVersion: String? {
        get {
            return UserDefaults.standard.object(forKey: iVersionLastVersionKey) as? String
        }
        set(newVersion) {
            UserDefaults.standard.setValue(newVersion, forKey: iVersionLastVersionKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    private var showIgnoreButton : Bool {
        get {
            return !((ignoreButtonLabel?.isEmpty)!) && updatePriority.rawValue < iVersionUpdatePriority.iVersionUpdatePriorityMedium.rawValue
        }
    }
    
    private var showRemindButton : Bool {
        get {
            return !((remindButtonLabel?.isEmpty)!) && updatePriority.rawValue < iVersionUpdatePriority.iVersionUpdatePriorityHigh.rawValue
        }
    }
    
    //manually control behaviour
    func openAppPageInAppStore() -> Bool {
        if updateURL == nil && appStoreID == nil {
            print("iVersion was unable to open the App Store because the app store ID is not set.")
            return false
        }
        
        let productController = SKStoreProductViewController.init()
        productController.delegate = self
        let productParameters = [SKStoreProductParameterITunesItemIdentifier: appStoreID?.description]
        productController.loadProduct(withParameters: productParameters, completionBlock: nil)
        
        var rootViewController = UIApplication.shared.delegate?.window??.rootViewController
        if rootViewController == nil {
            if verboseLogging {
                print("iVersion couldn't find a root view controller from which to display StoreKit product page")
            }
            return false
        } else {
            while rootViewController!.presentedViewController != nil {
                rootViewController = rootViewController!.presentedViewController
            }
            rootViewController!.present(productController, animated: true, completion: nil)
            delegate?.iVersionDidPresentStoreKitModal?()
        }
        return true
    }
    
    func checkIfNewVersion() {
        if lastVersion == nil || showOnFirstLaunch || previewMode {
            if (true) { // TODO: String compare
                lastReminded = nil
                var showDetails = versionDetails != nil
                // TODO: responds to selector
                //if showDetails && delegate?.responds(to: #selector(iVersionShouldDisplayCurrentVersionDetails(versionDetails:))) {
                //    showDetails = (delegate?.iVersionShouldDisplayCurrentVersionDetails?(versionDetails: versionDetails))!
                //}
                if showDetails && visibleLocalAlert == nil && visibleRemoteAlert == nil {
                    visibleLocalAlert = showAlertWith(title: inThisVersionTitle, details: versionDetails, defaultButton: okButtonLabel, ignoreButton: nil, remindButton: nil)
                }
            }
        }
    }
    
    private func showAlertWith(title: String?, details: String?, defaultButton: String?, ignoreButton: String?, remindButton: String?) -> AnyObject {
        var topController = UIApplication.shared.delegate?.window??.rootViewController
        while topController?.presentedViewController != nil {
            topController = topController?.presentedViewController
        }
        let alert = UIAlertController.init(title: title, message: details, preferredStyle: UIAlertControllerStyle.alert)
        let downloadAction = UIAlertAction(title: downloadButtonLabel, style: UIAlertActionStyle.default) { UIAlertAction in
            self.didDismissAlert(alertView: alert, buttonIndex: 0)
        }
        alert.addAction(downloadAction)
        if showIgnoreButton {
            let ignoreAction = UIAlertAction(title: ignoreButtonLabel, style: UIAlertActionStyle.default, handler: { UIAlertAction in
                self.didDismissAlert(alertView: alert, buttonIndex: 1)
            })
            alert.addAction(ignoreAction)
        }
        if showRemindButton {
            let remindAction = UIAlertAction(title: remindButtonLabel, style: UIAlertActionStyle.default, handler: { UIAlertAction in
                self.didDismissAlert(alertView: alert, buttonIndex: self.showIgnoreButton ? 2 : 1)
            })
            alert.addAction(remindAction)
        }
        topController?.present(alert, animated: true, completion: nil)
        return alert
    }
    
    private func didDismissAlert(alertView: AnyObject, buttonIndex: Int) {
        let downloadButtonIndex = 0
        let ignoreButtonIndex = showIgnoreButton ? 1 : 0
        let remindButtonIndex = showRemindButton ? ignoreButtonIndex + 1 : 0
        
        let latestVersion = mostRecentVersionInDict(dict: remoteVersionsDict)
        
        if visibleLocalAlert === alertView {
            viewedVersionDetails = true
            visibleLocalAlert = nil
            return ;
        }
        
        if buttonIndex == downloadButtonIndex {
            lastReminded = nil
            delegate?.iVersionUserDidAttemptToDownloadUpdate?(version: latestVersion)
            if let _ = delegate?.iVersionShouldOpenAppStore?() {
                _ = openAppPageInAppStore()
            }
        } else if buttonIndex == ignoreButtonIndex {
            ignoredVersion = latestVersion
            lastReminded = nil
            delegate?.iVersionUserDidIgnoreUpdate?(version: latestVersion)
        } else if buttonIndex == remindButtonIndex {
            lastReminded = Date()
            delegate?.iVersionUserDidRequestReminderForUpdate?(version: latestVersion)
        }
    }
    
    func shouldCheckForNewVersion() -> Bool {
        if previewMode == false {
            if lastReminded != nil {
                if lastReminded!.timeIntervalSinceNow < remindPeriod * SECONDS_IN_A_DAY {
                    if verboseLogging {
                        print("iVersion did not check for a new version because the user last asked to be reminded less than \(remindPeriod) days ago")
                    }
                    return false;
                }
            }
        } else if lastChecked != nil && lastChecked!.timeIntervalSinceNow < checkPeriod * SECONDS_IN_A_DAY {
            if verboseLogging {
                print("iVersion did not check for a new version because the last check was less than \(checkPeriod) days ago")
            }
            return false
        } else if verboseLogging {
            print("iVersion debug mode is enabled - make sure you disable this for release")
        }
        
        let shouldCheck = delegate?.iVersionShouldCheckForNewVersion?()
        if shouldCheck != nil {
            if verboseLogging {
                print("iVersion did not check for a new version because the iVersionShouldCheckForNewVersion delegate method returned NO")
            }
            return shouldCheck!
        }
        
        return true
    }
    
    func checkForNewVersion() {
        if !self.checkingForNewVersion {
            self.checkingForNewVersion = true
            self.performSelector(inBackground: #selector(checkForNewVersionInBackground), with: nil)
        }
    }
    
    func checkForNewVersionInBackground() {
        // TODO
    }
    
    private func mostRecentVersionInDict(dict: NSDictionary?) -> String? {
        return dict?.keysSortedByValue(comparator: <#T##(Any, Any) -> ComparisonResult#>)
    }
    
    private func versionDetailsInDict(version: String?, dict: NSDictionary?) -> String? {
        let versionData = dict?[version]
        if versionData is String {
            return versionData! as! String
        } else if versionData is [Any] {
            return (versionData as! NSArray).componentsJoined(by: "\n")
        }
        return nil
    }
    
    private func versionDetailsSince(lastVersion: String?, dict: NSDictionary?) -> String? {
        var newVersionFound = false
        var details = String()
        if var lastVersion = lastVersion {
            if previewMode {
                lastVersion = "0"
            }
            // TODO
            //var versions: [Any] = (dict.keys as NSArray).sortedArray(using: #selector(self.compareVersionDescending))
            if let versions = dict?.allKeys {
                for version in versions {
                    let v = version as! String
                    if v.compare(lastVersion) == .orderedDescending {
                        newVersionFound = true
                        if groupNotesByVersion {
                            details += (versionLabelFormat?.replacingOccurrences(of: "%@", with: v))!
                            details += "\n\n"
                        }
                        if let d = versionDetailsInDict(version: v, dict: dict) {
                            details += d
                        }
                        details += "\n"
                        if groupNotesByVersion {
                            details += "\n"
                        }
                    }
                }
            }
        }
        return newVersionFound ? details.trimmingCharacters(in: CharacterSet.newlines) : nil
    }
    
    
    // private properties
    private var remoteVersionsDict: NSDictionary?
    private var downloadError: Error?
    private lazy var versionDetails: String? = {
        if self.viewedVersionDetails != nil {
            return self.versionDetailsInDict(version: self.applicationVersion, dict:self.localVersionsDict())
        } else {
            return self.versionDetailsSince(lastVersion: self.lastVersion, dict: self.localVersionsDict())
        }
    }()
    private var visibleLocalAlert: AnyObject?
    private var visibleRemoteAlert: AnyObject?
    private var checkingForNewVersion: Bool // TODO: how to deal with assign property
    
    
    private func urlEncodedString(_ string: String) -> String {
        return "TODO"
        /*
        var stringRef: CFString = CFBridgingRetain(string) as! CFString
        //clang diagnostic push
        //clang diagnostic ignored "-Wdeprecated-declarations"
        var encoded: CFString = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, stringRef, nil, CFSTR("!*'\"();:@&=+$,/?%#[]% "), kCFStringEncodingUTF8)
        //clang diagnostic pop
        
        return CFBridgingRelease(encoded)
 */
    }
    
    private func downloadedVersionsData() {
        if checkingForNewVersion {
            //no longer checking
            checkingForNewVersion = false
            //check if data downloaded
            if remoteVersionsDict == nil {
                //log the error
                if downloadError != nil {
                    print("iVersion update check failed because: \(downloadError!.localizedDescription)")
                } else {
                    print("iVersion update check failed because an unknown error occured")
                }
                delegate?.iVersionVersionCheckDidFailWithError?(error: downloadError)
                
                return
            }
            //get version details
            let mostRecentVersion = mostRecentVersionInDict(dict: remoteVersionsDict)
            if let details = versionDetailsInDict(version: applicationVersion, dict: remoteVersionsDict) {
                //inform delegate of new version
                delegate?.iVersionDidDetectNewVersion?(version: mostRecentVersion, versionDetails: details)

                //check if ignored
                var showDetails = !(ignoredVersion == mostRecentVersion) || previewMode
                if showDetails {
                    showDetails = (delegate?.iVersionShouldDisplayNewVersion?(version: mostRecentVersion, versionDetails: details))!
                    if !showDetails && verboseLogging {
                        print("iVersion did not display the new version because the iVersionShouldDisplayNewVersion:details: delegate method returned NO")
                    }
                } else if verboseLogging {
                    print("iVersion did not display the new version because it was marked as ignored")
                }
                
                //show details
                if showDetails && visibleRemoteAlert != nil {
                    var title = updateAvailableTitle
                    if !groupNotesByVersion {
                        title = title?.appendingFormat(" (%@)", mostRecentVersion!)
                    }
                    visibleRemoteAlert = showAlertWith(title: title, details: details, defaultButton: downloadButtonLabel, ignoreButton: showIgnoreButton ? ignoreButtonLabel : nil, remindButton: showRemindButton ? remindButtonLabel : nil)
                } else {
                    delegate?.iVersionDidNotDetectNewVersion?()
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
            if localVersionsPlistPath == nil {
                Holder.versionsDict = NSDictionary() //empty dictionary
            } else {
                var versionsFile = URL(fileURLWithPath: (Bundle.main.resourcePath)!).appendingPathComponent(self.localVersionsPlistPath!).absoluteString
                Holder.versionsDict = NSDictionary.init(contentsOfFile: versionsFile)
                if Holder.versionsDict == nil {
                    // Get the path to versions plist in localized directory
                    if let pathComponents = localVersionsPlistPath?.components(separatedBy: ".") {
                        if let s = Bundle.main.path(forResource: pathComponents[0], ofType: pathComponents[1]) {
                            versionsFile = pathComponents.count == 2 ? s : ""
                        }
                    }
                    Holder.versionsDict = NSDictionary.init(contentsOfFile: versionsFile)
                }
            }
        }
        return Holder.versionsDict!
    }
    
    override init() {
        showOnFirstLaunch = false
        groupNotesByVersion = false
        //default settings
        updatePriority = iVersionUpdatePriority.iVersionUpdatePriorityDefault
        useAllAvailableLanguages = true
        onlyPromptIfMainWindowIsAvailable = true
        checkAtLaunch = true
        checkPeriod = 0.0
        remindPeriod = 1.0
        
        useUIAlertControllerIfAvailable = true
        useAppStoreDetailsIfNoPlistEntryFound = true
        previewMode = false
        checkingForNewVersion = false
        
        applicationBundleID = "com.charcoaldesign.rainbowblocks-free"
        
        //configure iVersion. These paths are optional - if you don't set
        //them, iVersion will just get the release notes from iTunes directly (if your app is on the store)
        remoteVersionsPlistURL = "http://charcoaldesign.co.uk/iVersion/versions.plist"
        localVersionsPlistPath = "versions.plist"
        
        //get country
        self.appStoreCountry = Locale.current.currencyCode
        if (self.appStoreCountry == "150") {
            self.appStoreCountry = "eu"
            //} else if (self.appStoreCountry?.replacingOccurrences(of: "[A-Za-z]{2}", with: "", options: .regularExpression, range: nil) {
        } else if (self.appStoreCountry == "GI") {
            self.appStoreCountry = "GB"
        }
        
        //application version (use short version preferentially)
        self.applicationVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        /*
        if (self.applicationVersion?.isEmpty) {
            self.applicationVersion = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
        }
        */
        //bundle id
        self.applicationBundleID = Bundle.main.bundleIdentifier!
        
        
        //enable verbose logging in debug mode
        self.verboseLogging = true
        
        
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: Notification.Name.UIApplicationWillEnterForeground, object: nil)
        

        //app launched
        self.performSelector(onMainThread: #selector(applicationLaunched), with: nil, waitUntilDone: false)
        
    }
    
    @objc func applicationLaunched() {
        if checkAtLaunch {
            checkIfNewVersion()
            if shouldCheckForNewVersion() {
                checkForNewVersion()
            }
        } else if self.verboseLogging {
            print("iVersion will not check for updates because the checkAtLaunch option is disabled")
        }
    }
    
    @objc func applicationWillEnterForeground() {
        if UIApplication.shared.applicationState == UIApplicationState.background {
            if checkAtLaunch {
                if shouldCheckForNewVersion() {
                    checkForNewVersion()
                }
            } else if (verboseLogging) {
                print("iVersion will not check for updates because the checkAtLaunch option is disabled")
            }
        }
    }
}


// NSString extensions at line 83 - 93 in iVersion.m

extension String {
    func compareVersion(version: String) -> ComparisonResult {
        return self.compare(version, options: String.CompareOptions.numeric, range: range(of: version), locale: Locale.autoupdatingCurrent)
    }
    
    func compareVerisonDescending(version: String) -> ComparisonResult {
        let r = compareVersion(version: version)
        if r == ComparisonResult.orderedAscending {
            return ComparisonResult.orderedDescending
        } else if r == ComparisonResult.orderedDescending {
            return ComparisonResult.orderedAscending
        } else {
            return r
        }
    }
}

@objc protocol iVersionDelegate : class, NSObjectProtocol {
    @objc optional func iVersionShouldCheckForNewVersion() -> Bool
    @objc optional func iVersionDidNotDetectNewVersion()
    @objc optional func iVersionVersionCheckDidFailWithError(error: Error?)
    @objc optional func iVersionDidDetectNewVersion(version: String?, versionDetails: String?)
    @objc optional func iVersionShouldDisplayNewVersion(version: String?, versionDetails: String?) -> Bool
    @objc optional func iVersionShouldDisplayCurrentVersionDetails(versionDetails: String?) -> Bool
    @objc optional func iVersionUserDidAttemptToDownloadUpdate(version: String?)
    @objc optional func iVersionUserDidRequestReminderForUpdate(version: String?)
    @objc optional func iVersionUserDidIgnoreUpdate(version: String?)
    @objc optional func iVersionShouldOpenAppStore() -> Bool
    @objc optional func iVersionDidPresentStoreKitModal()
    @objc optional func iVersionDidDismissStoreKitModal()
}

