//
//  SetupConfig.swift
//  SetupContainer
//
//  Created by shutut on 2024/12/6.
//

import Foundation
@preconcurrency import Vapor
import Fluent

/// 程序启动配置
public struct SetupConfig: Sendable {
    
    /// 是否使用数据库
    public var isUsingDatabase = true
    
    /// 是否使用leaf
    public var isUsingLeaf = true
    
    /// 工作目录
    public var workingDirectory: String = ""
    
    /// 中间件
    public var middlewares: [Middleware]?
    
    /// 数据库对象迁移
    public var migrations: [Migration]?
    
    /// routes
    public var routeCollections: [RouteCollection]?
    
    /// 数据库表名
    public var databaseName = "Database"
    
    /// 服务名
    public var serverName = "app-server"
    
    /// 是否打印日志
    public var isLog: Bool = true
    
    /// 服务监听的ip
    public var host = "::"
    
    /// 服务监听的端口名
    public var port = 8080
    
    /// 其他配置
    public var configHandler: (@Sendable (Application) throws -> Void)?
    
    public init() {
        
    }
}
