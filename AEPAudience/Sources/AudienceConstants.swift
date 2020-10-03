
/*
 Copyright 2020 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License")
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import Foundation

/// Constants for `Audience Manager`
enum AudienceConstants {

    /// general strings
    static let EXTENSION_NAME = "com.adobe.module.audience"
    static let FRIENDLY_NAME = "Audience Manager"
    static let EXTENSION_VERSION = "0.0.1"
    static let DATA_STORE_NAME = AudienceConstants.EXTENSION_NAME
    static let LOG_TAG = "Audience Manager"

    /// destination variable keys
    static let AUDIENCE_MANAGER_DATA_PROVIDER_ID_KEY          = "d_dpid"
    static let AUDIENCE_MANAGER_DATA_PROVIDER_USER_ID_KEY     = "d_dpuuid"
    static let AUDIENCE_MANAGER_USER_ID_KEY                   = "d_uuid"
    static let MARKETING_CLOUD_ORG_ID                         = "d_orgid"
    static let VISITOR_ID_MID_KEY                             = "d_mid"
    static let VISITOR_ID_BLOB_KEY                            = "d_blob"
    static let VISITOR_ID_LOCATION_HINT_KEY                   = "dcs_region"
    static let VISITOR_ID_PARAMETER_KEY_CUSTOMER              = "d_cid_ic"
    static let VISITOR_ID_CID_DELIMITER                       = "%01"

    /// url stitching
    static let AUDIENCE_MANAGER_CUSTOMER_DATA_PREFIX          = "c_"
    static let AUDIENCE_MANAGER_URL_SUFFIX                    = "&d_dst=1&d_rtbd=json"
    static let AUDIENCE_MANAGER_URL_PLATFORM_KEY              = "&d_ptfm="

    /// persistent storage
    static let AUDIENCE_MANAGER_SHARED_PREFS_DATA_STORE       = "AAMDataStore"
    static let AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY      = "AAMUserProfile"
    static let AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY      = "AAMUserId"

    /// json response keys
    static let AUDIENCE_MANAGER_JSON_DESTS_KEY                = "dests"
    static let AUDIENCE_MANAGER_JSON_URL_KEY                  = "c"
    static let AUDIENCE_MANAGER_JSON_STUFF_KEY                = "stuff"
    static let AUDIENCE_MANAGER_JSON_USER_ID_KEY              = "uuid"
    static let AUDIENCE_MANAGER_JSON_COOKIE_NAME_KEY          = "cn"
    static let AUDIENCE_MANAGER_JSON_COOKIE_VALUE_KEY         = "cv"

    /// config defaults
    static let DEFAULT_AAM_TIMEOUT                            = 2

    /// opt-out end-points
    static let AUDIENCE_MANAGER_OPT_OUT_URL_BASE              = "https://%s/demoptout.jpg?"
    static let AUDIENCE_MANAGER_OPT_OUT_URL_AAM               = "d_uuid=%s"

    /// context data keys
    static let CONTEXT_DATA_KEY_ADVERTISING_IDENTIFIER    = "a.adid"
    static let CONTEXT_DATA_KEY_APPLICATION_IDENTIFIER    = "a.AppID"
    static let CONTEXT_DATA_KEY_CARRIER_NAME              = "a.CarrierName"
    static let CONTEXT_DATA_KEY_CRASH_EVENT_KEY           = "a.CrashEvent"
    static let CONTEXT_DATA_KEY_DAILY_ENGAGED_EVENT_KEY   = "a.DailyEngUserEvent"
    static let CONTEXT_DATA_KEY_DAY_OF_WEEK               = "a.DayOfWeek"
    static let CONTEXT_DATA_KEY_DAYS_SINCE_FIRST_LAUNCH   = "a.DaysSinceFirstUse"
    static let CONTEXT_DATA_KEY_DAYS_SINCE_LAST_LAUNCH    = "a.DaysSinceLastUse"
    static let CONTEXT_DATA_KEY_DAYS_SINCE_LAST_UPGRADE   = "a.DaysSinceLastUpgrade"
    static let CONTEXT_DATA_KEY_DEVICE_NAME               = "a.DeviceName"
    static let CONTEXT_DATA_KEY_DEVICE_RESOLUTION         = "a.Resolution"
    static let CONTEXT_DATA_KEY_HOUR_OF_DAY               = "a.HourOfDay"
    static let CONTEXT_DATA_KEY_IGNORED_SESSION_LENGTH    = "a.ignoredSessionLength"
    static let CONTEXT_DATA_KEY_INSTALL_DATE              = "a.InstallDate"
    static let CONTEXT_DATA_KEY_INSTALL_EVENT_KEY         = "a.InstallEvent"
    static let CONTEXT_DATA_KEY_LAUNCH_EVENT_KEY          = "a.LaunchEvent"
    static let CONTEXT_DATA_KEY_LAUNCHES                  = "a.Launches"
    static let CONTEXT_DATA_KEY_LAUNCHES_SINCE_UPGRADE    = "a.LaunchesSinceUpgrade"
    static let CONTEXT_DATA_KEY_LOCALE                    = "a.locale"
    static let CONTEXT_DATA_KEY_MONTHLY_ENGAGED_EVENT_KEY = "a.MonthlyEngUserEvent"
    static let CONTEXT_DATA_KEY_OPERATING_SYSTEM          = "a.OSVersion"
    static let CONTEXT_DATA_KEY_PREVIOUS_SESSION_LENGTH   = "a.PrevSessionLength"
    static let CONTEXT_DATA_KEY_RUN_MODE                  = "a.RunMode"
    static let CONTEXT_DATA_KEY_TIME_SINCE_LAUNCH_KEY     = "a.TimeSinceLaunch"
    static let CONTEXT_DATA_KEY_UPGRADE_EVENT_KEY         = "a.UpgradeEvent"

    /// event data keys
    static let EVENT_DATA_KEY_AUDIENCE_STATE_OWNER          = "stateowner"
    static let EVENT_DATA_KEY_AUDIENCE_SHARED_STATE_NAME    = "com.adobe.module.audience"
    static let EVENT_DATA_KEY_AUDIENCE_VISITOR_TRAITS       = "aamtraits"
    static let EVENT_DATA_KEY_AUDIENCE_VISITOR_PROFILE      = "aamprofile"
    static let EVENT_DATA_KEY_AUDIENCE_DPID                 = "dpid"
    static let EVENT_DATA_KEY_AUDIENCE_DPUUID               = "dpuuid"
    static let EVENT_DATA_KEY_AUDIENCE_UUID                 = "uuid"
    static let EVENT_DATA_KEY_AUDIENCE_AUDIENCE_IDS         = "audienceids"
    static let EVENT_DATA_KEY_AUDIENCE_OPTED_OUT_HIT_SENT   = "optedouthitsent"

    static let EVENT_DATA_KEY_ANALYTICS_SERVER_RESPONSE = "analyticsserverresponse"

    static let EVENT_DATA_KEY_CONFIGURATION_SHARED_STATE_NAME =
        "com.adobe.module.configuration"
    static let EVENT_DATA_KEY_CONFIGURATION_GLOBAL_PRIVACY   = "global.privacy"
    static let EVENT_DATA_KEY_CONFIGURATION_AAM_SERVER       = "audience.server"
    static let EVENT_DATA_KEY_CONFIGURATION_AAM_TIMEOUT      = "audience.timeout"
    static let EVENT_DATA_KEY_CONFIGURATION_ANALYTICS_AAM_FORWARDING    =
        "analytics.aamForwardingEnabled"
    static let EVENT_DATA_KEY_CONFIGURATION_EXPERIENCE_CLOUD_ORGID    =
        "experienceCloud.org"

    static let EVENT_DATA_KEY_IDENTITY_SHARED_STATE_NAME           = "com.adobe.module.identity"
    static let EVENT_DATA_KEY_IDENTITY_ADVERTISING_IDENTIFIER      = "advertisingidentifier"
    static let EVENT_DATA_KEY_IDENTITY_VISITOR_ID_MID              = "mid"
    static let EVENT_DATA_KEY_IDENTITY_VISITOR_ID_BLOB             = "blob"
    static let EVENT_DATA_KEY_IDENTITY_VISITOR_ID_LOCATION_HINT    = "locationhint"
    static let EVENT_DATA_KEY_IDENTITY_VISITOR_IDS_LIST            = "visitoridslist"

    static let EVENT_DATA_KEY_LIFECYCLE_SHARED_STATE_NAME = "com.adobe.module.lifecycle"
    static let EVENT_DATA_KEY_LIFECYCLE_ADDITIONAL_CONTEXT_DATA = "additionalcontextdata"
    static let EVENT_DATA_KEY_LIFECYCLE_APP_ID                  = "appid"
    static let EVENT_DATA_KEY_LIFECYCLE_CARRIER_NAME            = "carriername"
    static let EVENT_DATA_KEY_LIFECYCLE_CRASH_EVENT             = "crashevent"
    static let EVENT_DATA_KEY_LIFECYCLE_DAILY_ENGAGED_EVENT     = "dailyenguserevent"
    static let EVENT_DATA_KEY_LIFECYCLE_DAY_OF_WEEK             = "dayofweek"
    static let EVENT_DATA_KEY_LIFECYCLE_DAYS_SINCE_FIRST_LAUNCH = "dayssincefirstuse"
    static let EVENT_DATA_KEY_LIFECYCLE_DAYS_SINCE_LAST_LAUNCH  = "dayssincelastuse"
    static let EVENT_DATA_KEY_LIFECYCLE_DAYS_SINCE_LAST_UPGRADE = "dayssincelastupgrade"
    static let EVENT_DATA_KEY_LIFECYCLE_DEVICE_NAME             = "devicename"
    static let EVENT_DATA_KEY_LIFECYCLE_DEVICE_RESOLUTION       = "resolution"
    static let EVENT_DATA_KEY_LIFECYCLE_HOUR_OF_DAY             = "hourofday"
    static let EVENT_DATA_KEY_LIFECYCLE_IGNORED_SESSION_LENGTH  = "ignoredsessionlength"
    static let EVENT_DATA_KEY_LIFECYCLE_INSTALL_DATE            = "installdate"
    static let EVENT_DATA_KEY_LIFECYCLE_INSTALL_EVENT           = "installevent"
    static let EVENT_DATA_KEY_LIFECYCLE_LAUNCH_EVENT            = "launchevent"
    static let EVENT_DATA_KEY_LIFECYCLE_LAUNCHES                = "launches"
    static let EVENT_DATA_KEY_LIFECYCLE_LAUNCHES_SINCE_UPGRADE  = "launchessinceupgrade"
    static let EVENT_DATA_KEY_LIFECYCLE_LIFECYCLE_CONTEXT_DATA  = "lifecyclecontextdata"
    static let EVENT_DATA_KEY_LIFECYCLE_LIFECYCLE_PAUSE         = "pause"
    static let EVENT_DATA_KEY_LIFECYCLE_LIFECYCLE_START         = "start"
    static let EVENT_DATA_KEY_LIFECYCLE_LOCALE                  = "locale"
    static let EVENT_DATA_KEY_LIFECYCLE_MAX_SESSION_LENGTH      = "maxsessionlength"
    static let EVENT_DATA_KEY_LIFECYCLE_MONTHLY_ENGAGED_EVENT   = "monthlyenguserevent"
    static let EVENT_DATA_KEY_LIFECYCLE_OPERATING_SYSTEM        = "osversion"
    static let EVENT_DATA_KEY_LIFECYCLE_PREVIOUS_SESSION_LENGTH = "prevsessionlength"
    static let EVENT_DATA_KEY_LIFECYCLE_PREVIOUS_SESSION_PAUSE_TIMESTAMP =
        "previoussessionpausetimestampseconds"
    static let EVENT_DATA_KEY_LIFECYCLE_PREVIOUS_SESSION_START_TIMESTAMP =
        "previoussessionstarttimestampseconds"
    static let EVENT_DATA_KEY_LIFECYCLE_RUN_MODE                = "runmode"
    static let EVENT_DATA_KEY_LIFECYCLE_SESSION_EVENT           = "sessionevent"
    static let EVENT_DATA_KEY_LIFECYCLE_SESSION_START_TIMESTAMP = "starttimestampseconds"
    static let EVENT_DATA_KEY_LIFECYCLE_UPGRADE_EVENT           = "upgradeevent"

    static let EVENT_DATA_KEY_RULES_ENGINE_RULES_REQUEST_CONTENT_AUDIENCE_MANAGER_DATA =
        "audiencemanagerdata"

    /// Dictionary to help go from lifecycle to context data
    static let MAP_TO_CONTEXT_DATA_KEYS =
        [EVENT_DATA_KEY_IDENTITY_ADVERTISING_IDENTIFIER : CONTEXT_DATA_KEY_ADVERTISING_IDENTIFIER,
         EVENT_DATA_KEY_LIFECYCLE_APP_ID : CONTEXT_DATA_KEY_APPLICATION_IDENTIFIER,
         EVENT_DATA_KEY_LIFECYCLE_CARRIER_NAME : CONTEXT_DATA_KEY_CARRIER_NAME,
         EVENT_DATA_KEY_LIFECYCLE_CRASH_EVENT : CONTEXT_DATA_KEY_CRASH_EVENT_KEY,
         EVENT_DATA_KEY_LIFECYCLE_DAILY_ENGAGED_EVENT : CONTEXT_DATA_KEY_DAILY_ENGAGED_EVENT_KEY,
         EVENT_DATA_KEY_LIFECYCLE_DAY_OF_WEEK : CONTEXT_DATA_KEY_DAY_OF_WEEK,
         EVENT_DATA_KEY_LIFECYCLE_DAYS_SINCE_FIRST_LAUNCH : CONTEXT_DATA_KEY_DAYS_SINCE_FIRST_LAUNCH,
         EVENT_DATA_KEY_LIFECYCLE_DAYS_SINCE_LAST_LAUNCH : CONTEXT_DATA_KEY_DAYS_SINCE_LAST_LAUNCH,
         EVENT_DATA_KEY_LIFECYCLE_DAYS_SINCE_LAST_UPGRADE : CONTEXT_DATA_KEY_DAYS_SINCE_LAST_UPGRADE,
         EVENT_DATA_KEY_LIFECYCLE_DEVICE_NAME : CONTEXT_DATA_KEY_DEVICE_NAME,
         EVENT_DATA_KEY_LIFECYCLE_DEVICE_RESOLUTION : CONTEXT_DATA_KEY_DEVICE_RESOLUTION,
         EVENT_DATA_KEY_LIFECYCLE_HOUR_OF_DAY : CONTEXT_DATA_KEY_HOUR_OF_DAY,
         EVENT_DATA_KEY_LIFECYCLE_IGNORED_SESSION_LENGTH : CONTEXT_DATA_KEY_IGNORED_SESSION_LENGTH,
         EVENT_DATA_KEY_LIFECYCLE_INSTALL_DATE : CONTEXT_DATA_KEY_INSTALL_DATE,
         EVENT_DATA_KEY_LIFECYCLE_INSTALL_EVENT : CONTEXT_DATA_KEY_INSTALL_EVENT_KEY,
         EVENT_DATA_KEY_LIFECYCLE_LAUNCH_EVENT : CONTEXT_DATA_KEY_LAUNCH_EVENT_KEY,
         EVENT_DATA_KEY_LIFECYCLE_LAUNCHES : CONTEXT_DATA_KEY_LAUNCHES,
         EVENT_DATA_KEY_LIFECYCLE_LAUNCHES_SINCE_UPGRADE : CONTEXT_DATA_KEY_LAUNCHES_SINCE_UPGRADE,
         EVENT_DATA_KEY_LIFECYCLE_LOCALE : CONTEXT_DATA_KEY_LOCALE,
         EVENT_DATA_KEY_LIFECYCLE_MONTHLY_ENGAGED_EVENT : CONTEXT_DATA_KEY_MONTHLY_ENGAGED_EVENT_KEY,
         EVENT_DATA_KEY_LIFECYCLE_OPERATING_SYSTEM : CONTEXT_DATA_KEY_OPERATING_SYSTEM,
         EVENT_DATA_KEY_LIFECYCLE_PREVIOUS_SESSION_LENGTH : CONTEXT_DATA_KEY_PREVIOUS_SESSION_LENGTH,
         EVENT_DATA_KEY_LIFECYCLE_RUN_MODE : CONTEXT_DATA_KEY_RUN_MODE,
         EVENT_DATA_KEY_LIFECYCLE_UPGRADE_EVENT : CONTEXT_DATA_KEY_UPGRADE_EVENT_KEY]
}
