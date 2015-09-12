//
//  TestUtil.swift
//  DroppedDOMs
//
//  Created by Dave Glowacki on 8/2/15.
//  Copyright © 2015 Dave Glowacki. All rights reserved.
//

import Foundation

@testable import DroppedDOMs

class MockRequester: JSONRequester {
    var result: JSONResult?
    
    init() {
        result = nil
    }
    
    func request(subject: RequestSubject, url: NSURL, postData: NSData, immediately: Bool) -> JSONResult {
        //print("url \(url) post \(postData)")
        if let r = result {
            return r
        }
        
        return .Error(message: "No result specified")
    }
    
    func setResult(result: JSONResult) {
        self.result = result
    }
}
