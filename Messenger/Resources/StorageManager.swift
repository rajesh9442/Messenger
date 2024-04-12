//
//  StorageManager.swift
//  Messenger
//
//  Created by Harshawardhan T V on 11/23/22.
//

import Foundation
import FirebaseStorage

final class StorageManager{
    static let shared  = StorageManager()
    
    private let storage = Storage.storage().reference()
    
    /*
     /images/tvharshawardhan-gmail-com_profile_picture.png
     */
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    
    //Uploads picture to firebase storage and returns completion with url string to download
    public func uploadProfilePicture(with data:Data,filename:String,completion:@escaping UploadPictureCompletion){
        storage.child("images/\(filename)").putData(data, metadata: nil,completion: { metadata, error in
            guard error==nil else{
                print("Failed")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self.storage.child("images/\(filename)").downloadURL(completion: {url,error in
                guard let url = url else {
                    print("Failed To Get Download URL")
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
                let urlString = url.absoluteString
                print("download url \(urlString)")
                completion(.success(urlString))
            })
        })
        
        
        
    }
    //upload image that will be sent in a conversation message
    public func uploadMessagePhoto(with data:Data,filename:String,completion:@escaping UploadPictureCompletion){
        storage.child("message_images/\(filename)").putData(data, metadata: nil,completion: { [weak self]metadata, error in
            guard error==nil else{
                print("Failed")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self?.storage.child("message_images/\(filename)").downloadURL(completion: {url,error in
                guard let url = url else {
                    print("Failed To Get Download URL")
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
                let urlString = url.absoluteString
                print("download url \(urlString)")
                completion(.success(urlString))
            })
        })
        
        
        
    }

    //Upload video
    public func uploadMessageVideo(with fileURL:URL,filename:String,completion:@escaping UploadPictureCompletion){
        storage.child("message_videos/\(filename)").putFile(from: fileURL, metadata: nil,completion: { [weak self]metadata, error in
            guard error==nil else{
                print("Failed to upload video")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self?.storage.child("message_videos/\(filename)").downloadURL(completion: {url,error in
                guard let url = url else {
                    print("Failed To Get Download URL")
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
                let urlString = url.absoluteString
                print("download url \(urlString)")
                completion(.success(urlString))
            })
        })
    }
    
    public enum StorageErrors: Error {
        case failedToUpload
        case failedToGetDownloadURL
    }
    
    public func downloadURL(for path: String, completion: @escaping (Result<URL,Error>) -> Void){
        let reference = storage.child(path)
        reference.downloadURL(completion: {url,error in
            guard let url = url, error == nil else{
                completion(.failure(StorageErrors.failedToGetDownloadURL))
                return
            }
            completion(.success(url))
        })
    }
    
}
