//
//  ViewControllerLoggData.swift
//  RsyncOSX
//  The ViewController is the logview
//
//  Created by Thomas Evensen on 23/09/2016.
//  Copyright © 2016 Thomas Evensen. All rights reserved.
//

import Foundation
import Cocoa

class ViewControllerLoggData: NSViewController {
    
    weak var schedulesDelegate: GetSchedulesObject?
    var schedulesNoS: SchedulesNoS?

    var tabledata: [NSDictionary]?
    var row: NSDictionary?
    var what: Filterlogs?
    var index: Int?

    @IBOutlet weak var scheduletable: NSTableView!
    @IBOutlet weak var search: NSSearchField!
    @IBOutlet weak var server: NSButton!
    @IBOutlet weak var catalog: NSButton!
    @IBOutlet weak var date: NSButton!
    @IBOutlet weak var sorting: NSProgressIndicator!
    @IBOutlet weak var numberOflogfiles: NSTextField!

    // Selecting what to filter
    @IBAction func radiobuttons(_ sender: NSButton) {
        if self.server.state == .on {
            self.what = .remoteServer
        } else if self.catalog.state == .on {
            self.what = .localCatalog
        } else if self.date.state == .on {
            self.what = .executeDate
        }
    }

    // Delete row
    @IBOutlet weak var deleteButton: NSButton!
    @IBAction func deleteRow(_ sender: NSButton) {
        guard self.row != nil else {
            self.deleteButton.state = .off
            return
        }
        Schedules.shared.deletelogrow(hiddenID: (self.row?.value(forKey: "hiddenID") as? Int)!,
                                               parent: (self.row?.value(forKey: "parent") as? String)!,
                                               resultExecuted: (self.row?.value(forKey: "resultExecuted") as? String)!,
                                               dateExecuted:(self.row?.value(forKey: "dateExecuted") as? String)!)
        self.deleteButton.state = .off
        self.deselectRow()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.scheduletable.delegate = self
        self.scheduletable.dataSource = self
        self.search.delegate = self
        self.sorting.usesThreadedAnimation = true
        // Reference to LogViewController
        ViewControllerReference.shared.setvcref(viewcontroller: .vcloggdata, nsviewcontroller: self)
        self.schedulesDelegate = ViewControllerReference.shared.getvcref(viewcontroller: .vctabmain)
            as? ViewControllertabMain
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        self.schedulesNoS = self.schedulesDelegate?.getschedulesobject()
        globalMainQueue.async(execute: { () -> Void in
            self.sorting.startAnimation(self)
            self.tabledata = ScheduleLoggData().getallloggdata()
            self.scheduletable.reloadData()
            self.sorting.stopAnimation(self)
        })
        self.catalog.state = .on
        self.what = .localCatalog
        self.deleteButton.state = .off
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        self.sorting.startAnimation(self)
        self.tabledata = nil
    }

    // deselect a row after row is deleted
    private func deselectRow() {
        guard self.index != nil else {
            return
        }
        self.scheduletable.deselectRow(self.index!)
    }
}

extension ViewControllerLoggData : NSSearchFieldDelegate {

    override func controlTextDidChange(_ obj: Notification) {
        guard self.server.state.rawValue == 1 ||
            self.catalog.state.rawValue == 1 ||
            self.date.state.rawValue == 1 else {
            return
        }
        let filterstring = self.search.stringValue
        self.sorting.startAnimation(self)
        if filterstring.isEmpty {
            globalMainQueue.async(execute: { () -> Void in
                self.tabledata = ScheduleLoggData().getallloggdata()
                self.scheduletable.reloadData()
                self.sorting.stopAnimation(self)
            })
        } else {
            globalMainQueue.async(execute: { () -> Void in
                ScheduleLoggData().filter(search: filterstring, what:self.what)
            })
        }
    }

    func searchFieldDidEndSearching(_ sender: NSSearchField) {
        self.index = nil
        globalMainQueue.async(execute: { () -> Void in
            self.tabledata = ScheduleLoggData().getallloggdata()
            self.scheduletable.reloadData()
        })
    }

}

extension ViewControllerLoggData : NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        if self.tabledata == nil {
            self.numberOflogfiles.stringValue = "Number of rows:"
            return 0
        } else {
            self.numberOflogfiles.stringValue = "Number of rows: " + String(self.tabledata!.count)
            return (self.tabledata!.count)
        }
    }

}

extension ViewControllerLoggData : NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let object: NSDictionary = self.tabledata![row]
        return object[tableColumn!.identifier] as? String
    }

    // setting which table row is selected
    func tableViewSelectionDidChange(_ notification: Notification) {
        let myTableViewFromNotification = (notification.object as? NSTableView)!
        let indexes = myTableViewFromNotification.selectedRowIndexes
        if let index = indexes.first {
            self.index = index
            self.row = self.tabledata?[self.index!]
        }
    }

}

extension ViewControllerLoggData: RefreshtableView {

    // Refresh tableView
    func refresh() {
        globalMainQueue.async(execute: { () -> Void in
            self.tabledata = ScheduleLoggData().getallloggdata()
            self.scheduletable.reloadData()
        })
        self.row = nil
    }
}

extension ViewControllerLoggData: Readfiltereddata {
    func readfiltereddata(data: Filtereddata) {
        globalMainQueue.async(execute: { () -> Void in
            self.tabledata = data.filtereddata
            self.scheduletable.reloadData()
            self.sorting.stopAnimation(self)
        })
    }
}
