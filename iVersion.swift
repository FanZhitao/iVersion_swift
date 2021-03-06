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
    static let shared = iVersion()
    
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
    lazy var applicationBundleID = {
        return Bundle.main.bundleIdentifier
    }()
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
    lazy var updateURL : URL? = {
        return URL(string: String(format: iVersioniOSAppStoreURLFormat, self.appStoreID!))
    }()
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
            return !((ignoreButtonLabel?.isEmpty)!) && updatePriority.rawValue < iVersionUpdatePriority.medium.rawValue
        }
    }
    
    private var showRemindButton : Bool {
        get {
            return !((remindButtonLabel?.isEmpty)!) && updatePriority.rawValue < iVersionUpdatePriority.high.rawValue
        }
    }
    
    //manually control behaviour
    func openAppPageInAppStore() -> Bool {
        if updateURL == nil && appStoreID == nil {
            print("iVersion was unable to open the App Store because the app store ID is not set.")
            return false
        }
        
        let productController = SKStoreProductViewController()
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
        if lastVersion != nil || showOnFirstLaunch || previewMode {
            if applicationVersion?.compare(lastVersion ?? "", options: .numeric) == .orderedDescending || previewMode {
                lastReminded = nil
                var showDetails = versionDetails != nil
                if showDetails {
                    if let s = delegate?.iVersionShouldDisplayCurrentVersionDetails?(versionDetails: versionDetails) {
                        showDetails = s
                    }
                }
                if showDetails && visibleLocalAlert == nil && visibleRemoteAlert == nil {
                    visibleLocalAlert = showAlertWith(title: inThisVersionTitle, details: versionDetails, defaultButton: okButtonLabel, ignoreButton: nil, remindButton: nil)
                }
            }
        } else {
            viewedVersionDetails = true
        }
    }
    
    private func showAlertWith(title: String?, details: String?, defaultButton: String?, ignoreButton: String?, remindButton: String?) -> AnyObject {
        var topController = UIApplication.shared.delegate?.window??.rootViewController
        while topController?.presentedViewController != nil {
            topController = topController?.presentedViewController
        }
        let alert = UIAlertController(title: title, message: details, preferredStyle: UIAlertControllerStyle.alert)
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
            if delegate?.iVersionShouldOpenAppStore?() != true {
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
        
        if let shouldCheck = delegate?.iVersionShouldCheckForNewVersion?() {
            if verboseLogging {
                print("iVersion did not check for a new version because the iVersionShouldCheckForNewVersion delegate method returned NO")
            }
            return shouldCheck
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
        objc_sync_enter(self)
        var newerVersionAvaiable = false
        //let osVersionSupported = false
        var latestVersion : String?
        var versions = [String: AnyObject]()
        
        var iTunesServiceURL = String(format: iVersionAppLookupURLFormat, appStoreCountry!)
        if let a = appStoreID {
            iTunesServiceURL = iTunesServiceURL.appendingFormat("?id=%d", a)
        } else {
            iTunesServiceURL = iTunesServiceURL.appendingFormat("?bundleId=%@", applicationBundleID!)
        }
        
        if verboseLogging {
            print(String(format: "iVersion is checking %@ for a new app version...", iTunesServiceURL))
        }
        
        let url = URL(string: iTunesServiceURL)
        //let request = URLRequest(url: url!, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: REQUEST_TIMEOUT)
        
        let task = URLSession.shared.dataTask(with: url!) { (data, response, error) in
            var statusCode = 0
            if let httpResponse = response as? HTTPURLResponse {
                statusCode = httpResponse.statusCode
            }
            if data != nil && statusCode == 200 {
                do {
                    //let jsonDict = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions(rawValue: 0)) as! [String: AnyObject]
                    // FIXME: has to use NSDictionary?
                    let jsonDict = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions(rawValue: 0)) as? NSDictionary
                    let json = (jsonDict?["results"] as? NSArray)?.lastObject as? NSDictionary
                    if let bundleID = json?["bundleId"] as? String {
                        if bundleID == self.applicationBundleID {
                            if let minimumSupportedOSVersion = json?["minimumOsVersion"] as? String {
                                let systemVersion = UIDevice.current.systemVersion
                                let osVersionSupported = systemVersion.compare(minimumSupportedOSVersion, options: .numeric) != ComparisonResult.orderedAscending
                                if osVersionSupported != true {
                                    // MARK: FIXME
                                    // error = NSError.errorWithDomain...
                                }
                                
                                let releaseNotes = json?["releaseNotes"] as? String
                                latestVersion = json?["version"] as? String
                                if latestVersion?.isEmpty == false && osVersionSupported {
                                    versions = [latestVersion!: releaseNotes! as AnyObject]
                                }
                                
                                if self.appStoreID == nil {
                                    let appStoreIDString = json?["trackId"] as? String
                                    self.performSelector(onMainThread: #selector(self.setAppStoreIDOnMainThread(appStoreIDString:)), with: appStoreIDString, waitUntilDone: true)
                                    if self.verboseLogging {
                                        print("iVersion found the app on iTunes. The App Store ID is \(appStoreIDString)")
                                    }
                                }
                                
                                newerVersionAvaiable = latestVersion?.compare(self.applicationVersion!, options:.numeric) == .orderedDescending
                                if self.verboseLogging {
                                    if newerVersionAvaiable {
                                        print("iVersion found a new Version (\(latestVersion)) of the app on iTunes. Current version is \(self.applicationVersion)")
                                    } else {
                                        print("iVersion did not find a new version of the app on iTunes. Current version is ")
                                    }
                                }
                            }
                        } else {
                            if self.verboseLogging {
                                print("iVersion found that the application bundle ID \(self.applicationBundleID) does not match the bundle ID of the app found on iTunes (\(bundleID)) with the specified App Store ID \(self.appStoreID)")
                            }
                            // MARK: FIXME
                            // error = ...
                        }
                    } else if (self.appStoreID != nil || !self.remoteVersionsPlistURL.isEmpty) {
                        if self.verboseLogging {
                            print("iVersion will check \(self.remoteVersionsPlistURL) for \(self.appStoreID != nil ? "release notes" : "a new app version")")
                        }
                        let url = URL(string: self.remoteVersionsPlistURL)
                        let task0 = URLSession.shared.dataTask(with: url!, completionHandler: { (data0, response0, error0) in
                            if data0 != nil {
                                do {
                                    var plistVersions = try PropertyListSerialization.propertyList(from: data0!, options: [], format: nil) as? [String: AnyObject]
                                    
                                    if latestVersion != nil {
                                        var versions = [String: AnyObject]()
                                        for version in plistVersions!.keys {
                                            if version.compare(latestVersion!, options: .numeric) != .orderedDescending {
                                                versions[version] = plistVersions![version]
                                            }
                                        }
                                        plistVersions = versions
                                    }
                                    if latestVersion == nil || plistVersions != nil || !self.useAppStoreDetailsIfNoPlistEntryFound {
                                        versions = plistVersions! // copy?
                                    }
                                } catch {
                                    print("plist deserailization error.")
                                }
                            }
                        })
                        task0.resume()
                    }
                } catch {
                    print("json serialization error.")
                }
            }
            self.performSelector(onMainThread: #selector(setter: self.downloadError), with: error, waitUntilDone: true)
            self.performSelector(onMainThread: #selector(setter: self.remoteVersionsDict), with: versions, waitUntilDone: true)
            self.performSelector(onMainThread: #selector(setter: self.lastChecked), with: Date(), waitUntilDone: true)
            self.performSelector(onMainThread: #selector(self.downloadedVersionsData), with: nil, waitUntilDone: true)
        }
        task.resume()
        
        objc_sync_exit(self)
    }
    
    @objc private func setAppStoreIDOnMainThread(appStoreIDString: String) {
        appStoreID = UInt(appStoreIDString)
    }
    /*
    private func value(forKey key: String, inJSON json: AnyObject) -> String? {
        if json is String {
            let json = json as! String
            let keyRange = json.range(of: String.init(format: "\"%@\"", key))
            if keyRange != nil {
                let valueStart = json.range(of: ":", options: String.CompareOptions.init(rawValue: 0), range: Range.init(uncheckedBounds: (lower: keyRange!.upperBound, upper: json.endIndex)))
                if valueStart != nil {
                    var valueEnd = json.range(of: ",", options: String.CompareOptions.init(rawValue: 0), range: Range.init(uncheckedBounds: (lower: json.index(valueStart!.lowerBound, offsetBy: 1), upper: json.endIndex)))
                    if valueEnd != nil {
                        var value = json[json.index(valueStart!.lowerBound, offsetBy: 1) ..< valueEnd!.upperBound]
                        value = value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        while value.hasPrefix("\"") && !value.hasSuffix("\"") {
                            if valueEnd == nil {
                                break;
                            }
                            valueEnd = json.range(of: ",", options: String.CompareOptions.init(rawValue: 0), range: Range.init(uncheckedBounds: (lower: json.index(valueEnd!.lowerBound, offsetBy: 1), upper: json.endIndex)))
                            value = json[json.index(valueStart!.lowerBound, offsetBy: 1) ..< valueEnd!.upperBound]
                            value = value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        }
                        
                        value = value.trimmingCharacters(in: CharacterSet.init(charactersIn: "\""))
                        value = value.replacingOccurrences(of: "\\\\", with: "\\")
                        value = value.replacingOccurrences(of: "\\/", with: "/")
                        value = value.replacingOccurrences(of: "\\\"", with: "\"")
                        value = value.replacingOccurrences(of: "\\n", with: "\n")
                        value = value.replacingOccurrences(of: "\\r", with: "\r")
                        value = value.replacingOccurrences(of: "\\t", with: "\t")
                        value = value.replacingOccurrences(of: "\\f", with: "\u{000C}")
                        value = value.replacingOccurrences(of: "\\b", with: "\u{000C}")
                        
                        while true {
                            let unicode = value.range(of: "\\u")
                            if unicode == nil || unicode!.upperBound == json.startIndex {
                                break
                            }
                            
                            var c : UInt32 = 0
                            let hex = value.substring(with: Range.init(uncheckedBounds: (lower: unicode!.lowerBound, upper: json.index(unicode!.lowerBound, offsetBy: 4))))
                            let scanner = Scanner.init(string: hex)
                            scanner.scanHexInt32(&c)
                            
                            if c <= 0xffff {
                                value = value.replacingCharacters(in: Range.init(uncheckedBounds: (lower: unicode!.lowerBound, upper: json.index(unicode!.lowerBound, offsetBy: 6))), with: String.init(format: "%C", unichar(c)))
                            } else {
                                let x = UInt16(c)
                                let u = UInt16(c >> 16) & UInt16((1 << 5) - 1)
                                let w : UInt16 = u - 1
                                let high : unichar = 0xd800 | (w << 6) | x >> 10
                                let low = UInt16(0xdc00 | (x & ((1 << 10) - 1)))
                                
                                value = value.replacingCharacters(in: Range.init(uncheckedBounds: (lower: unicode!.lowerBound, upper: json.index(unicode!.lowerBound, offsetBy: 6))), with: String.init(format: "%C%C", high, low))
                            }
                        }
                        return value
                    }
                }
            }
        }
        return json[key] as? String
    }
    */
    private func mostRecentVersionInDict(dict: [String: AnyObject]?) -> String? {
         return dict?.keys.sorted(by: {(s0, s1) -> Bool in return s0.localizedStandardCompare(s1) == .orderedAscending}).last
    }
    
    private func versionDetailsInDict(version: String?, dict: [String: AnyObject]?) -> String? {
        if version?.isEmpty == false {
            let versionData = dict?[version!]
            if versionData is String {
                return (versionData as! String)
            } else if versionData is [String] {
                return (versionData as! [String]).joined(separator: "\n")
            }
        }
        return nil
    }
    
    private func versionDetailsSince( lastVersion: String?, dict: [String: AnyObject]?) -> String? {
        var lastVersion = lastVersion ?? ""
        if previewMode {
            lastVersion = "0"
        }
        var newVersionFound = false
        var details = String()
        let versions = dict?.keys.sorted(by: {(s0, s1) -> Bool in return s0.localizedStandardCompare(s1) == .orderedAscending})
        if versions?.isEmpty == false {
            for version in versions! {
                if version.compare(lastVersion) == .orderedDescending {
                    newVersionFound = true
                    if groupNotesByVersion {
                        details += (versionLabelFormat?.replacingOccurrences(of: "%@", with: version))!
                        details += "\n\n"
                    }
                    details += versionDetailsInDict(version: version, dict: dict) ?? ""
                    details += "\n"
                    if groupNotesByVersion {
                        details += "\n"
                    }
                }
            }
        }
        return newVersionFound ? details.trimmingCharacters(in: CharacterSet.newlines) : nil
    }
    
    // private properties
    @objc private var remoteVersionsDict: [String: AnyObject]?
    @objc private var downloadError: Error?
    private lazy var versionDetails: String? = {
        if self.viewedVersionDetails != nil {
            return self.versionDetailsInDict(version: self.applicationVersion, dict:self.localVersionsDict())
        } else {
            return self.versionDetailsSince(lastVersion: self.lastVersion, dict: self.localVersionsDict())
        }
    }()
    private var visibleLocalAlert: AnyObject?
    private var visibleRemoteAlert: AnyObject?
    private var checkingForNewVersion: Bool
    
    @objc private func downloadedVersionsData() {
        if checkingForNewVersion {
            //no longer checking
            checkingForNewVersion = false
            //check if data downloaded
            if remoteVersionsDict?.isEmpty != false {
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
            let details = versionDetailsSince(lastVersion: applicationVersion, dict: remoteVersionsDict)
            let mostRecentVersion = mostRecentVersionInDict(dict: remoteVersionsDict)
            if details?.isEmpty == false {
                //inform delegate of new version
                delegate?.iVersionDidDetectNewVersion?(version: mostRecentVersion, versionDetails: details)

                //check if ignored
                var showDetails = !(ignoredVersion == mostRecentVersion) || previewMode
                if showDetails {
                    showDetails = delegate?.iVersionShouldDisplayNewVersion?(version: mostRecentVersion, versionDetails: details) ?? showDetails
                    if !showDetails && verboseLogging {
                        print("iVersion did not display the new version because the iVersionShouldDisplayNewVersion:details: delegate method returned NO")
                    }
                } else if verboseLogging {
                    print("iVersion did not display the new version because it was marked as ignored")
                }
                
                //show details
                if showDetails && visibleRemoteAlert == nil {
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
    
    private func localVersionsDict() -> [String: AnyObject]? {
        // static var workaround
        // ref: http://stackoverflow.com/questions/25354882/static-function-variables-in-swift
        struct Holder {
            static var versionsDict: [String: AnyObject]?
        }
        if Holder.versionsDict == nil {
            if localVersionsPlistPath == nil {
                Holder.versionsDict = Dictionary()
            } else {
                var versionsFile = URL(fileURLWithPath: (Bundle.main.resourcePath)!).appendingPathComponent(self.localVersionsPlistPath!).absoluteString
                Holder.versionsDict = NSDictionary(contentsOfFile: versionsFile) as? [String: AnyObject]
                if Holder.versionsDict == nil {
                    // Get the path to versions plist in localized directory
                    if let pathComponents = localVersionsPlistPath?.components(separatedBy: ".") {
                        if let s = Bundle.main.path(forResource: pathComponents[0], ofType: pathComponents[1]) {
                            versionsFile = pathComponents.count == 2 ? s : ""
                        }
                    }
                    Holder.versionsDict = NSDictionary(contentsOfFile: versionsFile) as? [String: AnyObject]
                }
            }
        }
        return Holder.versionsDict
    }
    
    override init() {
        showOnFirstLaunch = false
        groupNotesByVersion = false
        //default settings
        updatePriority = .defaultPriority
        useAllAvailableLanguages = true
        onlyPromptIfMainWindowIsAvailable = true
        checkAtLaunch = true
        checkPeriod = 0.0
        remindPeriod = 1.0
        
        useUIAlertControllerIfAvailable = true
        useAppStoreDetailsIfNoPlistEntryFound = true
        previewMode = false
        checkingForNewVersion = false
        
        //get country
        appStoreCountry = Locale.current.regionCode
        if (appStoreCountry == "150") {
            appStoreCountry = "eu"
            //} else if (self.appStoreCountry?.replacingOccurrences(of: "[A-Za-z]{2}", with: "", options: .regularExpression, range: nil) {
        } else if (appStoreCountry == "GI") {
            appStoreCountry = "GB"
        }
        
        //application version (use short version preferentially)
        applicationVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        /*
        if (self.applicationVersion?.isEmpty) {
            self.applicationVersion = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
        }
        */
        
        
        //enable verbose logging in debug mode
        verboseLogging = true
        
        remoteVersionsPlistURL = String()
        
        super.init()
        //bundle id
        applicationBundleID = Bundle.main.bundleIdentifier!

        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: Notification.Name.UIApplicationWillEnterForeground, object: nil)
        

        //app launched
        performSelector(onMainThread: #selector(applicationLaunched), with: nil, waitUntilDone: false)
        
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

