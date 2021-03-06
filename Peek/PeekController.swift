//
//  PeekController.swift
//  Peek
//
//  Created by Garret Koontz on 1/24/17.
//  Copyright © 2017 GK. All rights reserved.
//

import UIKit
import CloudKit
import CoreLocation

extension PeekController {
    static let PeeksChangedNotification = Notification.Name("PeeksChangedNotification")
    static let PeekCommentsChangedNotification = Notification.Name("PeekCommentsChangedNotification")
    
}

class PeekController {
    static let sharedController = PeekController()
    
    var peeks = [Peek]() {
        didSet {
            DispatchQueue.main.async {
                let nc = NotificationCenter.default
                nc.post(name: PeekController.PeeksChangedNotification, object: nil)
            }
        }
    }
    
    var comments: [Comment] {
        return peeks.flatMap { $0.comments }
    }
    
    var sortedPeeksByTime: [Peek] {
        let sortedPeeks = peeks.filter { !$0.title.contains("#NSFW") }
        return sortedPeeks.sorted(by: { return $0.timestamp.compare($1.timestamp as Date) == .orderedDescending})
    }
    
    var sortedPeeksByNumberOfComments: [Peek] {
        let sortedPeeks = peeks.filter { !$0.title.contains("#NSFW") }
        return sortedPeeks.sorted(by: { return $0.comments.count > $1.comments.count})
    }
    
    var sortedCommentsByTime: [Comment] {
        return comments.sorted(by: { return $0.timestamp.compare($1.timestamp as Date) == .orderedDescending })
    }
    
    var sortedPeeksByNSFWContent: [Peek] {
        let nsfwPeeks = peeks.filter { $0.title.contains("#NSFW") }
        return nsfwPeeks.sorted(by: { return $0.timestamp.compare($1.timestamp as Date) == .orderedDescending})
    }
    
    func doSomething() {
        
    }
    var isSyncing: Bool = false
    
    var cloudKitManager = CloudKitManager()
    
    init() {
        
        cloudKitManager = CloudKitManager()
        performFullSync()
    }
    
    func iCloudUserIDAsync(complete: @escaping (_ instance: CKRecordID?, _ error: NSError?) -> ()) {
        let container = CKContainer.default()
        container.fetchUserRecordID() {
            recordID, error in
            if error != nil {
                print(error!.localizedDescription)
                complete(nil, error as NSError?)
            } else {
                print("fetched ID \(recordID?.recordName)")
                complete(recordID, nil)
            }
        }
    }
    
    func createPeekWithImage(title: String, image: UIImage, location: CLLocation, completion: ((Peek) -> Void)? = nil) {
        guard let data = UIImageJPEGRepresentation(image, 0.6) else { return }
        let peek = Peek(title: title, photoData: data, location: location)
        peeks.insert(peek, at: 0)
        
        cloudKitManager.saveRecord(CKRecord(peek)) { (record, error) in
            guard let record = record else { return }
            peek.cloudKitRecordID = record.recordID
            if let error = error {
                print("Error saving new peek to CloudKit: \(error)")
            }
            completion?(peek)
        }
    }
    
    func addComment(peek: Peek, commentText: String, completion: @escaping ((Comment) -> Void) = { _ in }) -> Comment {
        let comment = Comment(text: commentText, peek: peek)
        peek.comments.insert(comment, at: 0)
        
        cloudKitManager.saveRecord(CKRecord(comment)) { (record, error) in
            if let error = error {
                print("Error saving new comment to CloudKit: \(error)")
            }
            comment.cloudKitRecordID = record?.recordID
            completion(comment)
        }
            DispatchQueue.main.async {
                let nc = NotificationCenter.default
                nc.post(name: PeekController.PeekCommentsChangedNotification, object: peek)
            }
        return comment
    }
    
    private func recordsOf(type: String) -> [CloudKitSyncable] {
        switch type {
        case "Peek":
            return peeks.flatMap { $0 as CloudKitSyncable }
        case "Comment":
            return comments.flatMap { $0 as CloudKitSyncable }
        default:
            return []
        }
    }
    
    func syncedRecords(ofType type: String) -> [CloudKitSyncable] {
        return recordsOf(type: type).filter { $0.isSynced }
    }
    
    func unsyncedRecords(ofType type: String) -> [CloudKitSyncable] {
        return recordsOf(type: type).filter { !$0.isSynced }
    }
    
    func fetchNewRecords(ofType type: String, completion: @escaping (() -> Void) = { _ in }) {
        
        var referencesToExclude = [CKReference]()
        
        var predicate: NSPredicate
        
        referencesToExclude = self.syncedRecords(ofType: type).flatMap {$0.cloudKitReference }
        predicate = NSPredicate(format: "NOT(recordID IN %@)", argumentArray: [referencesToExclude])
        
        if referencesToExclude.isEmpty {
            predicate = NSPredicate(value: true)
        }
        
        cloudKitManager.fetchRecordsWithType(type, predicate: predicate, recordFetchedBlock: { (record) in
            switch type {
            case PeekKeys.recordType.rawValue:
                if let post = Peek(record: record) {
                    self.peeks.append(post)
                }
            case CommentKeys.recordType.rawValue:
                guard let postReference = record[CommentKeys.peekReference.rawValue] as? CKReference,
                    let comment = Comment(record: record) else { return }
                let matchingPeek = PeekController.sharedController.peeks.filter({$0.cloudKitRecordID == postReference.recordID}).first
                matchingPeek?.comments.append(comment)
            default:
                return
            }
            
        }) { (records, error) in
            if let error = error {
                print("Error fetching CloudKit records of type \(type): \(error)")
            }
            completion()
        }
        
    }
    
    func pushChangesToCloudKit(completion: @escaping ((_ success: Bool, Error?) -> Void) = { _,_ in }) {
        
        let unsavedPeeks = unsyncedRecords(ofType: PeekKeys.recordType.rawValue) as? [Peek] ?? []
        let unsavedComments = unsyncedRecords(ofType: CommentKeys.recordType.rawValue) as? [Comment] ?? []
        var unsavedObjectsByRecord = [CKRecord: CloudKitSyncable]()
        
        for peek in unsavedPeeks {
            let record = CKRecord(peek)
            unsavedObjectsByRecord[record] = peek
        }
        
        for comment in unsavedComments {
            let record = CKRecord(comment)
            unsavedObjectsByRecord[record] = comment
        }
        
        let unsavedRecords = Array(unsavedObjectsByRecord.keys)
        
        cloudKitManager.saveRecords(unsavedRecords, perRecordCompletion: { (record, error) in
            guard let record = record else { return }
            unsavedObjectsByRecord[record]?.cloudKitRecordID = record.recordID
            
        }) { (records, error) in
            let success = records != nil
            completion(success, error)
        }
        
    }
    
    func performFullSync(completion: @escaping (() -> Void) = { _ in }) {
        
        guard !isSyncing else {
            completion()
            return
        }
        
        isSyncing = true
        
        pushChangesToCloudKit { (success, error) in
            
            if success {
                self.fetchNewRecords(ofType: PeekKeys.recordType.rawValue) {
                    self.fetchNewRecords(ofType: CommentKeys.recordType.rawValue) {
                        self.isSyncing = false
                        completion()
                    }
                }
            }
        }
    }
}
