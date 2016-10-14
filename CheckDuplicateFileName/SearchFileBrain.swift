//
//  SearchFileBrain.swift
//  CheckSameFileName
//
//  Created by NixonShih on 2016/10/6.
//  Copyright © 2016年 Nixon. All rights reserved.
//

import Foundation

/**
 **SearchFileBrainDelegate**
 
 
 遵守這個 Protocol 可以觸發檔案監控事件
 
 - func foundDuplicateFile(brain: SearchFileBrain, duplicateFiles: [SearchResult]) 找到重複的檔案就會觸發這個 Protocol func
 - func searchFinish(brain: SearchFileBrain) 搜尋結束就會觸發這個 Protocol func
 - func searchError(brain: SearchFileBrain, errorMessage: String) 搜尋錯誤就會觸發這個 Protocol func
 
 */
protocol SearchFileBrainDelegate {
    /**
     找到重複的檔案就會觸發這個 Protocol func
     - parameter brain:             發送這個事件的 Instance
     - parameter duplicateFiles:    重複的檔案
     */
    func foundDuplicateFile(brain: SearchFileBrain, duplicateFiles: [SearchResult])
    /**
     搜尋結束就會觸發這個 Protocol func
     - parameter brain:             發送這個事件的 Instance
     */
    func searchFinish(brain: SearchFileBrain)
    /**
     搜尋錯誤就會觸發這個 Protocol func
     - parameter brain:             發送這個事件的 Instance
     - parameter errorMessage:      錯誤訊息
     */
    func searchError(brain: SearchFileBrain, errorMessage: String)
}

/**
 **SearchFileBrain**
 
 
 這個 Class 負責搜尋檔案的邏輯部分
 
 - 使用 startSearch() 進行檔案搜尋
 - Conform SearchFileBrainDelegate 來監控當案收尋的狀況
 
 */
class SearchFileBrain {
    
    /** 想要搜尋的路徑 */
    let directoryPath: String
    var excludeFolders: [String]
    var delegate: SearchFileBrainDelegate?
    private var searchResultStorage = [SearchResult]()
    private var cancelSearchFlag = false // 停止收尋為 True
    
    /**
     負責初始化 SearchFileBrain 這個 Class
     
     - parameter directoryPath: 想要搜尋的路徑
     - returns: SearchFileBrain's Instance
     */
    init(directoryPath: String,excludeFolders: [String]) {
        self.directoryPath = directoryPath
        self.excludeFolders = excludeFolders
    }
    
    /** 開始搜尋你所要求路徑的資料夾 */
    func startSearch() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.enumeratorDirectory()
        }
    }
    
    /** 停止搜尋 */
    func stopSearch() {
        cancelSearchFlag = true
    }
    
    // MARK: Private Methods
    
    // 開始對資料夾進行檢索比對
    private func enumeratorDirectory() {
        let fileManager = NSFileManager()
        let directoryURL = NSURL(string: directoryPath)
        let keys = [NSURLIsDirectoryKey]
        
        if let directoryURL = directoryURL {
            let enumerator = fileManager.enumeratorAtURL(directoryURL, includingPropertiesForKeys: keys, options:NSDirectoryEnumerationOptions.SkipsHiddenFiles,errorHandler: {aURL, aError in true})
            
            if let enumerator = enumerator {
                for fileURL in enumerator {
                    
                    if cancelSearchFlag { return }
                    
                    var isDir : ObjCBool = false
                    if fileManager.fileExistsAtPath(fileURL.path!, isDirectory: &isDir) {
                        if !isDir {
                            let aFileURL = fileURL as! NSURL
                            
                            if checkNeedExcludeOf(aFileURL.absoluteString) { continue }
                            
                            let theSearchResult = SearchResult(fileURL: aFileURL)
                            
                            if theSearchResult.fileName == ".DS_Store" {
                                continue
                            }
                            
                            var duplicateFiles = duplicateFilesInStorage(aFileURL)
                            
                            if duplicateFiles.count == 0 {
                                searchResultStorage.append(theSearchResult)
                            }else{
                                duplicateFiles.append(theSearchResult)
                                
                                dispatch_async(dispatch_get_main_queue(), {
                                    self.delegate?.foundDuplicateFile(self,duplicateFiles: duplicateFiles)
                                })
                            }
                        }
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), {
                    self.delegate?.searchFinish(self)
                })
                
            }
        }
    }
    
    // 比對有哪些檔案重複
    private func duplicateFilesInStorage(fileURL: NSURL) -> [SearchResult] {
        
        let fileName = fileURL.lastPathComponent
        return searchResultStorage.filter { $0.fileName == fileName! }
    }
    
    // 檢查路徑是否有在排除名單中
    private func checkNeedExcludeOf(path: String) -> Bool {
        
        if excludeFolders.count == 0 {
            return false
        }
        
        let filterResult = excludeFolders.filter { path.containsString($0) }
        
        return filterResult.count != 0
    }
    
}