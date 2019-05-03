//
//  ViewControllerCopyFiles.swift
//  RsyncOSX
//
//  Created by Thomas Evensen on 12/09/2016.
//  Copyright © 2016 Thomas Evensen. All rights reserved.
//
//  swiftlint:disable line_length function_body_length file_length

import Foundation
import Cocoa

protocol GetSource: class {
    func getSourceindex(index: Int)
}

class ViewControllerCopyFiles: NSViewController, SetConfigurations, Delay, VcCopyFiles, VcSchedule, Connected, VcExecute {

    var copyFiles: CopySingleFiles?
    var rsyncindex: Int?
    var getfiles: Bool = false
    var estimated: Bool = false
    private var restoretabledata: [String]?
    var diddissappear: Bool = false
    // Infoobject
    var information: Info?

    @IBOutlet weak var numberofrows: NSTextField!
    @IBOutlet weak var server: NSTextField!
    @IBOutlet weak var rcatalog: NSTextField!
    @IBOutlet weak var info: NSTextField!
    @IBOutlet weak var restoretableView: NSTableView!
    @IBOutlet weak var rsynctableView: NSTableView!
    @IBOutlet weak var commandString: NSTextField!
    @IBOutlet weak var remoteCatalog: NSTextField!
    @IBOutlet weak var restorecatalog: NSTextField!
    @IBOutlet weak var working: NSProgressIndicator!
    @IBOutlet weak var search: NSSearchField!
    @IBOutlet weak var restorebutton: NSButton!

    var verifyrsyncpath: Verifyrsyncpath?

    @IBAction func totinfo(_ sender: NSButton) {
        guard ViewControllerReference.shared.norsync == false else {
            self.verifyrsyncpath!.noRsync()
            return
        }
        self.configurations!.processtermination = .remoteinfotask
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerRemoteInfo!)
        })
    }

    @IBAction func quickbackup(_ sender: NSButton) {
        guard ViewControllerReference.shared.norsync == false else {
            self.verifyrsyncpath!.noRsync()
            return
        }
        self.openquickbackup()
    }

    @IBAction func automaticbackup(_ sender: NSButton) {
        self.configurations!.processtermination = .automaticbackup
        self.configurations?.remoteinfotaskworkqueue = RemoteInfoTaskWorkQueue(inbatch: false)
        self.presentAsSheet(self.viewControllerEstimating!)
    }

    // Userconfiguration button
    @IBAction func userconfiguration(_ sender: NSButton) {
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerUserconfiguration!)
        })
    }

    // Abort button
    @IBAction func abort(_ sender: NSButton) {
        self.working.stopAnimation(nil)
        guard self.copyFiles != nil else { return }
        self.restorebutton.isEnabled = true
        self.copyFiles!.abort()
    }

    // Do the work
    @IBAction func restore(_ sender: NSButton) {
        guard self.remoteCatalog.stringValue.isEmpty == false && self.restorecatalog.stringValue.isEmpty == false else {
            self.info.stringValue = self.information!.info3(num: 3)
            return
        }
        guard self.copyFiles != nil else { return }
        self.restorebutton.isEnabled = false
        self.getfiles = true
        self.working.startAnimation(nil)
        if self.estimated == false {
            self.copyFiles!.executeRsync(remotefile: self.remoteCatalog!.stringValue, localCatalog: self.restorecatalog!.stringValue, dryrun: true)
            self.estimated = true
        } else {
            self.copyFiles!.executeRsync(remotefile: self.remoteCatalog!.stringValue, localCatalog: self.restorecatalog!.stringValue, dryrun: false)
            self.estimated = false
        }
    }

    private func displayRemoteserver(index: Int?) {
        guard index != nil else {
            self.server.stringValue = ""
            self.rcatalog.stringValue = ""
            return
        }
        let hiddenID = self.configurations!.gethiddenID(index: index!)
        globalMainQueue.async(execute: { () -> Void in
            self.server.stringValue = self.configurations!.getResourceConfiguration(hiddenID, resource: .offsiteServer)
            self.rcatalog.stringValue = self.configurations!.getResourceConfiguration(hiddenID, resource: .remoteCatalog)
        })
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ViewControllerReference.shared.setvcref(viewcontroller: .vccopyfiles, nsviewcontroller: self)
        self.restoretableView.delegate = self
        self.restoretableView.dataSource = self
        self.rsynctableView.delegate = self
        self.rsynctableView.dataSource = self
        self.working.usesThreadedAnimation = true
        self.search.delegate = self
        self.restorecatalog.delegate = self
        self.remoteCatalog.delegate = self
        self.restoretableView.doubleAction = #selector(self.tableViewDoubleClick(sender:))
        self.information = Info()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        ViewControllerReference.shared.activetab = .vccopyfiles
        guard self.diddissappear == false else {
            globalMainQueue.async(execute: { () -> Void in
                self.rsynctableView.reloadData()
            })
            return
        }
        if let restorePath = ViewControllerReference.shared.restorePath {
            self.restorecatalog.stringValue = restorePath
        } else {
            self.restorecatalog.stringValue = ""
        }
        self.verifylocalCatalog()
        globalMainQueue.async(execute: { () -> Void in
            self.rsynctableView.reloadData()
        })
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        self.diddissappear = true
    }

    @objc(tableViewDoubleClick:) func tableViewDoubleClick(sender: AnyObject) {
        guard self.remoteCatalog.stringValue.isEmpty == false else { return }
        guard self.restorecatalog.stringValue.isEmpty == false else { return }
        let question: String = NSLocalizedString("Copy single files or directory?", comment: "Restore")
        let text: String = NSLocalizedString("Start restore?", comment: "Restore")
        let dialog: String = NSLocalizedString("Restore", comment: "Restore")
        let answer = Alerts.dialogOrCancel(question: question, text: text, dialog: dialog)
        if answer {
            self.restorebutton.isEnabled = false
            self.getfiles = true
            self.working.startAnimation(nil)
            self.copyFiles!.executeRsync(remotefile: remoteCatalog!.stringValue, localCatalog: restorecatalog!.stringValue, dryrun: false)
        }
    }

    private func verifylocalCatalog() {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: self.restorecatalog.stringValue) == false {
            self.info.stringValue = self.information!.info3(num: 1)
        } else {
            self.info.stringValue = self.information!.info3(num: 0)
        }
    }

    private func inprogress() -> Bool {
        guard self.copyFiles != nil else { return false }
        if self.copyFiles?.process != nil {
            return true
        } else {
            return false
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let myTableViewFromNotification = (notification.object as? NSTableView)!
        if myTableViewFromNotification == self.restoretableView {
            self.info.stringValue = self.information!.info3(num: 0)
            let indexes = myTableViewFromNotification.selectedRowIndexes
            if let index = indexes.first {
                guard self.restoretabledata != nil else { return }
                self.remoteCatalog.stringValue = self.restoretabledata![index]
                guard self.remoteCatalog.stringValue.isEmpty == false && self.restorecatalog.stringValue.isEmpty == false else {
                    self.info.stringValue = self.information!.info3(num: 3)
                    return
                }
                self.commandString.stringValue = self.copyFiles!.getCommandDisplayinView(remotefile: self.remoteCatalog.stringValue, localCatalog: self.restorecatalog.stringValue)
                self.estimated = false
                self.restorebutton.title = "Estimate"
                self.restorebutton.isEnabled = true
            }
        } else {
            let indexes = myTableViewFromNotification.selectedRowIndexes
            self.commandString.stringValue = ""
            if let index = indexes.first {
                guard self.inprogress() == false else {
                    self.working.stopAnimation(nil)
                    guard self.copyFiles != nil else { return }
                    self.restorebutton.isEnabled = true
                    self.copyFiles!.abort()
                    return
                }
                let config = self.configurations!.getConfigurations()[index]
                guard self.connected(config: config) == true else {
                    self.restorebutton.isEnabled = false
                    self.info.stringValue = self.information!.info3(num: 4)
                    return
                }
                self.info.stringValue = self.information!.info3(num: 0)
                self.getfiles = false
                self.restorebutton.title = "Estimate"
                self.restorebutton.isEnabled = false
                self.remoteCatalog.stringValue = ""
                self.rsyncindex = index
                let hiddenID = self.configurations!.getConfigurationsDataSourcecountBackupSnapshot()![index].value(forKey: "hiddenID") as? Int ?? -1
                self.copyFiles = CopySingleFiles(hiddenID: hiddenID)
                self.working.startAnimation(nil)
                self.displayRemoteserver(index: index)
            } else {
                self.rsyncindex = nil
                self.restoretabledata = nil
                globalMainQueue.async(execute: { () -> Void in
                    self.restoretableView.reloadData()
                })
            }
        }
    }

    private func reloadtabledata() {
        guard self.copyFiles != nil else { return }
        globalMainQueue.async(execute: { () -> Void in
            self.restoretabledata = self.copyFiles!.filter(search: nil)
            self.restoretableView.reloadData()
        })
    }
}

extension ViewControllerCopyFiles: NSSearchFieldDelegate {

    func controlTextDidChange(_ notification: Notification) {
        if (notification.object as? NSTextField)! == self.search {
            self.delayWithSeconds(0.25) {
                if self.search.stringValue.isEmpty {
                    globalMainQueue.async(execute: { () -> Void in
                        self.restoretabledata = self.copyFiles?.filter(search: nil)
                        self.restoretableView.reloadData()
                    })
                } else {
                    globalMainQueue.async(execute: { () -> Void in
                        self.restoretabledata = self.copyFiles?.filter(search: self.search.stringValue)
                        self.restoretableView.reloadData()
                    })
                }
            }
            self.verifylocalCatalog()
        } else {
            self.delayWithSeconds(0.25) {
                self.verifylocalCatalog()
                self.restorebutton.title = "Estimate"
                self.restorebutton.isEnabled = true
                self.estimated = false
                guard self.remoteCatalog.stringValue.count > 0 else { return }
                self.commandString.stringValue = self.copyFiles?.getCommandDisplayinView(remotefile: self.remoteCatalog.stringValue, localCatalog: self.restorecatalog.stringValue) ?? ""
            }
        }
    }

    func searchFieldDidEndSearching(_ sender: NSSearchField) {
        globalMainQueue.async(execute: { () -> Void in
            self.restoretabledata = self.copyFiles?.filter(search: nil)
            self.restoretableView.reloadData()
        })
    }
}

extension ViewControllerCopyFiles: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == self.restoretableView {
            let numberofrows: String = NSLocalizedString("Number remote files: ", comment: "Copy files")
            guard self.restoretabledata != nil else {
                self.numberofrows.stringValue = numberofrows
                return 0
            }
            self.numberofrows.stringValue = numberofrows + String(self.restoretabledata!.count)
            return self.restoretabledata!.count
        } else {
             return self.configurations?.getConfigurationsDataSourcecountBackupSnapshot()?.count ?? 0
        }
    }
}

extension ViewControllerCopyFiles: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == self.restoretableView {
            guard self.restoretabledata != nil else { return nil }
            let cellIdentifier = "files"
            let text: String = self.restoretabledata![row]
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: self) as? NSTableCellView {
                cell.textField?.stringValue = text
                return cell
            }
        } else {
            guard row < self.configurations!.getConfigurationsDataSourcecountBackupSnapshot()!.count else { return nil }
            let object: NSDictionary = self.configurations!.getConfigurationsDataSourcecountBackupSnapshot()![row]
            let cellIdentifier: String = tableColumn!.identifier.rawValue
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: self) as? NSTableCellView {
                cell.textField?.stringValue = object.value(forKey: cellIdentifier) as? String ?? ""
                return cell
            }
        }
        return nil
    }
}

extension ViewControllerCopyFiles: UpdateProgress {
    func processTermination() {
        if self.getfiles == false {
            self.copyFiles!.setRemoteFileList()
            self.reloadtabledata()
            self.working.stopAnimation(nil)
        } else {
            self.restorebutton.title = "Restore"
            self.working.stopAnimation(nil)
            self.presentAsSheet(self.viewControllerInformation!)
            self.restorebutton.isEnabled = true
        }
        self.copyFiles?.process = nil
    }

    func fileHandler() {
        // nothing
    }
}

extension ViewControllerCopyFiles: DismissViewController {
    func dismiss_view(viewcontroller: NSViewController) {
        self.dismiss(viewcontroller)
    }
}

extension ViewControllerCopyFiles: GetOutput {
    func getoutput() -> [String] {
        return self.copyFiles!.getOutput()
    }
}

extension ViewControllerCopyFiles: TemporaryRestorePath {
    func temporaryrestorepath() {
        if let restorePath = ViewControllerReference.shared.restorePath {
            self.restorecatalog.stringValue = restorePath
        } else {
            self.restorecatalog.stringValue = ""
        }
        self.verifylocalCatalog()
    }
}

extension ViewControllerCopyFiles: NewProfile {
    func newProfile(profile: String?) {
        self.restoretabledata  = nil
        globalMainQueue.async(execute: { () -> Void in
            self.restoretableView.reloadData()
        })
    }

    func enableProfileMenu() {
        //
    }
}

extension ViewControllerCopyFiles: OpenQuickBackup {
    func openquickbackup() {
        self.configurations!.processtermination = .quicktask
        self.configurations!.allowNotifyinMain = false
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerQuickBackup!)
        })
    }
}
