//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Harshawardhan T V on 11/21/22.
//

import Foundation
import FirebaseDatabase
import MessageKit
import RNCryptor

let encryptionKEY = "$3N2@C7@pXp"

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    static func safeEmail(emailAddress: String)-> String{
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
        
    }
    
}

extension DatabaseManager{
    public static func encrypt(plainText : String, password: String) -> String {
        
        let data: Data = plainText.data(using: .utf8)!
        let encryptedData = RNCryptor.encrypt(data: data, withPassword: encryptionKEY)
        let encryptedString : String = encryptedData.base64EncodedString() // getting base64encoded string of encrypted data.
        return encryptedString
    }
    // Decrypt Function
    public static func decrypt(encryptedText : String, password: String) -> String {
        do  {
            guard let data: Data = Data(base64Encoded: encryptedText) else{
                return encryptedText
            } // Just get data from encrypted base64Encoded string.
            let decryptedData = try RNCryptor.decrypt(data: data, withPassword: password)
            let decryptedString = String(data: decryptedData, encoding: .utf8) // Getting original string, using same .utf8 encoding option,which we used for encryption.
            return decryptedString ?? ""
        }
        catch {
            return "FAILED"
        }
    }
}


extension DatabaseManager{
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) ->Void)
    {
        self.database.child("\(path)").observeSingleEvent(of: .value, with: {
            snapshot in guard let value = snapshot.value else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
}



extension DatabaseManager {
    
    public func userExists(with email:String, completion: @escaping ((Bool) -> Void)){
        
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        database.child(safeEmail).observeSingleEvent(of: .value, with: {snapshot in
            guard snapshot.value as? String != nil else {
                completion(false)
                return
            }
            completion(true)
        })
        
    }
    
    /// Inserts new user to db
    public func insertUser(with user: ChatAppUser,completion: @escaping (Bool) -> Void){
        database.child(user.safeEmail).setValue([
            "first_name":user.firstName,
            "last_name":user.lastName
        ], withCompletionBlock: {error,_ in
            guard error == nil else{
                print("failed to write to database")
                completion(false)
                return
            }
            self.database.child("users").observeSingleEvent(of: .value, with: {snapshot in
                if var usersCollection = snapshot.value as? [[String: String]] {
                    //append to user dictionary
                    let newElement = [
                        "name":user.firstName+" "+user.lastName,
                        "email":user.safeEmail
                    ]
                    usersCollection.append(newElement)
                    
                    self.database.child("users").setValue(usersCollection, withCompletionBlock: {error,_ in
                        guard error == nil else{
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
                else{
                    //create that array
                    let newCollection: [[String: String]] = [
                        [
                            "name":user.firstName+" "+user.lastName,
                            "email":user.safeEmail
                        ]
                    ]
                    self.database.child("users").setValue(newCollection, withCompletionBlock: {error,_ in
                        guard error == nil else{
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                    
                }
            })
        })
    }
    
    public func getAllUsers(completion: @escaping(Result<[[String:String]],Error>)->Void) {
        database.child("users").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [[String:String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
    }
    
    /*
     users =>[
     [
     "name" :
     "safe_email":
     ],
     [
     "name" :
     "safe_email":
     ]
     
     ]
     
     */
}

//Sending Messages
extension DatabaseManager {
    
    /*
     "dd"{
     "messages":[
     {
     id: "String"
     "type":text,photo,video
     "content":String,
     "date": Date()
     "sender_email": String,
     "isRead": true/false,
     }
     ]
     }
     
     convo=>[
     [
     [
     "conversation_id":dd
     "other_user_email":
     "latest_message": => {
     "date": Date()
     "latest_message": "message"
     "is_read": true/false
     ]
     ],
     ]
     
     */
    
    //Creates new convo
    public func createNewConversation(with otherUserEmail: String, name: String,firstMessage: Message, completion: @escaping (Bool)-> Void){
        
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentName = UserDefaults.standard.value(forKey: "name") as? String
        else{
            return
        }
        
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        
        let  ref = database.child("\(safeEmail)")
        ref.observeSingleEvent(of: .value, with: {[weak self]snapshot in
            guard var userNode = snapshot.value as? [String:Any] else {
                completion(false)
                print("User not found")
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            switch firstMessage.kind {
                
            case .text(let messageText):
                message = DatabaseManager.encrypt(plainText: messageText, password: encryptionKEY)
                
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
            
            let conversationId = "conversation_\(firstMessage.messageId)"
            let newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email":otherUserEmail,
                "name": name,
                "latest_message":[
                    "date":dateString,
                    "message":message,
                    "is_read": false
                ]
                
            ]
            
            let recipient_newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email":safeEmail,
                "name": currentName,
                "latest_message":[
                    "date":dateString,
                    "message":message,
                    "is_read":false
                ]
                
            ]
            
            
            //Update current user conversation entry
            //Update recipient conv entry
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: {[weak self]
                snapshot in
                if var conversations = snapshot.value as? [[String: Any]]{
                    //append
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversationId)
                    
                }
                else{
                    //creation
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
            })
            
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                ref.setValue(userNode, withCompletionBlock: {[weak self]error, _ in
                    guard error==nil else{
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name:name,conversationID: conversationId, firstMessage: firstMessage, completion: completion)
                })
            }
            else{
                //conversation array dows not exist
                userNode["conversations"] = [
                    newConversationData
                ]
                
                ref.setValue(userNode, withCompletionBlock: {[weak self]error, _ in
                    guard error==nil else{
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name:name,conversationID: conversationId, firstMessage: firstMessage, completion: completion)
                })
                
            }
            
        })
        
        
    }
    
    private func finishCreatingConversation(name: String,conversationID: String, firstMessage: Message, completion: @escaping (Bool) -> Void){
        //    {
        //               id: "String"
        //               "type":text,photo,video
        //               "content":String,
        //               "date": Date()
        //               "sender_email": String,
        //               "isRead": true/false,
        //        }
        
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
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
        
        guard let myEmail =  UserDefaults.standard.value(forKey: "email") as? String else{
            completion(false)
            return
        }
        
        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type":firstMessage.kind.MessageKindString,
            "content":message,
            "date":dateString,
            "sender_email":currentUserEmail,
            "is_read": false,
            "name": name
        ]
        let value : [String: Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        
        print("convo:\(conversationID)")
        database.child("\(conversationID)").setValue(value, withCompletionBlock: {
            error, _ in
            guard error == nil else{
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    //Return all conv for the user
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void){
        database.child("\(email)/conversations").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String:Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let conversations: [Conversation] = value.compactMap({dictionary in
                guard let conversationId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else{
                    return nil
                }
                
                print("This is for the Latest message")
                
                
                var decrypt_message = DatabaseManager.decrypt(encryptedText: message, password: encryptionKEY)
                
                if(decrypt_message==message){
                    decrypt_message="Image"
                }
                
                print("Decrypted \(decrypt_message)")
                let latestMessageObject = LatestMessage(date: date,
                                                        text: decrypt_message,
                                                        isRead: isRead)
                
                return Conversation(id: conversationId,
                                    name: name,
                                    otherUserEmail: otherUserEmail,
                                    latestMessage: latestMessageObject)
            })
            completion(.success(conversations))
        })
        
    }
    
    //get all messages for a convo
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>)-> Void){
        
        database.child("\(id)/messages").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String:Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let messages: [Message] = value.compactMap({dictionary in
                guard let name = dictionary["name"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let messageID = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let type = dictionary["type"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString)
                else{
                    return nil
                }
                print("\(content) is the message")
                
                var kind:MessageKind?
                if type=="photo"{
                    guard let imageUrl = URL(string: content),
                    let placeHolder =  UIImage(systemName: "plus") else{
                        return nil
                    }
                    let media = Media(url:imageUrl, image:nil,placeholderImage: placeHolder, size: CGSize(width: 300, height: 300))
                    kind = .photo(media)
                    
                }
                else{
                    guard let k = DatabaseManager.decrypt(encryptedText: content, password: encryptionKEY) as? String else {
                        kind = .text(content)
                    }
//                    print("Decrypted")
                    kind = .text(k)

                }
                guard let finalKind = kind else {
                    return nil
                }
                let sender = Sender(photoURL: "",
                                    senderId: senderEmail, displayName: name)
                
                return Message(sender: sender,
                               messageId: messageID,
                               sentDate: date,
                               kind: finalKind)
            })
            completion(.success(messages))
        })
        
        
    }
    
    //Sends a message with target convo
    
    public func sendMessage(to conversation: String, otherUserEmail:String, name: String,newMessage: Message, completion: @escaping (Bool) -> Void ) {
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            completion(false)
            return
        }
        let currentEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        database.child("\(conversation)/messages").observeSingleEvent(of: .value, with: {[weak self] snapshot in
            guard let strongSelf = self else {
                return
            }
            guard var currentMessages = snapshot.value as? [[String: Any]] else{
                completion(false)
                return
            }
            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            var message = ""
            switch newMessage.kind {
                
            case .text(let messageText):
                message = messageText
                
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString {
                    message = targetUrlString
                }
                break
            case .video(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString {
                    message = targetUrlString
                }
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
            
            guard let myEmail =  UserDefaults.standard.value(forKey: "email") as? String else{
                completion(false)
                return
            }
            
            let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
            
            
            
            let newMessageEntry: [String: Any] = [
                "id": newMessage.messageId,
                "type":newMessage.kind.MessageKindString,
                "content":message,
                "date":dateString,
                "sender_email":currentUserEmail,
                "is_read": false,
                "name": name
            ]
            
            currentMessages.append(newMessageEntry)
            
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessages,withCompletionBlock: {error,_ in
                guard error==nil else {
                    completion(false)
                    return
                }
                strongSelf.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value, with: {snapshot in
                    guard var currentUserConversations = snapshot.value as? [[String:Any]] else{
                        completion(false)
                        return
                    }
                    
                    let updatedValue: [String: Any] = [
                        "date":dateString,
                        "message":message,
                        "is_read":false
                    ]
                    
                    var targetConversation: [String:Any]?
                    var position = 0
                    
                    for conversationDictionary in currentUserConversations{
                        if let currentId = conversationDictionary["id"] as? String,currentId==conversation{
                            targetConversation = conversationDictionary
                            break
                        }
                        position+=1
                    }
                    targetConversation?["latest_message"] = updatedValue
                    guard let finalConversation = targetConversation else {
                        completion(false)
                        return
                    }
                    currentUserConversations[position] = finalConversation
                    strongSelf.database.child("\(currentUserEmail)/conversations").setValue(currentUserConversations, withCompletionBlock: {error,_ in
                        guard error==nil else{
                            completion(false)
                            return
                        }
                        
                        //Update latest Message for recipient
                        
                        strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: {snapshot in
                            guard var otherUserConversations = snapshot.value as? [[String:Any]] else{
                                completion(false)
                                return
                            }
                            
                            let updatedValue: [String: Any] = [
                                "date":dateString,
                                "message":message,
                                "is_read":false
                            ]
                            
                            var targetConversation: [String:Any]?
                            var position = 0
                            
                            for conversationDictionary in otherUserConversations{
                                if let currentId = conversationDictionary["id"] as? String,currentId==conversation{
                                    targetConversation = conversationDictionary
                                    break
                                }
                                position+=1
                            }
                            targetConversation?["latest_message"] = updatedValue
                            guard let finalConversation = targetConversation else {
                                completion(false)
                                return
                            }
                            otherUserConversations[position] = finalConversation
                            strongSelf.database.child("\(otherUserEmail)/conversations").setValue(otherUserConversations, withCompletionBlock: {error,_ in
                                guard error==nil else{
                                    completion(false)
                                    return
                                }
                                completion(true)
                            })
                        })
                    })
                })
            })
        })
    }
}



struct ChatAppUser{
    let firstName: String
    let lastName: String
    let emailAddress: String
    var safeEmail: String{
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    var profilePictureFileName: String{
        //        tvharshawardhan-gmail-com_profile_picture.png
        return "\(safeEmail)_profile_picture.png"
    }
}
