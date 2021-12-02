//
//  ChatViewController.swift
//  Messenger
//
//  Created by Данил Фролов on 27.10.2021.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SwiftUI

struct Message: MessageType {
    public var sender: SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKind
}

extension MessageKind {
    var messageKindString: String {
        switch self {
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributed_text"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .linkPreview(_):
            return "link_preview"
        case .custom(_):
            return "custom"
        }
    }
}

struct Sender: SenderType {
    var photoURL: String
    var senderId: String
    var displayName: String
}

class ChatViewController: MessagesViewController {
    
    private var senderPhotoURL: URL?
    private var otherUserPhotoURL: URL?
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        return formatter
    }()
    
    public let otherUserEmail: String
    private let conversationId: String?
    public var isNewConversation = false
    
    private var messages = [Message]()
    
    private var selfSender: Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else { return nil }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        return Sender(photoURL: "",
                      senderId: safeEmail,
                      displayName: "Frolov Danil")
    }
    
    init(with email: String, id: String?) {
        self.otherUserEmail = email
        self.conversationId = id
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messagesLayoutDelegate = self
        messageInputBar.delegate = self
    }
    
    private func listenForMessages(id: String, shouldScrolToBottom: Bool) {
        DatabaseManager.shared.getAllMessagesForConversations(with: id) { [weak self] result in
            switch result {
            case .success(let messages):
                guard !messages.isEmpty else {
                    return
                }
                self?.messages = messages
                
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    
                    if shouldScrolToBottom {
                        self?.messagesCollectionView.scrollToLastItem()
                    }
                }
                
            case .failure(let error):
                print("failed to get messages: \(error)")
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        
        if let conversationId = conversationId {
            listenForMessages(id: conversationId, shouldScrolToBottom: true)
        }
    }
}

//MARK: - InputBar Delegate
extension ChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let selfSender = self.selfSender,
              let messageId = createMessageID() else {
                  return
              }
        
        let message = Message(sender: selfSender,
                              messageId: messageId,
                              sentDate: Date(),
                              kind: .text(text))
        
        //MARK: Send Message
        if isNewConversation {
            DatabaseManager.shared.createNewConversations(with: otherUserEmail, name: self.title ?? "User", firstMessage: message) { [weak self] success in
                if success {
                    print("message send")
                    self?.isNewConversation = false
                }
                else {
                    print("failed to send")
                    //wait
                }
            }
        }
        else {
            guard let conversationId = conversationId,
                  let name = self.title else {
                      return
                  }
            //append to existing conversation data
            DatabaseManager.shared.sendMessage(to: conversationId, name: name, with: otherUserEmail, newMessage: message) { success in
                if success {
                    print("message send")
                }
                else {
                    print("failed to send")
                }
            }
        }
        
        func createMessageID() -> String? {
            //date, otherUserEmail, SenderEmail, randomInt
            guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                return nil
            }
            
            let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
            
            let dateString = Self.dateFormatter.string(from: Date())
            let newIdentifier = "\(otherUserEmail)_\(safeCurrentEmail)_\(dateString)"
            
            return newIdentifier
        }
    }
}


//MARK: - Messages Delegate
extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    func currentSender() -> SenderType {
        if let sender = selfSender {
            return sender
        }
        fatalError("Self sender is nil, email should be cached")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            return .link
        }
        
        return .secondarySystemBackground
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let sender = message.sender
        
        if sender.senderId == selfSender?.senderId {
            if let curentUserImageURL = self.senderPhotoURL {
                avatarView.sd_setImage(with: curentUserImageURL, completed: nil)
            }
            else {
                guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                    return
                }
                
                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "images/\(safeEmail)_profile_picture.png"
                
                
                StorageManager.shared.downloadURL(for: "\(path)") { [weak self] result in
                    switch result {
                    case .success(let urlString):
                        let fileUrl = URL(string: urlString)
                        self?.senderPhotoURL = fileUrl
                        
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: fileUrl, completed: nil)
                        }
                        
                    case .failure(let error):
                        print("\(error)")
                    }
                }
            }
        }
        else {
            if let otherUserImageURL = self.otherUserPhotoURL {
                avatarView.sd_setImage(with: otherUserImageURL, completed: nil)
            } else {
                let safeEmail = DatabaseManager.safeEmail(emailAddress: otherUserEmail)
                let path = "images/\(safeEmail)_profile_picture.png"
                
                
                StorageManager.shared.downloadURL(for: "\(path)") { [weak self] result in
                    switch result {
                    case .success(let urlString):
                        let fileUrl = URL(string: urlString)
                        self?.otherUserPhotoURL = fileUrl
                        
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: fileUrl, completed: nil)
                        }
                    case .failure(let error):
                        print("\(error)")
                    }
                }
            }
        }
    }
}


