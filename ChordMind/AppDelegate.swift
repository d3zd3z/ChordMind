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
    
    var mclient = MIDIClientRef()
    var mport = MIDIPortRef()

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        logArea.stringValue = "This is the first line\nAnd this is the second\n"
        
        // Connect to the MIDI system.
        if MIDIClientCreate("ChordMind", nil, nil, &mclient) != 0 {
            // Warn about difficulties with the midi system, and at least present a dialog.
            exit(1)
        }
        // if MIDIInputPortCreate(mclient, "input", midiRead, nil, &mport) != 0 {
        if MIDIInputPortCreateWithBlock(mclient, "input", &mport, midiNotify) != 0 {
            print("Error creating port")
            exit(1)
        }
        
        // Determine how many devices we have.
        let num = MIDIGetNumberOfDevices()
        print("There are \(num) MIDI devices")
        for devNo in 0 ..< num {
            let dev = MIDIGetDevice(devNo)
            let nEntities = MIDIDeviceGetNumberOfEntities(dev)
            print("  dev \(devNo) has \(nEntities) children")
            let (s,p) = getProperties(dev)
            if let properties = p where s == noErr {
                print(properties)
            }
            
            for entNo in 0 ..< nEntities {
                let entity = MIDIDeviceGetEntity(dev, entNo)
                let nSources = MIDIEntityGetNumberOfSources(entity)
                for srcNo in 0 ..< nSources {
                    let src = MIDIEntityGetSource(entity, srcNo)
                    print("  src = \(src)")
                    
                    // Connect the source to our port.
                    if MIDIPortConnectSource(mport, src, nil) != 0 {
                        print("  Error connecting source")
                    }
                }
            }
        }
        
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
    
    func midiNotify(message: UnsafePointer<MIDIPacketList>, con: UnsafeMutablePointer<Void>) -> Void {
        let pl = message.memory
        print("Midi notify: \(pl.numPackets), len=\(pl.packet.length)")
        // TODO: Unsure what to do if more than one packet.
        counter += Int(pl.packet.length)
        update()
    }
}

func getProperties(obj: MIDIObjectRef) -> (OSStatus, Dictionary<String, AnyObject>?) {
    var properties: Unmanaged<CFPropertyList>?
    let status = MIDIObjectGetProperties(obj, &properties, true)
    defer { properties?.release() }
    if status != noErr {
        print("error getting properties \(status)")
        return (status, nil)
    }
    
    if let dict = properties?.takeUnretainedValue() as? Dictionary<String, AnyObject> {
        return (status, dict)
    } else {
        return (status, nil)
    }
}