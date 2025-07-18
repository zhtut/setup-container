import NIOSSL
import Fluent
import FluentPostgresDriver
import Leaf
import Vapor

public struct SetupError: Error {
    public var msg: String
}

public extension Application {
    
    struct Key: StorageKey {
        public typealias Value = SetupConfig
    }
    
    var setupConfig: SetupConfig? {
        get {
            self.storage[Key.self]
        }
        set {
            self.storage[Key.self] = newValue
        }
    }
}

// configures your application
public func configure(_ app: Application, config: SetupConfig) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    app.setupConfig = config
    
    // 配置工作目录
    try app.configureWorkDirectory(config.workingDirectory)
    
    // 配置数据库
    try app.configureDatabase()
    
    // 配置httpServer
    try app.configureHTTPServer()
    
    // 配置sessions
    try app.configureSessions()
    
    // 配置中间件
    try app.configureMiddleware()
    
    // 配置路由
    try app.configureRoutes()

    if config.isUsingLeaf {
        app.views.use(.leaf)
    }
    
    if let config = config.configHandler {
        try config(app)
    }
    
    // 自动注册migration
    try await app.autoMigrate()
}


public extension Application {
    /// 配置工作目录
    func configureWorkDirectory(_ path: String) throws {
#if os(macOS)
        let home = NSHomeDirectory()
        let workDirectory = home + path
        
        if !FileManager.default.fileExists(atPath: workDirectory) {
            try FileManager.default.createDirectory(atPath: workDirectory, withIntermediateDirectories: true)
        }
        
        // 配置工作目录
        directory = .init(workingDirectory: workDirectory)
#endif
        print("work directory: \(directory.workingDirectory)")
    }
}


public extension Application {
    /// 配置数据库
    func configureDatabase() throws {
        guard let setupConfig else {
            throw SetupError(msg: "没有config对象")
        }
        
        if !setupConfig.isUsingDatabase {
            return
        }
        
        // 配置数据库
        let hostName = Environment.get("DATABASE_HOST") ?? "localhost"
        let port = Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber
        let userName = Environment.get("DATABASE_USERNAME") ?? "zhtut"
        let password =  Environment.get("DATABASE_PASSWORD") ?? "Zaq145236-"
        let database = Environment.get("DATABASE_NAME") ?? setupConfig.databaseName
        let tls = PostgresConnection.Configuration.TLS.prefer(try .init(configuration: .clientDefault))
        let configuration = SQLPostgresConfiguration(hostname: hostName,
                                                     port: port,
                                                     username: userName,
                                                     password: password,
                                                     database: database,
                                                     tls: tls)
        databases.use(.postgres(configuration: configuration), as: .psql)
    }
}


public extension Application {
    /// 配置http相关的参数
    func configureHTTPServer() throws {
        guard let setupConfig else {
            throw SetupError(msg: "没有config对象")
        }
        let app = self
        // Add 'Server: vapor' header to responses.
        app.http.server.configuration.serverName = setupConfig.serverName
        
        // 支持的http版本，tls不支持的话，默认是http1，否则支持2个版本
        //    app.http.server.configuration.supportVersions = [.one, .two]
        
        // Configure custom port.
        app.http.server.configuration.port = setupConfig.port
        
        // config host
        //    #if DEBUG
        app.http.server.configuration.hostname = setupConfig.host
        //    #endif
        
        // 最大连接数
        app.http.server.configuration.backlog = 256
        
        // Enable HTTP response compression. 允许使用gzip来压缩数据，压缩buffer设置为1024
        app.http.server.configuration.responseCompression = .enabled(initialByteBufferCapacity: 1024)
        
        // Enable HTTP request decompression. No decompression size limit 允许请求压缩，设置为允许，无限制
        app.http.server.configuration.requestDecompression = .enabled(limit: .none)
        
        // Support HTTP pipelining.是否支持管道
        app.http.server.configuration.supportPipelining = true
    }
}

extension Application {
    
    /// 配置Session
    func configureSessions() throws {
        guard let setupConfig else {
            throw SetupError(msg: "没有config对象")
        }
        let app = self
        
        // 更改 cookie 名称为 ”foo“。
        app.sessions.configuration.cookieName = setupConfig.serverName
        
        // 配置 cookie 值创建。
        app.sessions.configuration.cookieFactory = { sessionID in
            HTTPCookies.Value(
                string: sessionID.string,
                expires: Date(
                    timeIntervalSinceNow: 60 * 60 * 24 * 7 // one week
                ),
                maxAge: nil,
                domain: "baseDomain",
                path: "/",
                isSecure: true,
                isHTTPOnly: false,
                sameSite: .strict
            )
        }
        
        // 使用数据库
        if setupConfig.isUsingDatabase {
            app.sessions.use(.fluent)
        } else {
            app.sessions.use(.memory)
        }
        
        // 最后，将 SessionRecord 迁移添加到数据库的迁移中。这将为在 _fluent_sessions 模式中存储会话数据准备好数据库。
        app.migrations.add(SessionRecord.migration)
        
        // sessions中间件
        app.middleware.use(app.sessions.middleware)
    }
}


public extension Application {
    func configureMiddleware() throws {
        guard let setupConfig else {
            throw SetupError(msg: "没有config对象")
        }
        let app = self
        
        // 错误
        let error = ErrorMiddleware.default(environment: app.environment)
        app.middleware.use(error)
        
        // 加上自定义的
        setupConfig.middlewares?.forEach { middleware in
            app.middleware.use(middleware)
        }
    }
}

public extension Application {
    
    /// 配置路由
    func configureRoutes() throws {
        guard let setupConfig else {
            throw SetupError(msg: "没有config对象")
        }
        let app = self
        
        // 配置文件上传最大尺寸
        app.routes.defaultMaxBodySize = "10mb"
        
        // 不区分大小写
        app.routes.caseInsensitive = false
        
        if let collections = setupConfig.routeCollections {
            for collection in collections {
                try app.routes.register(collection: collection)
            }
        }
        
        // 打印所有路由
        print("Routes Start------------")
        for route in app.routes.all.sorted(by: { $0.path.string < $1.path.string }) {
            print(route)
        }
        print("Routes End------------")
    }
}
