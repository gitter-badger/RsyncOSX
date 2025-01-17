//
//  ViewControllertabSchedule.swift
//  RsyncOSXver30
//
//  Created by Thomas Evensen on 19/08/2016.
//  Copyright © 2016 Thomas Evensen. All rights reserved.
//
//  swiftlint:disable line_length cyclomatic_complexity function_body_length

import Foundation
import Cocoa

protocol SetProfileinfo: class {
    func setprofile(profile: String, color: NSColor)
}

class ViewControllertabSchedule: NSViewController, SetConfigurations, SetSchedules, VcSchedule, Delay, Index, VcExecute {

    private var index: Int?
    private var hiddenID: Int?
    private var schedulessorted: ScheduleSortedAndExpand?
    var schedule: Scheduletype?
    private var preselectrow: Bool = false

    // Main tableview
    @IBOutlet weak var mainTableView: NSTableView!
    @IBOutlet weak var profilInfo: NSTextField!
    @IBOutlet weak var weeklybutton: NSButton!
    @IBOutlet weak var dailybutton: NSButton!
    @IBOutlet weak var oncebutton: NSButton!
    @IBOutlet weak var info: NSTextField!
    @IBOutlet weak var rsyncosxschedbutton: NSButton!
    @IBOutlet weak var menuappisrunning: NSButton!

    @IBAction func totinfo(_ sender: NSButton) {
        guard ViewControllerReference.shared.norsync == false else {
            _ = Norsync()
            return
        }
        self.configurations!.processtermination = .remoteinfotask
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerRemoteInfo!)
        })
    }

    @IBAction func quickbackup(_ sender: NSButton) {
        guard ViewControllerReference.shared.norsync == false else {
            _ = Norsync()
            return
        }
        self.openquickbackup()
    }

    @IBAction func automaticbackup(_ sender: NSButton) {
        self.configurations!.processtermination = .automaticbackup
        self.configurations?.remoteinfotaskworkqueue = RemoteInfoTaskWorkQueue(inbatch: false)
        self.presentAsSheet(self.viewControllerEstimating!)
    }

    @IBAction func rsyncosxsched(_ sender: NSButton) {
        let pathtorsyncosxschedapp: String = ViewControllerReference.shared.pathrsyncosxsched! + ViewControllerReference.shared.namersyncosssched
        NSWorkspace.shared.open(URL(fileURLWithPath: pathtorsyncosxschedapp))
        self.rsyncosxschedbutton.isEnabled = false
        NSApp.terminate(self)
    }

    @IBAction func once(_ sender: NSButton) {
        self.schedule = .once
        self.addschedule()
    }

    @IBAction func daily(_ sender: NSButton) {
        self.schedule = .daily
        self.addschedule()
    }

    @IBAction func weekly(_ sender: NSButton) {
        self.schedule = .weekly
        self.addschedule()
    }

    @IBAction func selectdate(_ sender: NSDatePicker) {
       self.schedulebuttonsonoff()
    }

    @IBAction func selecttime(_ sender: NSDatePicker) {
       self.schedulebuttonsonoff()
    }

    private func addschedule() {
        let question: String = NSLocalizedString("Add Schedule?", comment: "Add schedule")
        let text: String = NSLocalizedString("Cancel or Add", comment: "Add schedule")
        let dialog: String = NSLocalizedString("Add", comment: "Add schedule")
        let answer = Alerts.dialogOrCancel(question: question, text: text, dialog: dialog)
        if answer {
            self.info.stringValue = Infoschedule().info(num: 2)
            let seconds: TimeInterval = self.starttime.dateValue.timeIntervalSinceNow
            let startdate: Date = self.startdate.dateValue.addingTimeInterval(seconds)
            if self.index != nil {
                self.schedules!.addschedule(self.hiddenID!, schedule: self.schedule ?? .once, start: startdate)
            }
        }
    }

    private func schedulebuttonsonoff() {
        let seconds: TimeInterval = self.starttime.dateValue.timeIntervalSinceNow
        // Date and time for stop
        let startime: Date = self.startdate.dateValue.addingTimeInterval(seconds)
        let secondstostart = startime.timeIntervalSinceNow
        if secondstostart < 60 {
            self.weeklybutton.isEnabled = false
            self.dailybutton.isEnabled = false
            self.oncebutton.isEnabled = false
        }
        if secondstostart > 60 {
            self.weeklybutton.isEnabled = true
            self.dailybutton.isEnabled = true
            self.oncebutton.isEnabled = true
        }
    }

    // Selecting profiles
    @IBAction func profiles(_ sender: NSButton) {
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerProfile!)
        })
    }

    // Userconfiguration button
    @IBAction func userconfiguration(_ sender: NSButton) {
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerUserconfiguration!)
        })
    }

    // Logg records
    @IBAction func loggrecords(_ sender: NSButton) {
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerScheduleDetails!)
        })
    }

    @IBOutlet weak var startdate: NSDatePicker!
    @IBOutlet weak var starttime: NSDatePicker!

    // Initial functions viewDidLoad and viewDidAppear
    override func viewDidLoad() {
        super.viewDidLoad()
        self.mainTableView.delegate = self
        self.mainTableView.dataSource = self
        self.mainTableView.doubleAction = #selector(ViewControllertabMain.tableViewDoubleClick(sender:))
        ViewControllerReference.shared.setvcref(viewcontroller: .vctabschedule, nsviewcontroller: self)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        ViewControllerReference.shared.activetab = .vctabschedule
        self.index = self.index()
        if self.index != nil {
            self.hiddenID = self.configurations!.gethiddenID(index: self.index!)
            guard (self.hiddenID ?? -1) > -1 else { return }
            self.info.stringValue = Infoschedule().info(num: 3)
            self.preselectrow = true
        } else {
            self.preselectrow = false
            self.info.stringValue = Infoschedule().info(num: 0)
        }
        self.weeklybutton.isEnabled = false
        self.dailybutton.isEnabled = false
        self.oncebutton.isEnabled = false
        self.startdate.dateValue = Date()
        self.starttime.dateValue = Date()
        if self.schedulessorted == nil {
            self.schedulessorted = ScheduleSortedAndExpand()
        }
        globalMainQueue.async(execute: { () -> Void in
            self.mainTableView.reloadData()
        })
        self.delayWithSeconds(0.5) {
            self.enablemenuappbutton()
        }
    }

    // setting which table row is selected
    func tableViewSelectionDidChange(_ notification: Notification) {
        self.info.stringValue = Infoschedule().info(num: 0)
        self.preselectrow = false
        let myTableViewFromNotification = (notification.object as? NSTableView)!
        let indexes = myTableViewFromNotification.selectedRowIndexes
        if let index = indexes.first {
            // Set index
            self.index = index
            let dict = self.configurations!.getConfigurationsDataSourcecountBackup()![index]
            self.hiddenID = dict.value(forKey: "hiddenID") as? Int
        } else {
            self.index = nil
            self.hiddenID = nil
        }
    }

    // Execute tasks by double click in table
    @objc(tableViewDoubleClick:) func tableViewDoubleClick(sender: AnyObject) {
        self.preselectrow = false
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerScheduleDetails!)
        })
    }

    private func enablemenuappbutton() {
        globalMainQueue.async(execute: { () -> Void in
            guard ViewControllerReference.shared.executescheduledtasksmenuapp == true else {
                self.rsyncosxschedbutton.isEnabled = false
                return
            }
            let running = Running()
            guard running.enablemenuappbutton == true else {
                self.rsyncosxschedbutton.isEnabled = false
                if running.menuappnoconfig == false {
                    self.menuappisrunning.image = #imageLiteral(resourceName: "green")
                    self.info.stringValue = Infoschedule().info(num: 5)
                }
                return
            }
            self.rsyncosxschedbutton.isEnabled = true
            self.menuappisrunning.image = #imageLiteral(resourceName: "red")
        })
    }
}

extension ViewControllertabSchedule: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.configurations?.getConfigurationsDataSourcecountBackup()?.count ?? 0
    }
}

extension ViewControllertabSchedule: NSTableViewDelegate, Attributedestring {

   func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < self.configurations!.getConfigurationsDataSourcecountBackup()!.count  else { return nil }
        let object: NSDictionary = self.configurations!.getConfigurationsDataSourcecountBackup()![row]
        let hiddenID: Int = object.value(forKey: "hiddenID") as? Int ?? -1
        switch tableColumn!.identifier.rawValue {
        case "scheduleID" :
            if self.schedulessorted != nil {
                let schedule: String? = self.schedulessorted!.sortandcountscheduledonetask(hiddenID, profilename: nil, number: false)
                if schedule?.isEmpty == false {
                    switch schedule {
                    case "once":
                        return NSLocalizedString("once", comment: "main")
                    case "daily":
                        return NSLocalizedString("daily", comment: "main")
                    case "weekly":
                        return NSLocalizedString("weekly", comment: "main")
                    case "manuel":
                        return NSLocalizedString("manuel", comment: "main")
                    default:
                        return ""
                    }
                } else {
                    return ""
                }
            }
        case "offsiteServerCellID":
            if (object[tableColumn!.identifier] as? String)!.isEmpty {
                if self.preselectrow == true && hiddenID == self.hiddenID ?? -1 {
                    return self.attributedstring(str: "localhost", color: NSColor.red, align: .left)
                } else {
                    return "localhost"
                }
            } else {
                if self.preselectrow == true && hiddenID == self.hiddenID ?? -1 {
                    let text = object[tableColumn!.identifier] as? String
                    return self.attributedstring(str: text!, color: NSColor.red, align: .left)
                } else {
                    return object[tableColumn!.identifier] as? String
                }
            }
        case "inCellID":
            if self.schedulessorted != nil {
                let taskintime: String? = self.schedulessorted!.sortandcountscheduledonetask(hiddenID, profilename: nil, number: true)
                return taskintime ?? ""
            }
        default:
            if self.preselectrow == true && hiddenID == self.hiddenID ?? -1 {
                let text = object[tableColumn!.identifier] as? String
                return self.attributedstring(str: text!, color: NSColor.red, align: .left)
            } else {
                return object[tableColumn!.identifier] as? String
            }
        }
    return nil
    }

}

extension  ViewControllertabSchedule: GetHiddenID {
    func gethiddenID() -> Int {
        return self.hiddenID ?? -1
    }
}

extension ViewControllertabSchedule: DismissViewController {

    func dismiss_view(viewcontroller: NSViewController) {
        self.dismiss(viewcontroller)
        globalMainQueue.async(execute: { () -> Void in
            self.mainTableView.reloadData()
        })
    }
}

extension ViewControllertabSchedule: Reloadandrefresh {

    func reloadtabledata() {
        // Create a New schedules object
        self.schedulessorted = ScheduleSortedAndExpand()
        globalMainQueue.async(execute: { () -> Void in
            self.mainTableView.reloadData()
        })
    }

}

// Deselect a row
extension ViewControllertabSchedule: DeselectRowTable {
    // deselect a row after row is deleted
    func deselect() {
        guard self.index != nil else { return }
        self.mainTableView.deselectRow(self.index!)
    }
}

extension ViewControllertabSchedule: SetProfileinfo {
    func setprofile(profile: String, color: NSColor) {
        globalMainQueue.async(execute: { () -> Void in
            self.profilInfo.stringValue = profile
            self.profilInfo.textColor = color
        })
    }
}

extension ViewControllertabSchedule: OpenQuickBackup {
    func openquickbackup() {
        self.configurations!.processtermination = .quicktask
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerQuickBackup!)
        })
    }
}
