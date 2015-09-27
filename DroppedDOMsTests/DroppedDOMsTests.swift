//
//  DroppedDOMsTests.swift
//  DroppedDOMsTests
//
//  Created by Dave Glowacki on 5/24/15.
//  Copyright (c) 2015 Dave Glowacki. All rights reserved.
//

import XCTest

@testable import DroppedDOMs

class MyDOM {
    static let fmt = NSDateFormatter()
    static var fmtInit = false
    
    let mbid: Int64
    let name: String
    let string: Int
    let position: Int
    let droptime: NSDate
    
    init(mbid: Int64, name: String, string: Int, position: Int, droptime: String) {
        if !MyDOM.fmtInit {
            MyDOM.initDateFmt()
        }
        
        self.mbid = mbid
        self.name = name
        self.string = string
        self.position = position
        self.droptime = MyDOM.fmt.dateFromString(droptime)!
    }
    
    class func initDateFmt() {
        fmt.dateFormat = "yyy-MM-dd hh:mm:ss"
        fmt.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        fmtInit = true
    }
    
    func assertEqual(dd: DroppedDOM) {
        XCTAssertEqual(self.mbid, dd.mbid, "\(dd.mbid) != expected MBID \(self.mbid)")
        XCTAssertEqual(self.name, dd.name, "\(dd.name) != expected MBID \(self.name)")
        XCTAssertEqual(self.string, dd.string, "\(dd.string) != expected MBID \(self.string)")
        XCTAssertEqual(self.position, dd.position, "\(dd.position) != expected MBID \(self.position)")
        XCTAssertEqual(self.droptime, dd.droptime, "\(dd.droptime) != expected MBID \(self.droptime)")
    }
    
    func dict() -> [String: AnyObject] {
        if !MyDOM.fmtInit {
            MyDOM.initDateFmt()
        }
        
        return [
            "dom_mbid": NSString(format:"%12X", self.mbid),
            "dom_name": self.name,
            "dom_string": self.string,
            "dom_position": self.position,
            "drop_time": MyDOM.fmt.stringFromDate(self.droptime),
        ]
    }
}

class DroppedDOMsTests: XCTestCase {
    /*
    override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
    }
    */
    
    func checkDOMs(expDOMs: [MyDOM], droppedDOMs dd: DroppedDOMs) {
        XCTAssertEqual(expDOMs.count, dd.count, "Expected \(expDOMs.count) DOMs, not \(dd.count)")
        
        for dom in expDOMs {
            for i in 0...dd.count {
                var found = false
                if let dom = dd.entry(i) {
                    for e in expDOMs {
                        print("CMP \(dom.name) and \(e.name)")
                        if dom.name == e.name {
                            found = true
                            e.assertEqual(dom)
                        } else {
                            print("'\(dom.name) != \(e.name)")
                        }
                    }
                }
                if found { break}
                XCTAssertTrue(found, "DOM \(dom) was not found")
            }
        }
    }

    func createDictFromList(expDOMs: [MyDOM]) -> [[String: AnyObject]] {
        var dict: [[String: AnyObject]] = []
        for dom in expDOMs {
            dict.append(dom.dict())
        }
        return dict
    }

    func createDOMs() -> [MyDOM] {
        return [
            MyDOM(mbid: 1234567890, name: "ABC", string: 12, position: 34, droptime: "2015-08-09 12:34:56"),
        ]
    }

    func testLoadUnknown() {
        let dd = DroppedDOMs()
        let rtnval = dd.load(["abc": "def"])
        
        switch rtnval {
        case .BadValueDict: break
        default: XCTFail("Load failed with \(rtnval)")
        }
        
        XCTAssertEqual(dd.count, 0,
            "Unexpected number of values  \(dd.count) for unknown message")
    }

    func testLoadMoniFileBad() {
        let dd = DroppedDOMs()
        let rtnval = dd.load(["moni_file": "xxx"])
        
        switch rtnval {
        case .BadValueDict: break
        default: XCTFail("Load failed with \(rtnval)")
        }
        
        XCTAssertEqual(dd.count, 0,
            "Unexpected number of values  \(dd.count) for unknown message")
    }
    
    func testLoadUserAlertBad() {
        let dd = DroppedDOMs()
        
        let rtnval = dd.load(["user_alert": "xxx"])
        switch rtnval {
        case .BadValueDict: break
        default: XCTFail("Load failed with \(rtnval)")
        }
        
        XCTAssertEqual(dd.count, 0,
            "Unexpected number of values  \(dd.count) for unknown message")
    }
    
    func testLoadMoniFile() {
        let expDOMs = createDOMs()
        
        let dict = createDictFromList(expDOMs)
        
        let dd = DroppedDOMs()
        
        let rtnval: LoadError = dd.load(["moni_file": dict])
        switch rtnval {
        case .Success: break
        default: XCTFail("Load failed with \(rtnval)")
        }
        
        checkDOMs(expDOMs, droppedDOMs: dd)
    }
    
    func testLoadBadMBID() {
        let expDOMs = createDOMs()
        
        var dict = createDictFromList(expDOMs)
        dict[0]["dom_mbid"] = "0123not valid"
        
        let dd = DroppedDOMs()
        
        let rtnval: LoadError = dd.load(["moni_file": dict])
        switch rtnval {
        case .BadMBID: break
        default: XCTFail("Load failed with \(rtnval)")
        }
        
        XCTAssertEqual(0, dd.count, "Did not expect \(dd.count) DOMs")
    }
    
    func testLoadBadMBIDType() {
        let expDOMs = createDOMs()
        
        var dict = createDictFromList(expDOMs)
        dict[0]["dom_mbid"] = 123
        
        let dd = DroppedDOMs()
        
        let rtnval: LoadError = dd.load(["moni_file": dict])
        switch rtnval {
        case .BadType: break
        default: XCTFail("Load failed with \(rtnval)")
        }
        
        XCTAssertEqual(0, dd.count, "Did not expect \(dd.count) DOMs")
    }
    
    func testLoadBadNameType() {
        let expDOMs = createDOMs()
        
        var dict = createDictFromList(expDOMs)
        dict[0]["dom_name"] = 123
        
        let dd = DroppedDOMs()
        
        let rtnval: LoadError = dd.load(["moni_file": dict])
        switch rtnval {
        case .BadType: break
        default: XCTFail("Load failed with \(rtnval)")
        }
        
        XCTAssertEqual(0, dd.count, "Did not expect \(dd.count) DOMs")
    }
    
    func testLoadBadStringType() {
        let expDOMs = createDOMs()
        
        var dict = createDictFromList(expDOMs)
        dict[0]["dom_string"] = "123"
        
        let dd = DroppedDOMs()
        
        let rtnval: LoadError = dd.load(["moni_file": dict])
        switch rtnval {
        case .BadType: break
        default: XCTFail("Load failed with \(rtnval)")
        }
        
        XCTAssertEqual(0, dd.count, "Did not expect \(dd.count) DOMs")
    }
    
    func testLoadBadPositionType() {
        let expDOMs = createDOMs()
        
        var dict = createDictFromList(expDOMs)
        dict[0]["dom_position"] = "xyz"
        
        let dd = DroppedDOMs()
        
        let rtnval: LoadError = dd.load(["moni_file": dict])
        switch rtnval {
        case .BadType: break
        default: XCTFail("Load failed with \(rtnval)")
        }
        
        XCTAssertEqual(0, dd.count, "Did not expect \(dd.count) DOMs")
    }
    
    func testLoadBadDropTimeType() {
        let expDOMs = createDOMs()
        
        var dict = createDictFromList(expDOMs)
        dict[0]["drop_time"] = 20150810
        
        let dd = DroppedDOMs()
        
        let rtnval: LoadError = dd.load(["moni_file": dict])
        switch rtnval {
        case .BadType: break
        default: XCTFail("Load failed with \(rtnval)")
        }
        
        XCTAssertEqual(0, dd.count, "Did not expect \(dd.count) DOMs")
    }
    
    func testLoadBadDropTime() {
        let expDOMs = createDOMs()
        
        var dict = createDictFromList(expDOMs)
        dict[0]["drop_time"] = "2015-08-10 "
        
        let dd = DroppedDOMs()
        
        let rtnval: LoadError = dd.load(["moni_file": dict])
        switch rtnval {
        case .BadDropTime: break
        default: XCTFail("Load failed with \(rtnval)")
        }
        
        XCTAssertEqual(0, dd.count, "Did not expect \(dd.count) DOMs")
    }
    
    func testLoadUnknownField() {
        let expDOMs = createDOMs()
        
        var dict = createDictFromList(expDOMs)
        dict[0]["dom_foo"] = "unknown"
        
        let dd = DroppedDOMs()
        
        let rtnval: LoadError = dd.load(["moni_file": dict])
        switch rtnval {
        case .UnknownField: break
        default: XCTFail("Load failed with \(rtnval)")
        }
        
        XCTAssertEqual(0, dd.count, "Did not expect \(dd.count) DOMs")
    }
    
    func testDuplicateName() {
        let expDOMs = createDOMs()
        
        let dd = DroppedDOMs()
        
        var d1 = createDictFromList(expDOMs)
        
        let rtnval: LoadError = dd.load(["moni_file": d1])
        switch rtnval {
        case .Success: break
        default: XCTFail("Load failed with \(rtnval)")
        }
        
        XCTAssertEqual(expDOMs.count, dd.count, "Did not expect \(dd.count) DOMs")
        
        if let nobj = d1[0]["dom_name"] {
            let name = nobj as! String
            d1.append(["dom_mbid": "A1B2C3D4E5F6", "dom_name": name])
        } else {
            XCTFail("Cannot retrieve dom_name from created dict")
        }
        
        let r2: LoadError = dd.load(["moni_file": d1])
        switch r2 {
        case .DuplicateName: break
        default: XCTFail("Load failed with \(rtnval)")
        }
        
        XCTAssertEqual(1, dd.count, "Did not expect \(dd.count) DOMs")
    }
    
    /*
    func testPerformanceExample() {
    // This is an example of a performance test case.
    self.measureBlock() {
    // Put the code you want to measure the time of here.
    }
    }
    */
}
