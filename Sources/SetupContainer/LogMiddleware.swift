//
//  File.swift
//  
//
//  Created by zhtg on 2023/4/15.
//

import Foundation
import Vapor
import VaporUtils

public struct LogMiddleware: AsyncMiddleware {
    
    public init() {
        
    }

    public func respond(to request: Vapor.Request, chainingTo next: any Vapor.AsyncResponder) async throws -> Vapor.Response {

        let start = currentDateDesc()

        // 发送到下个节点
        do {
            let response = try await next.respond(to: request)

            var log = "======Request Start \(start)======\n"
            log += "URL: \(request.url)\nMethod: \(request.method)\n"
            log += "Headers: \(request.headers)\n"
            if request.method != .GET {
                let data = request.body.data
                log += "Body: \(data.requireString(def: ""))\n"
            }
            log += "Response------>:\n"
            log += "Status: \(response.status)\n"
            log += "Headers: \(response.headers)\n"
            let buffer = response.body.buffer
            log += "Body: \(buffer.requireString(def: ""))\n"
            log += "======Request End \(currentDateDesc())======"

            // 收到response，进行打印
            print("\(log)")

            // 返回到下个节点
            return response
        } catch {
            var log = "======Request Start \(start)======\n"
            log += "URL: \(request.url)\nMethod: \(request.method)\n"
            if request.method != .GET {
                let data = request.body.data
                log += "body: \(data.requireString(def: ""))\n"
            }
            log += "Error->:\n \(error)\n"
            log += "======Request End \(currentDateDesc())======"
            // 打印Error
            print("\(log)")
            throw error
        }
    }
}
