//
//  MainPeekViewController.swift
//  Peek
//
//  Created by Garret Koontz on 1/23/17.
//  Copyright © 2017 GK. All rights reserved.
//

import UIKit
import MessageUI
import MapKit
import CoreLocation

class PeekListTableViewController: UITableViewController, MFMailComposeViewControllerDelegate{
    
    var peek: Peek?
    
    let dimView = UIView()
    let dismissButton: UIButton = UIButton()
    
    @IBOutlet var menuView: UIView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        refreshControl?.tintColor = UIColor(red: 30/255, green: 215/255, blue: 96/255, alpha: 1.0)
        refreshControl?.backgroundColor = tableView.backgroundColor
        
        requestFullSync()
        
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(postsChanged(_:)), name: PeekController.PeeksChangedNotification, object: nil)
        
        LocationManager.sharedInstance.locationManager.requestWhenInUseAuthorization()
        LocationManager.sharedInstance.requestCurrentLocation()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        navigationController?.hidesBarsOnSwipe = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.menuView.removeFromSuperview()
        self.dimView.removeFromSuperview()
        self.dismissButton.removeFromSuperview()
        self.tableView.isScrollEnabled = true
    }
    
    @IBAction func indexChanged(_ sender: Any) {
        tableView.reloadData()
    }
    
    @IBAction func refreshControlPulled(_ sender: UIRefreshControl) {
        
        requestFullSync {
            self.refreshControl?.endRefreshing()
        }
    }
    
    @IBAction func composeButtonTapped(_ sender: Any) {
        composeButtonMenuAnimation()
    }
    
    @IBAction func exitButtonTapped(_ sender: Any) {
        exitComposeMenu()
    }
    
    func postsChanged(_ notification: Notification) {
        tableView.reloadData()
    }
    
    func requestFullSync(_ completion: (() -> Void)? = nil) {
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        PeekController.sharedController.performFullSync {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            completion?()
        }
    }
    
    //MARK: - TableViewDataSource and Delegate Functions
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var returnString = ""
        switch (segmentedControl.selectedSegmentIndex) {
        case 0:
            returnString = "Newest😄"
            break
        case 1:
            returnString = "Most Popular😎"
            break
        default:
            break
        }
        return returnString
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        view.tintColor = .clear
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = .black
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        var returnValue = 0
        
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            returnValue = PeekController.sharedController.sortedPeeksByTime.count
            break
        case 1:
            returnValue = PeekController.sharedController.sortedPeeksByNumberOfComments.count
            break
        default:
            break
        }
        return returnValue
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "peekCell", for: indexPath) as? PeekTableViewCell else { return UITableViewCell() }
        
        let bgColorView = UIView()
        bgColorView.backgroundColor = .white
        bgColorView.layer.cornerRadius = 4.0
    
        cell.selectedBackgroundView = bgColorView
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        
        let whiteRoundedView: UIView = UIView(frame: CGRect(x: 10, y: 8, width: self.view.frame.size.width - 20, height: cell.frame.size.height - 10))
        whiteRoundedView.layer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 1.0, 0.9])
        whiteRoundedView.layer.masksToBounds = false
        whiteRoundedView.layer.cornerRadius = 4.0
        cell.contentView.addSubview(whiteRoundedView)
        cell.contentView.sendSubview(toBack: whiteRoundedView)
        
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            let peek = PeekController.sharedController.sortedPeeksByTime[indexPath.row]
            cell.updateWithPeek(peek: peek)
            break
        case 1:
            let peek = PeekController.sharedController.sortedPeeksByNumberOfComments[indexPath.row]
            cell.updateWithPeek(peek: peek)
            break
        default:
            break
        }
        
        return cell
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let report = UITableViewRowAction(style: .default, title: "Report") { (action, index) in
            if MFMailComposeViewController.canSendMail() {
                
                let messageBody = "Specify the abuse or spam you saw from a user. Review the Terms & Conditions."
                let toRecipients = ["peekapp.contact@gmail.com"]
                let mc = MFMailComposeViewController()
                mc.mailComposeDelegate = self
                mc.setMessageBody(messageBody, isHTML: false)
                mc.setToRecipients(toRecipients)
                
                self.present(mc, animated: true, completion: nil)
                
            } else {
                self.presentErrorAlert()
            }
        }
        report.backgroundColor = .clear
        return [report]
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true, completion: nil)
    }
    
    func presentErrorAlert() {
        let errorAlert = UIAlertController(title: "Error Sending Email", message: "Check email configuration then try again.", preferredStyle: .alert)
        
        let dismissAction = UIAlertAction(title: "Dismiss", style: .cancel, handler: nil)
        errorAlert.addAction(dismissAction)
        
        present(errorAlert, animated: true, completion: nil)
    }

    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toComments" {
            if let indexPath = tableView.indexPathForSelectedRow {
                switch segmentedControl.selectedSegmentIndex {
                case 0:
                    let peek = PeekController.sharedController.sortedPeeksByTime[indexPath.row]
                    let commentsTVC = segue.destination as? CommentsTableViewController
                    commentsTVC?.peek = peek
                    break
                case 1:
                    let peek = PeekController.sharedController.sortedPeeksByNumberOfComments[indexPath.row]
                    let commentsTVC = segue.destination as? CommentsTableViewController
                    commentsTVC?.peek = peek
                    break
                default:
                    break
                }
            }
        }
    }
}

extension PeekListTableViewController {
    
    func composeButtonMenuAnimation() {
        self.view.addSubview(menuView)
        menuView.layer.frame = CGRect(x: 0, y: -100, width: view.frame.size.width, height: menuView.frame.size.height)
        menuView.layer.cornerRadius = 2
        
        dimView.frame = CGRect(x: view.frame.origin.x, y: view.frame.origin.y + 45, width: view.frame.size.width, height: view.frame.size.height)
        dimView.backgroundColor = UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 0.75)
        dimView.alpha = 0
        
        dismissButton.frame = CGRect(x: view.frame.origin.x, y: view.frame.origin.y, width: view.frame.size.width, height: view.frame.size.height - menuView.frame.size.height)
        dismissButton.addTarget(self, action: #selector(tapToExit(_:)), for: .touchUpInside)
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.75, options: .curveEaseIn, animations: {
            self.menuView.frame.origin.y = 0
            self.view.addSubview(self.dimView)
            self.view.addSubview(self.dismissButton)
            self.dimView.alpha = 0.75
            self.view.bringSubview(toFront: self.menuView)
            self.tableView.isScrollEnabled = false
        }, completion: nil)
    }
    
    func exitComposeMenu() {
        UIView.animate(withDuration: 0.2, animations: {
            self.menuView.frame.origin.y = self.view.frame.origin.y - 100
            self.dimView.alpha = 0
        }) { (_) in
            self.menuView.removeFromSuperview()
            self.dimView.removeFromSuperview()
            self.dismissButton.removeFromSuperview()
            self.tableView.isScrollEnabled = true
        }
    }
    
    func tapToExit(_ sender: UIButton) {
        exitComposeMenu()
    }
}
