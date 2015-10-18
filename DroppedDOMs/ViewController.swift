//
//  ViewController.swift
//  DroppedDOMs
//
//  Created by Dave Glowacki on 9/12/15.
//  Copyright © 2015 Dave Glowacki. All rights reserved.
//

import UIKit

class ViewController: UIViewController, LiveAPIProtocol {
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var runNumField: UITextField!
    @IBOutlet weak var tableView: UITableView!

    var dropped = DroppedDOMs()

    let usernameKey = "username"

    override func viewDidLoad() {
        super.viewDidLoad()
        if let user = NSUserDefaults.standardUserDefaults().stringForKey(usernameKey) {
            usernameField.text = user

            if let pass = Keychain.getString(user) {
                passwordField.text = pass
                runNumField.becomeFirstResponder()
            } else {
                passwordField.becomeFirstResponder()
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // LiveAPIProtocol method
    func didReceiveError(error: NSError) {
        showError("Error", error.localizedDescription)
    }

    func showError(title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        presentViewController(alert, animated: true, completion: nil)

    }

    @IBAction func query(sender: AnyObject) {
        guard let username = usernameField.text else {
            showError("Missing name", "Please enter user name")
            return
        }

        guard let password = passwordField.text else {
            showError("Missing password", "Please enter password for \(username)")
            return
        }

        guard let rnstr = runNumField.text else {
            showError("Missing run number", "Please enter run number")
            return
        }

        guard let runNum = Int(rnstr) else {
            showError("Bad run number", "Bad run number \(runNumField.text)")
            return
        }

        if username != "" {
            NSUserDefaults.standardUserDefaults().setObject(username, forKey: usernameKey)
            if !Keychain.setString(password, forKey: username) {
                showError("WARNING", "Cannot save password for user \(username)")
            }
        }

        let debug = true
        var rootURL: String
        if debug {
            rootURL = "http://localhost/~dglo/cgi-bin"
        } else {
            rootURL = "https://live.icecube.wisc.edu"
        }
        let live = LiveAPI(rootURL: rootURL, username: username, password: password)
        live.delegate = self
        live.droppedDOMs(runNum, immediately: false)
    }

    // LiveAPIProtocol method
    func didReceiveResponse(results: [String: AnyObject]) {
        dropped.load(results)
        print("Loaded \(dropped.count) dropped DOMs")
        tableView.reloadData()
    }
}

