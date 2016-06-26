//
//  Midi.swift
//  ChordMind
//
//  Created by David Brown on 6/25/16.
//  Copyright © 2016 David Brown. All rights reserved.
//

import Foundation
import CoreMIDI

class Midi {
    var mclient = MIDIClientRef()
    var mport = MIDIPortRef()

    init() {
        if MIDIClientCreate("org.davidb.ChordMind", nil, nil, &mclient) != 0 {
            // This should fail.
            exit(1)
        }

        if MIDIInputPortCreateWithBlock(mclient, "input", &mport, midiNotify) != 0 {
            print("Error creating port")
            exit(1)
        }

        // Walk the MIDI tree and assign.
        let numDevs = MIDIGetNumberOfDevices()
        for devNum in 0 ..< numDevs {
            let dev = MIDIGetDevice(devNum)

            /*
            let (s,p) = getProperties(dev)
            if let properties = p where s == noErr {
                print(properties)
            }
            */

            let numEntries = MIDIDeviceGetNumberOfEntities(dev)
            // Get the properties to have names to associate with.
            for entNum in 0 ..< numEntries {
                let entity = MIDIDeviceGetEntity(dev, entNum)
                let numSources = MIDIEntityGetNumberOfSources(entity)
                for srcNum in 0 ..< numSources {
                    let src = MIDIEntityGetSource(entity, srcNum)

                    // For now, connect all sources.
                    if MIDIPortConnectSource(mport, src, nil) != 0 {
                        print("  Error connecting source")
                    }
                }
            }
        }
    }

    func midiNotify(message: UnsafePointer<MIDIPacketList>, con: UnsafeMutablePointer<Void>) -> Void {
        let pl = message.memory
        print("Midi notify: \(pl.numPackets), len=\(pl.packet.length)")

        var buf: Array<UInt8> = Array()
        
        // Grumble, you can't iterate tuples in Swift. I'm not sure why they did this.
        let mdata = Mirror(reflecting: pl.packet.data)
        for (index, item) in mdata.children.enumerate() {
            if index == Int(pl.packet.length) {
                break
            }
            buf.append(item.value as! UInt8)
            let hex = String(format: "%02x", item.value as! UInt8)
            print("  byte(\(index)): \(hex)")
        }
        print("   data: \(buf)")
        // TODO: Unsure what to do if more than one packet.
        // counter += Int(pl.packet.length)
        // update()
    }
}

// Retrieve the properties of a midi object
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
