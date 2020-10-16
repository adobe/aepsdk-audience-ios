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

enum AudienceConstants {
    static let EXTENSION_NAME = "com.adobe.module.audience"
    static let FRIENDLY_NAME = "Audience"
    static let EXTENSION_VERSION = "0.0.1"
    static let DATASTORE_NAME = EXTENSION_NAME

    enum SharedStateKeys {
        static let CONFIGURATION = "com.adobe.module.configuration"
        static let IDENTITY = "com.adobe.module.identity"
        static let LIFECYCLE = "com.adobe.module.lifecycle"
    }

    enum EventDataKeys {
        static let VISITOR_TRAITS       = "aam.traits"
        static let VISITOR_PROFILE      = "aam.profile"
        static let DPID                 = "dpid"
        static let DPUUID               = "dpuuid"
        static let UUID                 = "uuid"
        static let AUDIENCE_IDS         = "audience.ids"
        static let OPTED_OUT_HIT_SENT   = "optedout.hit.sent"
    }

    enum DataStoreKeys {
        static let AUDIENCE_MANAGER_SHARED_PREFS_DATA_STORE = "AAMDataStore"
        static let AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY = "AAMUserProfile"
        static let AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY = "AAMUserId"

    }

    enum DestinationKeys {
        static let AUDIENCE_MANAGER_DATA_PROVIDER_ID_KEY          = "d_dpid"
        static let AUDIENCE_MANAGER_DATA_PROVIDER_USER_ID_KEY     = "d_dpuuid"
        static let AUDIENCE_MANAGER_USER_ID_KEY                   = "d_uuid"
        static let MARKETING_CLOUD_ORG_ID                         = "d_orgid"
        static let VISITOR_ID_MID_KEY                             = "d_mid"
        static let VISITOR_ID_BLOB_KEY                            = "d_blob"
        static let VISITOR_ID_LOCATION_HINT_KEY                   = "dcs_region"
        static let VISITOR_ID_PARAMETER_KEY_CUSTOMER              = "d_cid_ic"
        static let VISITOR_ID_CID_DELIMITER                       = "%01"
    }

    enum URLKeys {
        static let AUDIENCE_MANAGER_CUSTOMER_DATA_PREFIX = "c_"
        static let AUDIENCE_MANAGER_URL_SUFFIX = "&d_dst=1&d_rtbd=json"
        static let AUDIENCE_MANAGER_URL_PLATFORM_KEY = "&d_ptfm="
        static let AUDIENCE_MANAGER_OPT_OUT_URL_BASE = "https://%s/demoptout.jpg?"
        static let AUDIENCE_MANAGER_OPT_OUT_URL_AAM = "d_uuid=%s"
    }

    enum Default {
        static let TIMEOUT = TimeInterval(2000)
    }

    enum ResponseKeys {
        static let AUDIENCE_MANAGER_JSON_DESTS_KEY                = "dests"
        static let AUDIENCE_MANAGER_JSON_URL_KEY                  = "c"
        static let AUDIENCE_MANAGER_JSON_STUFF_KEY                = "stuff"
        static let AUDIENCE_MANAGER_JSON_USER_ID_KEY              = "uuid"
        static let AUDIENCE_MANAGER_JSON_COOKIE_NAME_KEY          = "cn"
        static let AUDIENCE_MANAGER_JSON_COOKIE_VALUE_KEY         = "cv"
    }

    enum ContextDataKeys {
        static let ADVERTISING_IDENTIFIER    = "a.adid"
        static let APPLICATION_IDENTIFIER    = "a.AppID"
        static let CARRIER_NAME              = "a.CarrierName"
        static let CRASH_EVENT_KEY           = "a.CrashEvent"
        static let DAILY_ENGAGED_EVENT_KEY   = "a.DailyEngUserEvent"
        static let DAY_OF_WEEK               = "a.DayOfWeek"
        static let DAYS_SINCE_FIRST_LAUNCH   = "a.DaysSinceFirstUse"
        static let DAYS_SINCE_LAST_LAUNCH    = "a.DaysSinceLastUse"
        static let DAYS_SINCE_LAST_UPGRADE   = "a.DaysSinceLastUpgrade"
        static let DEVICE_NAME               = "a.DeviceName"
        static let DEVICE_RESOLUTION         = "a.Resolution"
        static let HOUR_OF_DAY               = "a.HourOfDay"
        static let IGNORED_SESSION_LENGTH    = "a.ignoredSessionLength"
        static let INSTALL_DATE              = "a.InstallDate"
        static let INSTALL_EVENT_KEY         = "a.InstallEvent"
        static let LAUNCH_EVENT_KEY          = "a.LaunchEvent"
        static let LAUNCHES                  = "a.Launches"
        static let LAUNCHES_SINCE_UPGRADE    = "a.LaunchesSinceUpgrade"
        static let LOCALE                    = "a.locale"
        static let MONTHLY_ENGAGED_EVENT_KEY = "a.MonthlyEngUserEvent"
        static let OPERATING_SYSTEM          = "a.OSVersion"
        static let PREVIOUS_SESSION_LENGTH   = "a.PrevSessionLength"
        static let RUN_MODE                  = "a.RunMode"
        static let TIME_SINCE_LAUNCH_KEY     = "a.TimeSinceLaunch"
        static let UPGRADE_EVENT_KEY         = "a.UpgradeEvent"
    }

    enum Configuration {
        static let EXPERIENCE_CLOUD_ORGID = "experienceCloud.org"
        static let GLOBAL_CONFIG_PRIVACY = "global.privacy"
        static let AAM_SERVER = "audience.server"
        static let AAM_TIMEOUT = "audience.timeout"
        static let ANALYTICS_AAM_FORWARDING = "analytics.aamForwardingEnabled"
    }

    enum Analytics {
        static let SERVER_RESPONSE = "analyticsserverresponse"
    }

    enum Identity {
        static let ADVERTISING_IDENTIFIER = "advertisingidentifier"
        static let VISITOR_ID_MID = "mid"
        static let VISITOR_ID_BLOB = "blob"
        static let VISITOR_ID_LOCATION_HINT = "locationhint"
        static let VISITOR_IDS_LIST = "visitoridslist"
    }

    enum Lifecycle {
        static let ADDITIONAL_CONTEXT_DATA = "additionalcontextdata"
        static let APP_ID                  = "appid"
        static let CARRIER_NAME            = "carriername"
        static let CRASH_EVENT             = "crashevent"
        static let DAILY_ENGAGED_EVENT     = "dailyenguserevent"
        static let DAY_OF_WEEK             = "dayofweek"
        static let DAYS_SINCE_FIRST_LAUNCH = "dayssincefirstuse"
        static let DAYS_SINCE_LAST_LAUNCH  = "dayssincelastuse"
        static let DAYS_SINCE_LAST_UPGRADE = "dayssincelastupgrade"
        static let DEVICE_NAME             = "devicename"
        static let DEVICE_RESOLUTION       = "resolution"
        static let HOUR_OF_DAY             = "hourofday"
        static let IGNORED_SESSION_LENGTH  = "ignoredsessionlength"
        static let INSTALL_DATE            = "installdate"
        static let INSTALL_EVENT           = "installevent"
        static let LAUNCH_EVENT            = "launchevent"
        static let LAUNCHES                = "launches"
        static let LAUNCHES_SINCE_UPGRADE  = "launchessinceupgrade"
        static let LIFECYCLE_CONTEXT_DATA  = "lifecyclecontextdata"
        static let LIFECYCLE_PAUSE         = "pause"
        static let LIFECYCLE_START         = "start"
        static let LOCALE                  = "locale"
        static let MAX_SESSION_LENGTH      = "maxsessionlength"
        static let MONTHLY_ENGAGED_EVENT   = "monthlyenguserevent"
        static let OPERATING_SYSTEM        = "osversion"
        static let PREVIOUS_SESSION_LENGTH = "prevsessionlength"
        static let PREVIOUS_SESSION_PAUSE_TIMESTAMP = "previoussessionpausetimestampseconds"
        static let PREVIOUS_SESSION_START_TIMESTAMP = "previoussessionstarttimestampseconds"
        static let RUN_MODE                = "runmode"
        static let SESSION_EVENT           = "sessionevent"
        static let SESSION_START_TIMESTAMP = "starttimestampseconds"
        static let UPGRADE_EVENT           = "upgradeevent"
    }

    enum RulesEnging {
        static let RULES_REQUEST_CONTENT_AUDIENCE_MANAGER_DATA = "audiencemanagerdata"
    }

    static let MapToContextDataKeys = [
        Identity.ADVERTISING_IDENTIFIER: ContextDataKeys.ADVERTISING_IDENTIFIER,
        Lifecycle.APP_ID: ContextDataKeys.APPLICATION_IDENTIFIER,
        Lifecycle.CARRIER_NAME: ContextDataKeys.CARRIER_NAME,
        Lifecycle.CRASH_EVENT: ContextDataKeys.CRASH_EVENT_KEY,
        Lifecycle.DAILY_ENGAGED_EVENT: ContextDataKeys.DAILY_ENGAGED_EVENT_KEY,
        Lifecycle.DAY_OF_WEEK: ContextDataKeys.DAY_OF_WEEK,
        Lifecycle.DAYS_SINCE_FIRST_LAUNCH: ContextDataKeys.DAYS_SINCE_LAST_LAUNCH,
        Lifecycle.DAYS_SINCE_LAST_LAUNCH: ContextDataKeys.DAYS_SINCE_LAST_LAUNCH,
        Lifecycle.DAYS_SINCE_LAST_UPGRADE: ContextDataKeys.DAYS_SINCE_LAST_UPGRADE,
        Lifecycle.DEVICE_NAME: ContextDataKeys.DEVICE_NAME,
        Lifecycle.DEVICE_RESOLUTION: ContextDataKeys.DEVICE_RESOLUTION,
        Lifecycle.HOUR_OF_DAY: ContextDataKeys.HOUR_OF_DAY,
        Lifecycle.IGNORED_SESSION_LENGTH: ContextDataKeys.IGNORED_SESSION_LENGTH,
        Lifecycle.INSTALL_DATE: ContextDataKeys.INSTALL_DATE,
        Lifecycle.INSTALL_EVENT: ContextDataKeys.INSTALL_EVENT_KEY,
        Lifecycle.LAUNCH_EVENT: ContextDataKeys.LAUNCH_EVENT_KEY,
        Lifecycle.LAUNCHES: ContextDataKeys.LAUNCHES,
        Lifecycle.LAUNCHES_SINCE_UPGRADE: ContextDataKeys.LAUNCHES_SINCE_UPGRADE,
        Lifecycle.LOCALE: ContextDataKeys.LOCALE,
        Lifecycle.MONTHLY_ENGAGED_EVENT: ContextDataKeys.MONTHLY_ENGAGED_EVENT_KEY,
        Lifecycle.OPERATING_SYSTEM: ContextDataKeys.OPERATING_SYSTEM,
        Lifecycle.PREVIOUS_SESSION_LENGTH: ContextDataKeys.PREVIOUS_SESSION_LENGTH,
        Lifecycle.RUN_MODE: ContextDataKeys.RUN_MODE,
        Lifecycle.UPGRADE_EVENT: ContextDataKeys.UPGRADE_EVENT_KEY
    ]
}
