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
    var checkPeriod: Float
    var remindPeriod: Float
    
    //message text - you may wish to customise these
    lazy var inThisVersionTitle = self.localizedString(key: iVersionInThisVersionTitleKey, defaultString: "New in this version")

    var updateAvailableTitle: String? {
        get {
            return self.localizedString(key: iVersionUpdateAvailableTitleKey, withDefault: "New version available")
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
            // TODO
            return true
        }
    }
    
    private var showRemindButton : Bool {
        get {
            return true
        }
    }
    
    //manually control behaviour
    func openAppPageInAppStore() -> Bool {
        if self.updateURL == nil && self.appStoreID == nil {
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
            //if delegate.respondsToSele {
            //    delegate?.iVersionDidPresentStoreKitModal()
            //}
        }
        return true
    }
    
    func checkIfNewVersion() {
        if lastVersion == nil || showOnFirstLaunch || previewMode {
            if (true) { // TODO: String compare
                lastReminded = nil
                var showDetails = versionDetails != nil
                if showDetails && false { // TODO: iVersionShouldDisplayCurrentVersionDetails selector
                    //showDetails = delegate?.iVersionShouldDisplayCurrentVersionDetails(versionDetails: versionDetails)
                }
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
        if self.showIgnoreButton {
            let ignoreAction = UIAlertAction(title: ignoreButtonLabel, style: UIAlertActionStyle.default, handler: { UIAlertAction in
                self.didDismissAlert(alertView: alert, buttonIndex: 1)
            })
            alert.addAction(ignoreAction)
        }
        if self.showRemindButton {
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
            // TODO: delegate methods
            openAppPageInAppStore()
        }
    }
    
    func shouldCheckForNewVersion() -> Bool {
        // TODO
        return false
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
    
    private func mostRecentVersionInDict(dict: NSDictionary?) -> String {
        return "TODO"
        //(dict.allKeys as NSArray).sortedArray(using: #selector(compareVersion)).last!
    }
    
    private func versionDetailsInDict(version: String, dict: NSDictionary) -> String {
        let versionData = dict[version]
        if versionData is String {
            return versionData! as! String
        } else if versionData is [Any] {
            return (versionData as! NSArray).componentsJoined(by: "\n")
        }
        return "TODO"
    }
    
    private func versionDetailsSince(lastVersion: String, dict: NSDictionary) -> String? {
        var lastVersion = lastVersion
        if self.previewMode {
            lastVersion = "0"
        }
        var newVersionFound = false
        var details = String()
        //var versions: [Any] = (dict.keys as NSArray).sortedArray(using: #selector(self.compareVersionDescending))
        let versions = dict.allKeys
        for version in versions {
            let v = version as! String
            if v.compare(lastVersion) == .orderedDescending {
                newVersionFound = true
                if groupNotesByVersion {
                    details += (versionLabelFormat?.replacingOccurrences(of: "%@", with: v))!
                    details += "\n\n"
                }
                details += versionDetailsInDict(version: v, dict: dict)
                details += "\n"
                if groupNotesByVersion {
                    details += "\n"
                }
            }
        }
        return newVersionFound ? details.trimmingCharacters(in: CharacterSet.newlines) : nil
    }
    
    
    // private properties
    private var remoteVersionsDict: NSDictionary?
    private var downloadError: Error?
    private var versionDetails: String? {
        get {
            /*
            if (self.viewedVersionDetails) {
                return self.versionDetailsInDict(version: self.applicationVersion, dict: self.localVersionsDict())
            } else {
                return self.versionDetails(since: self.lastVersion, inDict: self.localVersionsDict())
            }
 */
            return "TODO"
        }
    }
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
// MARK: - TODO
        /*
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
 */
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
                if Holder.versionsDict == nil {
                    // Get the path to versions plist in localized directory
// TODO
                    /*
                    var pathComponents: [Any] = self.localVersionsPlistPath.components(separatedBy: ".")
                    versionsFile = (pathComponents.count == 2) ? Bundle.main.path(forResource: pathComponents[0], ofType: pathComponents[1]) : nil
                    Holder.versionsDict = [AnyHashable: Any](contentsOfFile: versionsFile)
 */
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
        self.applicationVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
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
    func compareVersion(version: String) -> ComparisonResult {
        //TODO: return self.compare(version: version, options: NSNumbericSearch)
        return ComparisonResult.orderedSame
    }
    
    func compareVerisonDescending(version: String) -> ComparisonResult {
        //TODO
        return ComparisonResult.orderedSame
    }
}

// Need to add @objc optional?
protocol iVersionDelegate : class {
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

