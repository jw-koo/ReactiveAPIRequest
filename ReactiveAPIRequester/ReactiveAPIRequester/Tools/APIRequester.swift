//
//  APIRequester.swift
//  ReactiveAPIRequester
//
//  Created by Jawon Koo on 2020/01/11.
//  Copyright © 2020 Jawon Koo. All rights reserved.
//

import ReactiveSwift
import Foundation
import NetworkExtension

//MARK: URL request with ReactiveSwift
// to-do: change print functions to OALog function
enum APIRequestError: Error {
    case FailedUrlSession
    case responseIsNot200
    case failedToParse(data: Data)
    case bodyIsNil
    case failedToDecrypt
}

protocol APIRequester {
    var logHeader: String { get }   // Header for OALog logging
    var header: [String: String]? { get }
    
    func request<T: Codable>(type: T.Type, with: URLRequest) -> SignalProducer<T, APIRequestError>
}
    
extension APIRequester {
    func request<T: Codable>(type: T.Type, with urlRequest: URLRequest) -> SignalProducer<T, APIRequestError> {
        print("\(logHeader)[APIRequester] network request called.")
        
        var urlRequest = urlRequest
        urlRequest.allHTTPHeaderFields = header
        
        return URLSession.shared.reactive
            .data(with: urlRequest)
            .mapError { error in
                print("\(self.logHeader)[APIRequester] error: \(error.localizedDescription)")
                return .FailedUrlSession
            }
            .attemptMap { data, response -> Result<T, APIRequestError> in
                guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                    print("\(self.logHeader)[APIRequester] error: response code is not 200.")
                    return .failure(APIRequestError.responseIsNot200)
                }
                
                guard let decodedData = try? JSONDecoder().decode(T.self, from: data) else {
                    print("\(self.logHeader)[APIRequester] error: failed to decode")
                    return .failure(.failedToParse(data: data))
                }

                return .success(decodedData)
            }
            .observe(on: UIScheduler())
    }
}

class CryptoAPIRequester: APIRequester {
    var logHeader: String
    var header: [String: String]?
    
    private var ivData: Data?
    private var keyData: Data?
    
    init(logHeader: String, header: [String: String]?) {
        self.logHeader = logHeader
        self.header = header
    }
    
    func request<T: Codable>(type: T.Type, with urlRequest: URLRequest, crypted: (Rx: Bool, Tx: Bool)) -> SignalProducer<T, APIRequestError> {
        print("\(self.logHeader)[APIRequester] crypto request called.")
        var urlRequest = urlRequest
        
        if crypted.Tx {
            guard let data = urlRequest.httpBody else { return SignalProducer<T, APIRequestError>(error: .bodyIsNil) }
            urlRequest.httpBody = encrypt(data: data)
            print("\(self.logHeader)[APIRequester] Tx data was encrypted.")
        }
        
        return request(type: type, with: urlRequest)
            .flatMapError{ error -> SignalProducer<T, APIRequestError> in
                switch error {
                case .failedToParse(let data):
                    if crypted.Rx {
                        guard let decryptedData = self.decrypt(data: data) else {
                            return SignalProducer<T, APIRequestError>(error: .failedToDecrypt)
                        }
                        
                        guard let decodedData = try? JSONDecoder().decode(T.self, from: decryptedData) else {
                            print("\(self.logHeader)[APIRequester] error: failed to decode")
                            return SignalProducer<T, APIRequestError>(error: .failedToParse(data: decryptedData))
                        }
                        
                        return SignalProducer<T, APIRequestError>(value: decodedData)
                    }
                    fallthrough
                default:
                    return SignalProducer<T, APIRequestError>(error: error)
                }
            }
    }
    
    func setCryptoData(ivData: Data, keyData: Data) {
        self.ivData = ivData
        self.keyData = keyData
    }
    
    private func encrypt(data: Data) -> Data? {
        return data // to-do : WIP
    }
    
    private func decrypt(data: Data) -> Data? {
        return data // to-do : WIP
    }
}
