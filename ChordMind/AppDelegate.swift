//
//  AppDelegate.swift
//  ChordMind
//
//  Created by David Brown on 6/24/16.
//  Copyright © 2016 David Brown. All rights reserved.
//

import Cocoa
import CoreMIDI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var logArea: NSTextField!
    @IBOutlet weak var countField: NSTextField!
    
    var counter = 0
    
    var midi = Midi()

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        logArea.stringValue = "This is the first line\nAnd this is the second\n"
        
        update()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    func update() {
        countField.stringValue = "Count: \(counter)"
    }
    
    @IBAction func pushAppend(sender: AnyObject) {
        logArea.stringValue += "Appending some text\n"
        print("Show me some text")
    }
}
