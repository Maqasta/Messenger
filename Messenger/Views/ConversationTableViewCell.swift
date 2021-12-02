//
//  ConversationTableViewCell.swift
//  Messenger
//
//  Created by Данил Фролов on 28.11.2021.
//

import UIKit
import SDWebImage
import AVFoundation


class ConversationTableViewCell: UITableViewCell {

    static let indentifier = "ConversationTableViewCell"
    
    private let userImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 35
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private let userNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 21, weight: .semibold)
        return label
    }()
    
    private let userMessageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 19, weight: .regular)
        label.numberOfLines = 0
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(userImageView)
        contentView.addSubview(userNameLabel)
        contentView.addSubview(userMessageLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        userImageView.frame = CGRect(x: 25,
                                     y: 25,
                                     width: 70,
                                     height: 70)
        
        userNameLabel.frame = CGRect(x: userImageView.right + 15,
                                     y: 10,
                                     width: contentView.width - 40 - userImageView.height,
                                     height: (contentView.height - 20)/2)
        
        userMessageLabel.frame = CGRect(x: userImageView.right + 15,
                                        y: userNameLabel.bottom + 1,
                                        width: contentView.width - 40 - userImageView.height,
                                        height: (contentView.height - 20)/2)
    }
    
    public func configure(with model: Conversation) {
        self.userMessageLabel.text = model.latestMessage.text
        self.userNameLabel.text = model.name
        
        let path = "images/\(model.otherUserEmail)_profile_picture.png"
        StorageManager.shared.downloadURL(for: path) { [weak self] result in
            switch result {
            case .success(let stringURL):
                guard let url = NSURL(string: stringURL) as URL? else {
                    return
                }
                
                DispatchQueue.main.async {
                    self?.userImageView.sd_setImage(with: url, completed: nil)
                }
                
            case .failure(let error):
                print("failed to get image url\(error)")
            }
        }
    }
}
