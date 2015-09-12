//
//  LiveAPITests.swift
//  DroppedDOMs
//
//  Created by Dave Glowacki on 7/21/15.
//  Copyright © 2015 Dave Glowacki. All rights reserved.
//

import XCTest

@testable import DroppedDOMs

class LiveAPITests: XCTestCase {
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
    
    func testRequestDelayed() {
        let api = LiveAPI(rootURL: "xxx", username: "", password: "pswd")
        
        let req = MockRequester()
        api.requester = req
        
        req.setResult(JSONResult.Delayed)
        
        switch api.droppedDOMs(123456, immediately: false) {
        case .Delayed:
            break
        default:
            XCTFail("Should not succeed")
        }
    }
    
    func testRequestError() {
        let api = LiveAPI(rootURL: "xxx", username: "user", password: "pswd")
    
        let req = MockRequester()
         api.requester = req

        req.setResult(JSONResult.Error(message: "XXX"))

        switch api.droppedDOMs(123456, immediately: true) {
        case .Error(let msg):
            XCTAssertEqual(msg, "XXX")
        default:
            XCTFail("Should not succeed")
        }
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