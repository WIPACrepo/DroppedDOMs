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
    func appendData(_: NSData)
    func processData() -> JSONResult
    func processError(_: NSError)
}

protocol JSONRequester {
    func request(subject: RequestSubject, url: NSURL, postData: NSData) -> JSONResult
}

class DefaultRequester: JSONRequester {
    /// Send a POST request to the url and return the result.
    ///
    /// - parameter NSURL: target URL
    /// - parameter NSData: data sent as part of the POST
    /// - returns: - `JSONResult.Success` if the call succeeded
    ///           - `JSONResult.Delayed` for asynchronous calls
    ///           - `JSONResult.Error` if there was a problem
    func request(subject: RequestSubject, url: NSURL, postData: NSData) -> JSONResult {

        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        request.HTTPBody = postData
        request.setValue(String(postData.length), forHTTPHeaderField: "Content-Length")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        startAsynchronous(request, subject: subject)
   
        return .Delayed
    }
    
    func startAsynchronous(request: NSURLRequest, subject: RequestSubject) {
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) {
            (data, response, error) -> Void in
            if error != nil {
                subject.processError(error!)
            } else if data != nil {
                subject.appendData(data!)
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
    var data: NSMutableData = NSMutableData()
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
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }

        let joined = list.joinWithSeparator("&")
        return joined.dataUsingEncoding(NSASCIIStringEncoding, allowLossyConversion: true)
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
    
    /// Append next chunk of data to internal cache
    public func appendData(data: NSData) {
        self.data.appendData(data)
    }
    
    /// Convert accumulated JSON data into native data structures.
    ///
    /// - returns: - `JSONResult.Success` if the data was converted
    ///           - `JSONResult.Error` if there was a problem
    public func processData() -> JSONResult {
        var jsonError: NSError?

        var rawResult: AnyObject?
        do {
            rawResult = try NSJSONSerialization.JSONObjectWithData(self.data, options:NSJSONReadingOptions.MutableContainers)
        } catch let error as NSError {
            jsonError = error
            rawResult = nil
        }
        if jsonError == nil {
            if let result = rawResult as? [String: AnyObject] {
                return .Success(data: result)
            }
        }

        let bogus = NSString(data: self.data, encoding:NSUTF8StringEncoding)

        if jsonError != nil {
            return .Error(message: "JSON \(bogus) error \(jsonError)")
        }

        return .Error(message: "Bad JSON string \(bogus)")
        
    }

    func processError(error: NSError) {
        didReceiveError(error)
    }

    // NSURLConnection delegate method
    func connection(connection: NSURLConnection!, didFailWithError error: NSError!) {
        didReceiveError(error)
    }
    
    // NSURLConnection delegate method
    func connection(didReceiveResponse: NSURLConnection!, didReceiveResponse response: NSURLResponse!) {
        //New request so we need to clear the data object
        self.data = NSMutableData()
    }
    
    // NSURLConnection delegate method
    func connection(connection: NSURLConnection!, didReceiveData data: NSData!) {
        //Append incoming data
        self.data.appendData(data)
    }
    
    // NSURLConnection delegate method
    func connectionDidFinishLoading(connection: NSURLConnection!) {
        //Finished receiving data and convert it to a JSON object
        //var err: NSError
        let result = processData()
        switch result {
        case .Success(let data):
            didReceiveResponse(data)
        case .Delayed:
            print("Strange, processData() returned .Delayed")
        case .Error(let message):
            let error = NSError(domain: "LiveAPI", code: 666, userInfo: ["message": message])
            didReceiveError(error)
        }
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
    /// - parameter Bool: if `true`, synchronously fetch results
    /// - parameter Bool: if `true`, simulate fetch via Dave's CGI-BIN script
    /// - returns: JSONResult
    func droppedDOMs(runNumber: Int, immediately: Bool) -> JSONResult {
        
        let url: NSURL! = NSURL(string: "\(rootURL)/dropped_dom_json/\(runNumber)/")
        
        var postData: NSData
        if let pd = dictToPostData(["user": self.username, "pass": self.password]) {
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
        delegate?.didReceiveError(error)
    }

    /// Pass response to delegate
    ///
    /// - parameter AnyObject: JSON response
    override func didReceiveResponse(jsondata: [String: AnyObject]) {
        delegate?.didReceiveResponse(jsondata)
    }
}

