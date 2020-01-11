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
    case failedToParse
}

protocol APIRequester {
    var logHeader: String { get }   // Header for OALog logging
    
    func request<T: Codable>(type: T.Type, with: URLRequest) -> SignalProducer<T, APIRequestError>
}
    
extension APIRequester {
    func request<T: Codable>(type: T.Type, with request: URLRequest) -> SignalProducer<T, APIRequestError> {
        print("\(logHeader)[APIRequester] network request called.")
        
        return URLSession.shared.reactive
            .data(with: request)
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
                    return .failure(.failedToParse)
                }

                return .success(decodedData)
            }
            .observe(on: UIScheduler())
    }
}
