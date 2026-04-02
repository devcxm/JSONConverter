//
//  MJExtensionBuilder.swift
//  JSONConverter
//
//  Created by yaow on 2022/5/11.
//  Copyright © 2022 vvkeep. All rights reserved.
//

import Foundation

class MJExtensionBuilder: BuilderProtocol {
    private func processedPropertyKey(_ keyName: String, strategy: PropertyStrategy) -> String {
        let processedOriginKey = strategy.processed(keyName)
        var processedKey = keyName.specialMappedKey ?? processedOriginKey
        if keyName.isPureNumber || keyName.isBoolLiteral || keyName.isReservedKeyword || keyName.isMathOperatorKey {
            processedKey = "key_\(processedKey)"
        }
        
        if processedKey.hasInitPrefix {
            processedKey = "p\(processedKey.uppercaseFirstChar())"
        }
        
        return processedKey
    }
    
    func isMatchLang(_ lang: LangType) -> Bool {
        return lang == .MJExtension
    }
    
    func propertyText(_ type: PropertyType, keyName: String, strategy: PropertyStrategy, maxKeyNameLength: Int, keyTypeName: String?) -> String {
        assert(!((type == .Dictionary || type == .ArrayDictionary) && keyTypeName == nil), " Dictionary type the typeName can not be nil")
        let tempKeyName = processedPropertyKey(keyName, strategy: strategy)
        switch type {
        case .String, .Null:
            return "@property (nonatomic, copy) NSString *\(tempKeyName);\n"
        case .Int:
            return "@property (nonatomic, strong) NSNumber *\(tempKeyName);\n"
        case .Float, .Double:
            return "@property (nonatomic, strong) NSNumber *\(tempKeyName);\n"
        case .Bool:
            return "@property (nonatomic, strong) NSNumber *\(tempKeyName);\n"
        case .Dictionary:
            return "@property (nonatomic, strong) \(keyTypeName!) *\(tempKeyName);\n"
        case .ArrayString, .ArrayNull:
            return "@property (nonatomic, copy) NSArray<NSString *> *\(tempKeyName);\n"
        case .ArrayInt, .ArrayFloat, .ArrayDouble, .ArrayBool:
            return "@property (nonatomic, copy) NSArray<NSNumber *> *\(tempKeyName);\n"
        case .ArrayDictionary:
            return "@property (nonatomic, copy) NSArray<\(keyTypeName!) *> *\(tempKeyName);\n"
        }
    }
    
    func contentParentClassText(_ clsText: String?) -> String {
        return StringUtils.isEmpty(clsText) ? ": NSObject" : ": \(clsText!)"
    }
    
    func contentText(_ structType: StructType, clsName: String, parentClsName: String, propertiesText: String, propertiesInitText: String?, propertiesGetterSetterText: String?) -> String {
        let tempPropertiesText = StringUtils.removeLastChar(propertiesText)
        return "\n@interface \(clsName) \(parentClsName)\n\n\(tempPropertiesText)\n\n@end\n"
    }
    
    func contentImplText(_ content: Content, strategy: PropertyStrategy, useKeyMapper: Bool) -> String {
        let frontReturnText = "    return @{"
        
        var propertyMapperText = ""
        if useKeyMapper {
            let propertyMapperList = content.properties.enumerated().map { (index, property) -> String in
                let keyName = processedPropertyKey(property.keyName, strategy: strategy)
                let numSpace = index == 0 ? "" : String.numSpace(count: frontReturnText.count)
                
                // --- 交换位置：将 keyName 作为 Key，property.keyName 作为 Value ---
                return "\(numSpace)@\"\(keyName)\": @\"\(property.keyName)\""
            }
            
            propertyMapperText = """
            \n+ (NSDictionary *)mj_replacedKeyFromPropertyName {
            \(frontReturnText)\n\(propertyMapperList.reversed().joined(separator: ",\n"))};
            }\n
            """
        }
        
        var firstArrayTypeFlag = true
        let arrayTypePropertyList = content.properties.compactMap { property -> String? in
            if property.type == .ArrayDictionary {
                let keyName = processedPropertyKey(property.keyName, strategy: strategy)
                let numSpace = String.numSpace(count: firstArrayTypeFlag ? 0 : frontReturnText.count)
                firstArrayTypeFlag = false
                return "\(numSpace)@\"\(keyName)\": [\(property.className) class]"
            } else {
                return nil
            }
        }
        
        var arrayPropertyText = ""
        if !arrayTypePropertyList.isEmpty {
            arrayPropertyText = """
                                \n+ (NSDictionary *)mj_objectClassInArray {
                                \(frontReturnText)\n\(arrayTypePropertyList.joined(separator: ",\n"))\n};
                                }\n
                                """
        }
        
        let result = """
                     \n@implementation \(content.className)\n \(propertyMapperText)\(arrayPropertyText)
                     @end\n
                     """
        return result
    }
    
    func fileSuffix() -> String {
        return "h"
    }
    
    func fileImplSuffix() -> String {
        return "m"
    }
    
    func fileImportText(_ rootName: String, contents: [Content], strategy: PropertyStrategy, prefix: String?) -> String {
        var tempStr = """
                    \n#import <Foundation/Foundation.h>
                    #import <MJExtension/MJExtension.h>\n
                    """
        for (i, content) in contents.enumerated() where i > 0 {
            let className = strategy.processed(content.className)
            tempStr += "\n@class \(className);"
        }
        
        tempStr += "\n"
        return tempStr
    }
    
    func fileExport(_ path: String, config: File, content: String, classImplContent: String?) -> [Export] {
        let filePath = "\(path)/\(config.rootName.className(withPrefix: config.prefix))"
        return [Export(path: "\(filePath).\(fileSuffix())", content: content), Export(path: "\(filePath).\(fileImplSuffix())", content: classImplContent!)]
    }
    
    func fileImplText(_ header: String, rootName: String, prefix: String?, contentCustomPropertyMapperTexts: [String]) -> String {
        var temp = header
        let rootClsName = rootName.className(withPrefix: prefix)
        temp += "\n#import \"\(rootClsName).h\"\n"
        
        for item in contentCustomPropertyMapperTexts {
            temp += item
        }
        
        return temp
    }
}

private extension String {
    var isPureNumber: Bool {
        guard !isEmpty else { return false }
        return rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }
    
    var hasInitPrefix: Bool {
        return hasPrefix("init")
    }
    
    var isBoolLiteral: Bool {
        return lowercased() == "true" || lowercased() == "false"
    }
    
    var isReservedKeyword: Bool {
        let lowercasedKey = lowercased()
        return lowercasedKey == "default" || lowercasedKey == "operator"
    }
    
    var isMathOperatorKey: Bool {
        return self == "+" || self == "-" || lowercased() == "x" || self == "/"
    }
    
    var specialMappedKey: String? {
        switch self {
        case "+":
            return "plus"
        case "-":
            return "minus"
        case "/":
            return "divide"
        case "x", "X":
            return "multiply"
        default:
            return nil
        }
    }
}
