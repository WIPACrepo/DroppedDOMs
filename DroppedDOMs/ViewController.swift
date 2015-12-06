//
//  ViewController.swift
//  DroppedDOMs
//
//  Created by Dave Glowacki on 9/12/15.
//  Copyright © 2015 Dave Glowacki. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, LiveAPIProtocol {
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var runNumField: UITextField!
    @IBOutlet weak var tableView: UITableView!

    var dropped = DroppedDOMs()

    let usernameKey = "username"

    let textCellName = "DOMCell"

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

        tableView.delegate = self
        tableView.dataSource = self

        //Looks for single or multiple taps.
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: "dismissKeyboard")
        view.addGestureRecognizer(tap)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // LiveAPIProtocol method
    func didReceiveError(error: NSError) {
        var errstr = error.localizedDescription
        if let val = error.userInfo["message"] {
            errstr = "\(error.localizedDescription): \(val)"
        }
        showError("Error \(error.code)", errstr)
    }

    // UITapGestureRecognizer calls this when a non-UI tap happens
    func dismissKeyboard() {
        // Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
    }

    func showError(title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message,
                                      preferredStyle: .Alert)
        let okAction = UIAlertAction(title: "OK", style: .Default) { (action) in
            // ...
        }
        alert.addAction(okAction);

        presentViewController(alert, animated: true, completion: nil)

    }

    @IBAction func query(sender: AnyObject) {
        guard let username = usernameField.text else {
            showError("Missing name", "Please enter user name")
            return
        }

        guard let password = passwordField.text else {
            showError("Missing password",
                      "Please enter password for \(username)")
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

        // hide active keyboard
        view.endEditing(true)

        if username != "" {
            NSUserDefaults.standardUserDefaults()
              .setObject(username, forKey: usernameKey)
            if !Keychain.setString(password, forKey: username) {
                showError("WARNING",
                          "Cannot save password for user \(username)")
            }
        }

        let debug = false
        var rootURL: String
        if debug {
            rootURL = "http://localhost/~dglo/cgi-bin"
        } else {
            rootURL = "https://live.icecube.wisc.edu"
        }
        let live = LiveAPI(rootURL: rootURL, username: username,
                           password: password)
        live.delegate = self
        live.droppedDOMs(runNum)
    }

    // LiveAPIProtocol method
    func didReceiveResponse(results: [String: AnyObject]) {
        dispatch_async(dispatch_get_main_queue(), {
            self.dropped.load(results)
print("Loaded \(self.dropped.count) dropped DOMs")
            self.tableView.reloadData()
print("Reloaded \(self.tableView)")
        })
    }


    // UITableViewDataSource method
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    // UITableViewDataSource method
    func tableView(tableView: UITableView,
                   cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCellWithIdentifier(textCellName, forIndexPath: indexPath) as UITableViewCell

        let row = indexPath.row

        var colstr: String
        if row < 0 || row > dropped.count {
            colstr = "?? No data for row \(row)"
        } else if let dom = dropped.entry(row) {
            colstr = "\(dom.name) (\(dom.string)-\(dom.position))"
        } else {
            colstr = "?? No DOM for row \(row)"
        }

        cell.textLabel?.text = colstr

        return cell
    }

    // UITableViewDataSource method
    func tableView(tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int
    {
        return self.dropped.count
    }

    // UITableViewDelegate method
    func tableView(tableView: UITableView,
                   didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)

        let row = indexPath.row
        print("Selected \(row)")
        print("Row => \(self.dropped.entry(row))")
    }
}
