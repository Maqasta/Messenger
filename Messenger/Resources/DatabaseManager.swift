//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Данил Фролов on 19.10.2021.
//

import Foundation
import FirebaseDatabase

final class DatabaseManager {
    static let shared = DatabaseManager()
    private let database = Database.database().reference()
    
    static func safeEmail(emailAddress: String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}

//MARK: - Account Manager
extension DatabaseManager {
    
    /// Checks if there was a user with the same mail
    public func userExists(with email: String,
                           completion: @escaping ((Bool)->Void)) {
        
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        
        database.child(safeEmail).observeSingleEvent(of: .value) { snapshot in
            guard snapshot.value as? String != nil else {
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    /// Inserts new user to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        database.child(user.safeEmail).setValue([
            "firstName": user.firstName,
            "lastName": user.lastName
        ]) { error, _ in
            guard error == nil else {
                completion(false)
                print("Failed to write to database")
                return
            }
            
            self.database.child("users").observeSingleEvent(of: .value) { snapshot in
                if var usersColection = snapshot.value as? [[String: String]] {
                    // append to user dictionary
                    usersColection.append([
                        "name": user.firstName + " " + user.lastName,
                        "email": user.safeEmail
                    ])
                    
                    self.database.child("users").setValue(usersColection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            print("Failed to write to database")
                            return
                        }
                        
                        completion(true)
                    }
                }
                else {
                    // create that array
                    let newCollection: [[String: String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                        ]
                    ]
                    
                    self.database.child("users").setValue(newCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            print("Failed to write to database")
                            return
                        }
                        
                        completion(true)
                    }
                }
            }
        }
    }
    
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
        database.child("users").observeSingleEvent(of: .value) { snapshot in
            
            guard let value = snapshot.value as? [[String:String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            completion(.success(value))
        }
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
    }
    
    /*
     users => [
         [
         "name":
         "safe_email":
         ],
         [
         "name":
         "safe_email":
         ].
     ]
     */
}

struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var safeEmail: String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    var profilePictureFileName: String {
        return "\(safeEmail)_profile_picture.png"
    }
}

//MARK: - Sending messages / conversations

extension DatabaseManager {
    
    /*
     
     "dadaldalm" {
         "messages": [
             {
                "id": String
                "type": text, photo, video,
                "content": String,
                "date": Date(),
                "sender_email": String,
                "isRead": bool,
             }
         ],
     }
     
     conversetions => [
         [
             "id":
             "other_user_email":
             "latest_message": = {
                 "date": Date()
                 "latest_message": "message"
                 "is_read": bool
             }
         ],
         [
             "id":
             "other_user_email":
             "latest_message": = {
                 "date": Date()
                 "latest_message": "message"
                 "is_read": bool
             }
         ].
     ]
     */
    
    /// Creates new conversations with target user email and first message sent
    public func createNewConversations(with otherUserEmail: String, firstMessage: Message, completion: @escaping (Bool) -> (Void)) {
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        
        let ref =  database.child(safeEmail)
        
        database.child(safeEmail).observeSingleEvent(of: .value) { snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("user not found")
                return
            }
            
            let messageData = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageData)
            
            var message = ""
            
            switch firstMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let conversationID = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String: Any] = [
                "id": conversationID,
                "other_user_email": otherUserEmail,
                "latest_message": [
                    "date": dateString,
                    "latest_message": message,
                    "is_read": false
                ]
            ]
            
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                // conversetion array exists for current user
                // you should append
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                
                ref.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    
                    self?.finishinCreatingConversation(conversationId: conversationID,
                                                      firstMessage: firstMessage,
                                                      completion: completion)
                }
            }
            else {
                // conversetion array does NOT exists
                // create it
                userNode["conversations"] = [
                    newConversationData
                ]
                
                ref.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    
                    self?.finishinCreatingConversation(conversationId: conversationID,
                                                      firstMessage: firstMessage,
                                                      completion: completion)
                }
            }
        }
    }
    
    public func finishinCreatingConversation(conversationId: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
//        "id": String
//        "type": text, photo, video,
//        "content": String,
//        "date": Date(),
//        "sender_email": String,
//        "isRead": bool,
        
        let messageData = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageData)
        
        var message = ""
        
        switch firstMessage.kind {
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let curentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        let colectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": curentUserEmail,
            "isRead": false,
        ]
        
        let value: [String: Any] = [
            "messages": [
                colectionMessage
            ]
        ]
        
        database.child(conversationId).setValue(value) { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            
            completion(true)
        }
    }
    
    /// Fetches and returns all conversations for the user with passed in email
    public func getAllConversations(for email: String, completion: @escaping (Result<String, Error>) -> Void) {
        
    }
    
    /// Gets all messages for a given Conversations
    public func getAllMessagesForConversations(with id: String, completion: @escaping (Result<String, Error>) -> Void) {
        
    }
    
    /// Sends a message with target conversation and message
    public func sendMessage(to conversation: String, message: Message, completion: @escaping (Bool) -> Void) {
        
    }
}


