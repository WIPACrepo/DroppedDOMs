//
//  LiveAPI.swift
//  DroppedDOMsDumb
//
//  Created by Dave Glowacki on 5/24/15.
//  Copyright (c) 2015 Dave Glowacki. All rights reserved.
//

import Foundation

public enum JSONResult {
    case Success(data: [String: AnyObject])
    case Delayed
    case Error(message: String)
}

protocol RequestSubject: AnyObject {
    func processData(data: NSData)
    func processError(_: NSError)
}

protocol JSONRequester {
    func request(subject: RequestSubject, url: NSURL,
                 postData: NSData) -> JSONResult
}

class DefaultRequester: JSONRequester {
    /// Send a POST request to the url and return the result.
    ///
    /// - parameter NSURL: target URL
    /// - parameter NSData: data sent as part of the POST
    /// - returns: - `JSONResult.Success` if the call succeeded
    ///           - `JSONResult.Delayed` for asynchronous calls
    ///           - `JSONResult.Error` if there was a problem
    func request(subject: RequestSubject, url: NSURL,
                 postData: NSData) -> JSONResult
    {

        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        request.HTTPBody = postData
        request.setValue(String(postData.length),
                         forHTTPHeaderField: "Content-Length")
        request.setValue("application/x-www-form-urlencoded",
                         forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        startAsynchronous(request, subject: subject)

        return .Delayed
    }

    func startAsynchronous(request: NSURLRequest, subject: RequestSubject) {
        let session = NSURLSession.sharedSession()
print("URLRequest \(request)")
        let task = session.dataTaskWithRequest(request) {
            (data, response, error) -> Void in
            if error != nil {
                subject.processError(error!)
            } else if data != nil {
print("SessionData \(data)")
                subject.processData(data!)
            } else {
                let errmsg = "Request did not return any data"
                let error = NSError(domain: "RESTAPI", code: 600,
                                    userInfo: ["message": errmsg])
                subject.processError(error)
            }
        }
        task.resume()
    }
}

extension String {
    // Escape special characters for URL parameter
    func urlEncode() -> String? {
        return self.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
    }
}

public class RestAPI: NSObject, RequestSubject {
    var requester: JSONRequester = DefaultRequester()

    /// Convert a dictionary of strings to a POST-ready data object.
    ///
    /// Dictionary key/value pairs are converted to `key=value`
    /// (with special characters encoded using HTML percent-escapes)
    /// and joined together using ampersands, as in `key1=value1&key2=value2`
    ///
    /// - parameter [String,: String] dictionary of values
    /// - returns: nil if one or more strings cannot be encoded
    func dictToPostData(values: [String: String]) -> NSData? {
        var list: [String] = []
        for (dkey, dval) in values {
            if let ekey = dkey.urlEncode() {
                if let eval = dval.urlEncode() {
                    list.append("\(ekey)=\(eval)")
                    continue
                }
            }

            return nil
        }

        let joined = list.joinWithSeparator("&")
        return joined.dataUsingEncoding(NSASCIIStringEncoding,
                                        allowLossyConversion: true)
    }

    /// Send a POST request to the url and return the result.
    ///
    /// - parameter NSURL: target URL
    /// - parameter NSData: data sent as part of the POST
    /// - returns: - `JSONResult.Success` if the call succeeded
    ///           - `JSONResult.Delayed` for asynchronous calls
    ///           - `JSONResult.Error` if there was a problem
    func restCall(url: NSURL, postData: NSData) -> JSONResult {
        return requester.request(self, url: url, postData: postData)
    }

    /// Convert accumulated JSON data into native data structures.
    ///
    /// - returns: - `JSONResult.Success` if the data was converted
    ///           - `JSONResult.Error` if there was a problem
    public func processData(data: NSData) {
        var jsonError: NSError?

        var rawResult: AnyObject?
        do {
            rawResult = try NSJSONSerialization.JSONObjectWithData(data, options:NSJSONReadingOptions.MutableContainers)
        } catch let error as NSError {
            print("Conversion failed: \(error)")
            jsonError = error
            rawResult = nil
        }
        if jsonError == nil {
            if let result = rawResult as? [String: AnyObject] {
                didReceiveResponse(result)
                return
            }
            let errmsg = "Could not convert response to dictionary"
            let error = NSError(domain: "LiveAPI", code: 6661,
                                userInfo: ["message": errmsg])
            didReceiveError(error)
            return
        }

        let bogus = NSString(data: data, encoding:NSUTF8StringEncoding)

        var errmsg: String
        if jsonError != nil {
            errmsg = "JSON \(bogus) error \(jsonError)"
        } else {
            errmsg = "Bad JSON string \(bogus)"
        }

        print("LiveAPI error \(errmsg)")
        let error = NSError(domain: "LiveAPI", code: 6662,
                            userInfo: ["message": errmsg])
        didReceiveError(error)
    }

    func processError(error: NSError) {
        didReceiveError(error)
    }

    /// Subclasses should override this function to process errors
    func didReceiveError(error: NSError) {
        preconditionFailure("Unimplemented")
    }

    /// Subclasses should override this function to process responses
    func didReceiveResponse(jsonData: [String: AnyObject]) {
        preconditionFailure("Unimplemented")
    }
}

protocol LiveAPIProtocol {
    func didReceiveError(error: NSError)
    func didReceiveResponse(results: [String: AnyObject])
}

public class LiveAPI: RestAPI {
    var rootURL: String
    var username: String
    var password: String
    var delegate: LiveAPIProtocol?

    /// Create a LiveAPI object.
    ///
    /// - parameter String: IceCubeLive username
    /// - parameter String: IceCubeLive password
    public init(rootURL: String, username: String, password: String) {
        self.rootURL = rootURL
        self.username = username
        self.password = password
    }

    /// Fetch the list of dropped DOMs for a run.
    ///
    /// - parameter Int: IceCube run number
    /// - returns: JSONResult
    func droppedDOMs(runNumber: Int) -> JSONResult {

        var cmd: String
        if rootURL.rangeOfString("localhost/~dglo") == nil {
            cmd = "dropped_dom_json"
        } else {
            cmd = "dropped_dom_json.py"
        }

        let fullURL = "\(rootURL)/\(cmd)/\(runNumber)/"
        let url: NSURL! = NSURL(string: fullURL)

        var postData: NSData
        if let pd = dictToPostData(["user": self.username,
                                    "pass": self.password])
        {
            postData = pd
        } else {
            return .Error(message: "Cannot encode username and/or password")
        }

        return restCall(url, postData: postData)
    }

    /// Pass error to delegate
    ///
    /// - parameter NSError: error returned by REST call
    override func didReceiveError(error: NSError) {
        NSOperationQueue.mainQueue().addOperationWithBlock {
            self.delegate?.didReceiveError(error)
        }
    }

    /// Pass response to delegate
    ///
    /// - parameter AnyObject: JSON response
    override func didReceiveResponse(jsondata: [String: AnyObject]) {
        NSOperationQueue.mainQueue().addOperationWithBlock {
            self.delegate?.didReceiveResponse(jsondata)
        }
    }
}
