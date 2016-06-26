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

    var downNotes: Set<UInt8> = Set()
    var chordNotes: Set<UInt8> = Set()
    var chordTimer: NSTimer?

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
        // print("Midi notify: \(pl.numPackets), len=\(pl.packet.length)")

        var buf: Array<UInt8> = Array()
        
        // Grumble, you can't iterate tuples in Swift. I'm not sure why they did this.
        let mdata = Mirror(reflecting: pl.packet.data)
        for (index, item) in mdata.children.enumerate() {
            if index == Int(pl.packet.length) {
                break
            }
            buf.append(item.value as! UInt8)
            // let hex = String(format: "%02x", item.value as! UInt8)
            // print("  byte(\(index)): \(hex)")
        }
        // print("   data: \(buf)")

        // TODO: For now, make the assumption that MIDI packets are entirely
        // contained within the received buffer.
        let len = buf.count
        var pos = 0
        while pos < len {
            let byte = buf[pos]
            if (byte & 0x80) == 0 {
                // print("WARN: Bare MIDI data received: \(byte)")
                pos += 1
                continue
            }

            switch byte & 0xf0 {
            case 0x80, 0x90:
                let isDown = (byte & 0xf0) == 0x90
                if pos + 2 >= len {
                    print("MIDI up/down missing data")
                    break
                }
                let note = buf[pos+1]
                // let velo = buf[pos+2]
                pos += 3

                // let direction = isDown ? "down" : "up"
                // print("Midi \(direction), note: \(note), velo: \(velo)")

                if isDown {
                    downNote(note)
                } else {
                    upNote(note)
                }
            default:
                pos += 1
            }
        }
        // TODO: Unsure what to do if more than one packet.
        // counter += Int(pl.packet.length)
        // update()
    }

    // We keep track of the notes that have been played.  Notes that are played
    // within a reasonably short time period are considered part of a chord.
    func downNote(note: UInt8) {
        synced(self) {
            self.downNotes.insert(note)
            self.chordNotes.insert(note)

            // Invalidate any existing timer.
            self.chordTimer?.invalidate()

            self.chordTimer = NSTimer(timeInterval: 0.250,
                    target: self, selector: #selector(Midi.chordFire),
                    userInfo: nil, repeats: false)
            NSRunLoop.mainRunLoop().addTimer(self.chordTimer!, forMode: NSRunLoopCommonModes)
            // NSRunLoop.currentRunLoop().addTimer(chordTimer!, forMode: NSRunLoopCommonModes)
            // print("Down: \(self.downNotes)")
            // print("Timer: \(self.chordTimer)")
        }
    }

    func upNote(note: UInt8) {
        synced(self) {
            self.downNotes.remove(note)
        }
    }

    @objc
    func chordFire() {
        var chord: Set<UInt8> = Set()
        synced(self) {
            self.chordTimer?.invalidate()
            self.chordTimer = nil
            chord = self.chordNotes
            self.chordNotes = Set()
        }
        print("Chord: \(chord)")
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

// Perform the operation synced.
func synced(obj: AnyObject, thunk: () -> ()) {
    objc_sync_enter(obj)
    defer { objc_sync_exit(obj) }
    thunk()
}
