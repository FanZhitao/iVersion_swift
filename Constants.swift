//
//  Constants.swift
//  iVersion
//
//  Created by Zhitao Fan on 1/26/17.
//  Copyright © 2017 Mobileware. All rights reserved.
//

import Foundation

// constants and lets at line 55 - 80 in iVersion.m

let iVersionErrorDomain = "iVersionErrorDomain"

let iVersionInThisVersionTitleKey = "iVersionInThisVersionTitle"
let iVersionUpdateAvailableTitleKey = "iVersionUpdateAvailableTitle"
let iVersionVersionLabelFormatKey = "iVersionVersionLabelFormat"
let iVersionOKButtonKey = "iVersionOKButton"
let iVersionIgnoreButtonKey = "iVersionIgnoreButton"
let iVersionRemindButtonKey = "iVersionRemindButton"
let iVersionDownloadButtonKey = "iVersionDownloadButton"

let iVersionAppStoreIDKey = "iVersionAppStoreID"
let iVersionLastVersionKey = "iVersionLastVersionChecked"
let iVersionIgnoreVersionKey = "iVersionIgnoreVersion"
let iVersionLastCheckedKey = "iVersionLastChecked"
let iVersionLastRemindedKey = "iVersionLastReminded"

let iVersionMacAppStoreBundleID = "com.apple.appstore"
let iVersionAppLookupURLFormat = "https://itunes.apple.com/%/lookup"

let iVersioniOSAppStoreURLFormat = "itms-apps://itunes.apple.com/app/id%"
let iVersionMacAppStoreURLFormat = "macappstore://itunes.apple.com/app/id%"


let SECONDS_IN_A_DAY = 86400.0
let MAC_APP_STORE_REFRESH_DELAY = 5.0
let REQUEST_TIMEOUT = 60.0


enum iVersionErrorCode: Int {
    case iVersionErrorBundleIdDoesNotMatchAppStore = 1,
    iVersionErrorApplicationNotFoundOnAppStore,
    iVersionErrorOSVersionNotSupported
}

enum iVersionUpdatePriority: Int {
    case iVersionUpdatePriorityDefault = 0,
    iVersionUpdatePriorityLow = 1,
    iVersionUpdatePriorityMedium = 2,
    iVersionUpdatePriorityHigh = 3
}
