//
//  Keychain.swift
//  DroppedDOMs
//
//  Created by Dave Glowacki on 9/7/15.
//  Copyright © 2015 Dave Glowacki. All rights reserved.
//

import Foundation

public class Keychain {

    public class func getData(key: String) -> NSData? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = withUnsafeMutablePointer(&result) {
            SecItemCopyMatching(query, UnsafeMutablePointer($0))
        }

        if status == noErr {

            return result as? NSData
        }

        return nil
    }

    public class func getString(key: String) -> String? {
        if let data = getData(key) {
            if let str = NSString(data: data, encoding: NSUTF8StringEncoding) as String? {
                return str
            }
        }

        return nil
    }

    public class func setData(value: NSData, forKey key: String) -> Bool {
        let access = kSecAttrAccessibleWhenUnlocked as String

        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: value,
            kSecAttrAccessible as String: access,
        ]

        let qref = query as CFDictionaryRef
        SecItemDelete(qref)

        let status: OSStatus = SecItemAdd(qref, nil)

        return status == noErr
    }

    public class func setString(value: String, forKey key: String) -> Bool {
        if let vstr = value.dataUsingEncoding(NSUTF8StringEncoding) {
            return setData(vstr, forKey: key)
        }

        return false
    }
}
