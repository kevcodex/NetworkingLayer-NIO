//
//  File.swift
//  
//
//  Created by Kevin Chen on 4/15/23.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import AsyncHTTPClient
import NIOCore
import NIOHTTP1
import NetworkingLayerCore

public struct NetworkingLayerNIO: Networkable {
    
    public let client: HTTPClient
    
    public init(client: HTTPClient) {
        self.client = client
    }
    
    
    public func send<Request>(request: Request,
                              callbackQueue: DispatchQueue,
                              progressHandler: ProgressHandler?) async throws -> NetworkResponse where Request : NetworkRequest {
        
        guard let urlRequest = request.buildURLRequest() else {
            throw NetworkResponseError.badRequest(message: "Bad URL Request")
        }
        
        switch request.requestType {
        case .requestData:
            return try await handleDataRequest(for: urlRequest,
                                               acceptableStatusCodes: request.acceptableStatusCodes,
                                               callbackQueue: callbackQueue,
                                               progressHandler: progressHandler)
            
        case .download(_):
            fatalError()
            
            
        case .uploadMultipart(let body):
            return try await handleMulitpartRequest(for: urlRequest,
                                                    multipartBody: body,
                                                    acceptableStatusCodes: request.acceptableStatusCodes,
                                                    callbackQueue: callbackQueue,
                                                    progressHandler: progressHandler)
        }
    }
    
    public func send<Request>(request: Request, callbackQueue: DispatchQueue, progressHandler: ProgressHandler?, completion: @escaping (Result<NetworkResponse, NetworkResponseError>) -> Void) -> NetworkTask? where Request : NetworkRequest {
        fatalError()
    }
    
    public func send<Request>(codableRequest: Request, callbackQueue: DispatchQueue, progressHandler: ProgressHandler?, completion: @escaping (Result<ResponseObject<Request.Response>, NetworkResponseError>) -> Void) -> NetworkTask? where Request : CodableRequest {
        fatalError()
    }
    
    public func send<Request, C>(request: Request, codableType: C.Type, callbackQueue: DispatchQueue, progressHandler: ProgressHandler?) async throws -> ResponseObject<C> where Request : NetworkRequest, C : Decodable {
        let response = try await send(request: request,
                                      callbackQueue: callbackQueue,
                                      progressHandler: progressHandler)
        
        let decoder = JSONDecoder()
        let object = try decoder.decode(C.self, from: response.data)
        let responseObject = ResponseObject(object: object,
                                            statusCode: response.statusCode,
                                            data: response.data,
                                            request: response.request,
                                            httpResponse: response.httpResponse)
        
        return responseObject
    }
    
    public func send<Request, C>(request: Request, codableType: C.Type, callbackQueue: DispatchQueue, progressHandler: ProgressHandler?, completion: @escaping (Result<ResponseObject<C>, NetworkResponseError>) -> Void) -> NetworkTask? where Request : NetworkRequest, C : Decodable {
        fatalError()
    }
    
    public func cancelAll() {
        fatalError()
    }
    
    // MARK: - Handlers
    
    func handleDataRequest(for urlRequest: URLRequest,
                           acceptableStatusCodes: [Int],
                           callbackQueue: DispatchQueue,
                           progressHandler: ProgressHandler?) async throws -> NetworkResponse {
        guard let url = urlRequest.url,
              let method = urlRequest.httpMethod?.uppercased() else {
            throw NetworkResponseError.badRequest(message: "Bad URL Request")
        }
        
        var httpHeaders: HTTPHeaders = [:]
        if let headers = urlRequest.allHTTPHeaderFields?.compactMap({ ($0, $1) }) {
            httpHeaders = HTTPHeaders(headers)
        }
        
        var httpBody: HTTPClient.Body? = nil
        if let body = urlRequest.httpBody {
            httpBody = HTTPClient.Body.data(body)
        }
        
        let httpRequest = try HTTPClient.Request(url: url.absoluteString, method: .init(rawValue: method), headers: httpHeaders, body: httpBody)
        
        let httpResponse = try await client.execute(request: httpRequest).get()
        
        let code = Int(httpResponse.status.code)
        
        guard let body = httpResponse.body,
              let data = String(buffer: body).data(using: .utf8) else {
            throw GenericError(message: "Response Error")
        }
        
        let response = NetworkResponse(statusCode: code, data: data, request: urlRequest, httpResponse: nil)
        
        guard acceptableStatusCodes.contains(code) else {            
            let error = GenericError(message: "Invalid Status Code")
            
            throw NetworkResponseError.responseError(error, response: response)
        }
        
        return response
    }
    
    func handleMulitpartRequest(for urlRequest: URLRequest,
                                multipartBody: [MultipartData],
                                acceptableStatusCodes: [Int],
                                callbackQueue: DispatchQueue,
                                progressHandler: ProgressHandler?) async throws -> NetworkResponse {
        
        var urlRequest = urlRequest
        
        let mpData = AFMultipartFormData()
        for body in multipartBody {
            mpData.append(body.data, withName: body.name, fileName: body.fileName, mimeType: body.mimeType)
        }
        
        let finalData = try mpData.encode()
        
        urlRequest.setValue("multipart/form-data; boundary=\(mpData.boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = finalData
        
        return try await handleDataRequest(for: urlRequest, acceptableStatusCodes: acceptableStatusCodes, callbackQueue: callbackQueue, progressHandler: progressHandler)
    }
}
