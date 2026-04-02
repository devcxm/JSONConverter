//
//  FileDefaultConfigManager.swift
//  JSONConverter
//
//  Created by DevYao on 2020/8/29.
//  Copyright © 2020 DevYao. All rights reserved.
//

import Foundation

private let FILE_CACHE_CONFIG_KEY = "FILE_CACHE_CONFIG_KEY"
private let EDITOR_JSON_CACHE_KEY = "EDITOR_JSON_CACHE_KEY"

class FileCacheManager {
    private lazy var fileConfigDic: [String: String]? = {
        let dic = UserDefaults.standard.object(forKey: FILE_CACHE_CONFIG_KEY) as? [String: String]
        return dic
    }()
        
    static let shared: FileCacheManager = {
        let manager = FileCacheManager()
        return manager
    }()
    
    func configFile() -> File {
        let file = File(cacheConfig: fileConfigDic)
        return file
    }
    
    func updateConfigWithFile(_ file: File) {
        fileConfigDic = file.toCacheConfig()
        UserDefaults.standard.set(fileConfigDic, forKey: FILE_CACHE_CONFIG_KEY)
        UserDefaults.standard.synchronize()
    }
    
    func editorJSONCache() -> String {
        return UserDefaults.standard.string(forKey: EDITOR_JSON_CACHE_KEY) ?? ""
    }
    
    func updateEditorJSONCache(_ text: String) {
        UserDefaults.standard.set(text, forKey: EDITOR_JSON_CACHE_KEY)
        UserDefaults.standard.synchronize()
    }
}
