//
//  RestAPITests.swift
//  DroppedDOMs
//
//  Created by Dave Glowacki on 8/2/15.
//  Copyright © 2015 Dave Glowacki. All rights reserved.
//

import XCTest
@testable import DroppedDOMs

class MyRequester: DefaultRequester {
    var data: NSData? = nil
    var error: NSError? = nil
    
    override func startAsynchronous(request: NSURLRequest, subject: RequestSubject) {
        // does nothing
    }

    override func startSynchronous(request: NSURLRequest, inout response: NSURLResponse?) -> (NSData?, NSError?) {
        return (data, error)
    }
}

class MySubject: RequestSubject {
    var result: JSONResult?
    
    func appendData(data: NSData) {
        // do nothing
    }
    func processData() -> JSONResult {
        if let r = result {
            return r
        }
        return .Error(message: "Fail")
    }
    func processError(_: NSError) {
        XCTFail("Should not receive error")
    }
    
}

class DefaultRequesterTests: XCTestCase {
    func testDelayed() {
        let fakeURL = NSURL(fileURLWithPath: "/foo/bar")
        let fakeData = "xxx".dataUsingEncoding(NSUTF8StringEncoding)!
        let req = MyRequester()
        switch req.request(MySubject(), url: fakeURL, postData: fakeData, immediately: false) {
        case .Delayed:
            break
        default:
            XCTFail("Should return Delayed")
        }
    }
    
    func testImmediateNoData() {
        let fakeURL = NSURL(fileURLWithPath: "/foo/bar")
        let fakeData = "xxx".dataUsingEncoding(NSUTF8StringEncoding)!
        let req = MyRequester()
        let resp = req.request(MySubject(), url: fakeURL, postData: fakeData, immediately: true)
        switch resp {
        case .Success:
            XCTFail("Should not return Success")
        case .Error(let msg):
            XCTAssertEqual(msg, "No data returned",
                "Unexpected error message \(msg)")
        case .Delayed:
            XCTFail("Should not return Delayed")
        }
    }
    
    func testImmediateError() {
        let fakeURL = NSURL(fileURLWithPath: "/foo/bar")
        let fakeData = "xxx".dataUsingEncoding(NSUTF8StringEncoding)!
        
        let req = MyRequester()
        req.data = fakeData
        
        let subj = MySubject()
        subj.result = JSONResult.Error(message: "ImmediateFail")
        
        let resp = req.request(subj, url: fakeURL, postData: fakeData, immediately: true)
        switch resp {
        case .Success:
            XCTFail("Should not return Success")
        case .Error(let msg):
            XCTAssertEqual(msg, "ImmediateFail",
                "Unexpected error message \(msg)")
        case .Delayed:
            XCTFail("Should not return Delayed")
        }
    }
    
    func testImmediateSuccess() {
        let fakeURL = NSURL(fileURLWithPath: "/foo/bar")
        let fakeData = "xxx".dataUsingEncoding(NSUTF8StringEncoding)!
        
        let req = MyRequester()
        req.data = fakeData
        
        let subj = MySubject()
        subj.result = JSONResult.Success(data: ["abc": "def"])
        
        let resp = req.request(subj, url: fakeURL, postData: fakeData, immediately: true)
        switch resp {
        case .Success:
            break
        case .Error:
            XCTFail("Should not return Error")
        case .Delayed:
            XCTFail("Should not return Delayed")
        }
    }
}

class RestAPITests: XCTestCase {
    func testProcessDataError() {
        let api = RestAPI()
        
        let jstr = "{\"abc\""
        let data: NSData = jstr.dataUsingEncoding(NSUTF8StringEncoding)!
        api.appendData(data)
        
        switch api.processData() {
        case .Delayed:
            XCTFail("Should not be delayed")
        case .Error:
            break
        case .Success(let data):
            XCTFail("Should not succeed with \(data)")
        }
        
    }

    func testProcessDataValid() {
        let api = RestAPI()
        
        let jstr = "{\"abc\": \"def\", \"ghi\": 987}"
        let data: NSData = jstr.dataUsingEncoding(NSUTF8StringEncoding)!
        api.appendData(data)
        
        switch api.processData() {
        case .Delayed:
            XCTFail("Should not be delayed")
        case .Error(let message):
            XCTFail("Should not return error \(message)")
        case .Success(let data):
            if let abcObj = data["abc"] {
                if let abcVal = abcObj as? NSString {
                    XCTAssertEqual(abcVal, "def", "Dictionary \"abc\" value should be \"def\", not \(abcVal)")
                } else {
                    let dval = data["abc"]
                    XCTFail("Bad value \(dval) for \"abc\"")
                }
            } else {
                XCTFail("Did not return dictionary \"abc\" value")
            }
            break
        }
    }

/*
    func testWebPageDownload() {
        let expectation = expectationWithDescription("RestAPI request")

        let api = RestAPI()
        api.restCall(url: "http://live.icecube.wisc.edu/not_really", completion: {
            (page: String?) -> () in
            if let downloadedPage = page {
                XCTAssert(!downloadedPage.isEmpty, "The page is empty")
                expectation.fulfill()
            }
        }, immediately: false)
        
        waitForExpectationsWithTimeout(5.0, handler:nil)
    }
*/
}
