//
//  AllProfilenames.swift
//  RsyncOSX
//
//  Created by Thomas Evensen on 15.05.2018.
//  Copyright © 2018 Thomas Evensen. All rights reserved.
//

import Foundation

class AllProfilenames {

   var allprofiles: [String]?

    private func getprofilenames() {
        let profile = Files(whichroot: .profileRoot, configpath: ViewControllerReference.shared.configpath)
        self.allprofiles = profile.getDirectorysStrings()
        guard self.allprofiles != nil else { return }
        self.allprofiles!.append(NSLocalizedString("Default profile", comment: "default profile"))
    }

    init() {
        self.getprofilenames()
    }
}
