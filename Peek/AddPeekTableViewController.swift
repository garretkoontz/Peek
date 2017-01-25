//
//  AddPeekTableViewController.swift
//  Peek
//
//  Created by Garret Koontz on 1/23/17.
//  Copyright © 2017 GK. All rights reserved.
//

import UIKit

class AddPeekTableViewController: UITableViewController {
    
    @IBOutlet weak var titleTextField: UITextField!
    
    @IBOutlet weak var peekTextView: UITextView!
    
    var image: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    @IBAction func addButtonTapped(_ sender: Any) {
        
        if let title = titleTextField.text,
            let text = peekTextView.text,
            let image = image {
            
            PeekController.sharedController.createPeek(title: title, caption: text, image: image, completion: nil)
            dismiss(animated: true, completion: nil)
            
        } else {
            presentErrorAlert()
        }
        
    }
    
    func presentErrorAlert() {
        let alertController = UIAlertController(title: "Missing information", message: "You need a title.", preferredStyle: .alert)
        
        let tryAgainAction = UIAlertAction(title: "Try Again", style: .cancel, handler: nil)
        alertController.addAction(tryAgainAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "embedPhotoSelect" {
            let embedVC = segue.destination as? PhotoSelectViewController
            embedVC?.delegate = self
        }
    }
    
}

extension AddPeekTableViewController: PhotoSelectViewControllerDelegate {
    func photoSelectViewControllerSelected(image: UIImage) {
        self.image = image
    }
}