// The Swift Programming Language
// https://docs.swift.org/swift-book

import Vapor

public func setupApplication(with config: SetupConfig) async throws {
    
    var env = try Environment.detect()
    try LoggingSystem.bootstrap(from: &env)
    
    let app = try await Application.make(env)
    
    do {
        try await configure(app, config: config)
    } catch {
        app.logger.report(error: error)
        try? await app.asyncShutdown()
        throw error
    }
    try await app.execute()
    try await app.asyncShutdown()
}
