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

extension DatabaseManager {
    public func getData(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        database.child("\(path)").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        }
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
    public func createNewConversations(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> (Void)) {
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        
        let ref = database.child(safeEmail)
        
        database.child(safeEmail).observeSingleEvent(of: .value) { [weak self] snapshot in
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
                "name": name,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            let recipientNewConversationData: [String: Any] = [
                "id": conversationID,
                "other_user_email": safeEmail,
                "name": "Self",
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            // Update recipient user conversation entry
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value) { [weak self] snapshot in
                if var conversations = userNode["conversations"] as? [[String: Any]] {
                    // apend
                    conversations.append(recipientNewConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                }
                else {
                    // create
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipientNewConversationData])
                }
                updateConversationForCurentUser()
            }
            
             func updateConversationForCurentUser() {
                // Update curent user conversation entry
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
                        
                        self?.finishinCreatingConversation(name: name,
                                                           conversationId: conversationID,
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
                        
                        self?.finishinCreatingConversation(name: name,
                                                           conversationId: conversationID,
                                                           firstMessage: firstMessage,
                                                           completion: completion)
                    }
                }
            }
        }
    }
    
    public func finishinCreatingConversation(name: String, conversationId: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        //        "id": String
        //        "type": text, photo, video,
        //        "content": String,
        //        "date": Date(),
        //        "sender_email": String,
        //        "is_read": bool,
        
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
            "is_read": false,
            "name": name
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
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        print("\(email)/conversations")
        database.child("\(email)/conversations").observe(.value) { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap { dictionary in
                guard let conversationId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let isRead = latestMessage["is_read"] as? Bool,
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String else {
                          return nil
                      }
                let latestMessageObject = LatestMessage(date: date,
                                                        text: message,
                                                        isRead: isRead)
                return Conversation(id: conversationId,
                                    name: name,
                                    otherUserEmail: otherUserEmail,
                                    latestMessage: latestMessageObject)
            }
            
            completion(.success(conversations))
        }
    }
    
    /// Gets all messages for a given Conversations
    public func getAllMessagesForConversations(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        database.child("\(id)/messages").observe(.value) { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let messages: [Message] = value.compactMap { dictionary in
                guard let content = dictionary["content"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let messageId = dictionary["id"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let name = dictionary["name"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let type = dictionary["type"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString) else {
                          return nil
                      }
                
                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: messageId,
                               sentDate: date,
                               kind: .text(content))
            }
            
            completion(.success(messages))
        }
    }
    
    /// Sends a message with target conversation and message
    public func sendMessage(to conversation: String, message: Message, completion: @escaping (Bool) -> Void) {
        
    }
}


