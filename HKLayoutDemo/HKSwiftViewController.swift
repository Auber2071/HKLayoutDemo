//
//  HKSwiftViewController.swift
//  HKLayoutDemo
//
//  Created by hankai on 2021/12/27.
//  Copyright © 2021 Edward. All rights reserved.
//

import Alamofire
import UIKit

class HKSwiftViewController: HKOCViewController {
    let age = 1
    let name = "tom"
    
    override func viewDidLoad() {
        super.viewDidLoad()


        
        
        
        
        
    }

}

extension HKSwiftViewController {
    func test2() {
        
    }
}

//
//import AFNetworking
//import Foundation
//  
//class ChunkedUploader {
//      
//    private let sessionManager: AFHTTPSessionManager
//    private let fileURL: URL
//    private let uploadURL: URL
//    private let chunkSize: Int
//    private var currentChunk = 0
//    private var totalChunks: Int = 0
//    private var resumedData: Data?
//      
//    init(fileURL: URL, uploadURL: URL, chunkSize: Int = 1024 * 1024) {
//        self.fileURL = fileURL
//        self.uploadURL = uploadURL
//        self.chunkSize = chunkSize
//        self.sessionManager = AFHTTPSessionManager()
//        self.sessionManager.responseSerializer = AFHTTPResponseSerializer()
//    }
//      
//    func uploadFile() {
//        do {
//            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
//            let fileSize = fileAttributes[FileAttributeKey.size] as! UInt64
//            totalChunks = Int(ceil(Double(fileSize) / Double(chunkSize)))
//              
//            // 如果之前有保存的断点续传数据，则从断点处继续上传
//            if let resumedData = self.resumedData {
//                self.uploadChunk(data: resumedData, chunkIndex: currentChunk)
//            } else {
//                self.startUploading()
//            }
//        } catch {
//            print("Error getting file attributes")
//        }
//    }
//      
//    private func startUploading() {
//        if currentChunk < totalChunks {
//            self.uploadNextChunk()
//        } else {
//            print("All chunks uploaded successfully")
//            // 所有块上传完成后，通知服务器合并文件或进行其他操作
//        }
//    }
//      
//    private func uploadNextChunk() {
//        let chunkData = self.readChunkData()
//        if let data = chunkData {
//            self.uploadChunk(data: data, chunkIndex: currentChunk)
//        } else {
//            self.currentChunk += 1
//            self.startUploading()
//        }
//    }
//      
//    private func readChunkData() -> Data? {
//        do {
//            let fileHandle = try FileHandle(forReadingFrom: fileURL)
//            fileHandle.seek(toFileOffset: Int64(currentChunk * chunkSize))
//            let data = fileHandle.readData(ofLength: chunkSize)
//            return data.count > 0 ? data : nil
//        } catch {
//            print("Error reading chunk data")
//            return nil
//        }
//    }
//      
//    private func uploadChunk(data: Data, chunkIndex: Int) {
//        let request = AFHTTPRequestSerializer().multipartFormRequest(withMethod: .post, URLString: uploadURL.absoluteString, parameters: nil, constructingBodyWith: { (formData) in
//            formData.append(data, withName: "file", fileName: "chunk-\(chunkIndex).dat", mimeType: "application/octet-stream")
//        })
//          
//        let uploadTask = sessionManager.uploadTask(with: request, from: data, progress: nil, completionHandler: { (response, error) in
//            if error == nil {
//                self.currentChunk += 1
//                self.startUploading()
//            } else {
//                print("Error uploading chunk: \(error?.localizedDescription ?? "Unknown error")")
//                // 保存当前已上传的数据，以便后续断点续传
//                self.resumedData = data
//            }
//        })
//          
//        uploadTask.resume()
//    }
//      
//    // 调用此方法来保存当前上传进度，以便在应用程序关闭或崩溃后恢复上传
//    func saveProgress() {
//        // 这里可以将currentChunk和resumedData保存到用户默认、Keychain或其他持久化存储中
//    }
//      
//    // 调用此方法来恢复之前的上传进度
//    func resumeUpload() {
//        // 从持久化存储中恢复currentChunk和resumedData的值
//        // 然后调用uploadFile()继续上传
//    }
//}
//
//// 使用示例
//let file
