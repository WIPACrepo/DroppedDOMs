//
//  DroppedDOMs.swift
//  DroppedDOMs
//
//  Created by Dave Glowacki on 6/12/15.
//  Copyright © 2015 Dave Glowacki. All rights reserved.
//

import Foundation

enum EntryType {
    case MoniFile
    case UserAlert
    case Both
    case Unknown
}

struct DroppedDOM {
    var entryType: EntryType
    let mbid: Int64
    let name: String
    let string: Int
    let position: Int
    let droptime: NSDate

    var description: String {
        return "(\(string)-\(position)) \(droptime)"
    }

    mutating func updateType(newType: EntryType) {
        switch entryType {
        case .Unknown:
            entryType = newType
        case .MoniFile:
            if newType == .UserAlert || newType == .Both {
                entryType = .Both
            }
        case .UserAlert:
            if newType == .MoniFile || newType == .Both {
                entryType = .Both
            }
        case .Both:
            break
        }
    }
}

enum LoadError {
    case Success
    case BadType(field: String, type: String)
    case BadDropTime(value: String)
    case BadMBID(value: String)
    case BadValueDict
    case DuplicateName(old: Int64, new: Int64)
    case UnknownField(name: String)
}

class DroppedDOMs {
    var keys: [String] = []
    var data: [String: DroppedDOM] = [:]

    var count: Int {
        return data.count
    }

    func convertFromHex(str: String) -> Int64? {
        let scanner = NSScanner(string: str)
        var val: UInt64 = 0
        scanner.scanHexLongLong(&val)
        if scanner.atEnd {
            return Int64(val)
        }
        return nil
    }

    func load(dict: [String: AnyObject]) -> LoadError {
        // clear old values before loading data
        keys.removeAll()
        data.removeAll()

        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyy-MM-dd hh:mm:ss"

        for (key, val) in dict {
            var type: EntryType
            switch key {
            case "moni_file":
                type = .MoniFile
            case "user_alert":
                type = .UserAlert
            default:
                type = .Unknown
            }

            if let vallist = val as? [[String: AnyObject]] {
                for subdict in vallist {
                    var mbid: Int64 = 0
                    var name: String = ""
                    var string: Int = 0
                    var position: Int = 0
                    var droptime: NSDate = NSDate()
                    
                    for (fldname, valobj) in subdict {
                        switch fldname {
                        case "dom_mbid":
                            if let valstr = valobj as? String {
                                //mbid = strtoll(valstr, nil, 16)
                                if let val = convertFromHex(valstr) {
                                    mbid = val
                                } else {
                                    return .BadMBID(value: valstr)
                                }
                            } else {
                                return .BadType(field: fldname, type: "\(valobj.dynamicType.description())")
                            }
                        case "dom_name":
                            if let valstr = valobj as? String {
                                name = valstr
                            } else {
                                return .BadType(field: fldname, type: "\(valobj.dynamicType.description())")
                            }
                        case "dom_string":
                            if let valnum = valobj as? Int {
                                string = valnum
                            } else {
                                return .BadType(field: fldname, type: "\(valobj.dynamicType.description())")
                            }
                        case "dom_position":
                            if let valnum = valobj as? Int {
                                position = valnum
                            } else {
                                return .BadType(field: fldname, type: "\(valobj.dynamicType.description())")
                            }
                        case "drop_time":
                            if let valstr = valobj as? String {
                                if let tmptime = dateFormatter.dateFromString(valstr) {
                                    droptime = tmptime
                                } else {
                                    return .BadDropTime(value: valstr)
                                }
                            } else {
                                return .BadType(field: fldname, type: "\(valobj.dynamicType.description())")
                            }
                        default:
                            return .UnknownField(name: fldname)
                        }
                    }

                    if var oldval = data[name] {
                        if mbid != oldval.mbid {
                            return .DuplicateName(old: oldval.mbid, new: mbid)
                        }

                        oldval.updateType(type)
                    } else {
                        data[name] = DroppedDOM(entryType: type, mbid: mbid, name: name, string: string,
                            position: position, droptime: droptime)
                    }
                }
            } else {
                return .BadValueDict
            }
        }

        keys = Array(data.keys).sort()
        return .Success
    }
    
    func entry(index: Int) -> DroppedDOM? {
        if index < 0 || index >= data.count {
            return nil
        }
        
        return data[keys[index]]
    }
    
    func name(index: Int) -> String {
        if index < 0 || index >= data.count {
            return "??\(index)??"
        }
        
        return keys[index]
    }
    
    func value(index: Int) -> String {
        if index < 0 || index >= data.count {
            return "??\(index)??"
        }
        
        return data[keys[index]]!.description
    }
}