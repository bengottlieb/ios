//
//  FetchIssuesOperation.swift
//  FiveCalls
//
//  Created by Ben Scheirman on 1/31/17.
//  Copyright © 2017 5calls. All rights reserved.
//

import Foundation

fileprivate extension IssuesManager.Query {
    func queryString() -> String? {
        switch self {
        case .all:
            return "inactive=true"
        case .top(let location):
            return location?.locationValue.flatMap { "address=\($0)" }
        }
    }
}

class FetchIssuesOperation : BaseOperation {
    
    let query: IssuesManager.Query
    
    // Output properties.
    // Once the job has finished consumers can check one or more of these for values.
    var httpResponse: HTTPURLResponse?
    var error: Error?
    var issuesList: IssuesList?

    init(query: IssuesManager.Query) {
        self.query = query
    }
    
    lazy var sessionConfiguration = URLSessionConfiguration.default
    lazy var session: URLSession = {
        return URLSessionProvider.buildSession(configuration: self.sessionConfiguration)
    }()
    
    func buildIssuesURL() -> URL? {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "5calls.org"
        urlComponents.path = "/issues/"
        
        if let queryString = query.queryString() {
            urlComponents.query = queryString
        }
        
        return urlComponents.url
    }

    override func execute() {
        guard let url = buildIssuesURL() else {
            print("Invalid issues url")
            finish()
            return
        }

        let task = session.dataTask(with: url) { (data, response, error) in
            if let e = error {
                print("Error fetching issues: \(e.localizedDescription)")
            } else {
                self.handleResponse(data: data, response: response)
            }
            
            self.finish()
        }
        
        
        print("Fetching issues... \(url)")

        task.resume()
    }
    
    private func handleResponse(data: Data?, response: URLResponse?) {
        guard let data = data else {
            print("data was nil, ignoring response")
            return
        }
        guard let http = response as? HTTPURLResponse else {
            print("Response was not an HTTP URL response (or was nil), ignoring")
            return
        }
        
        print("HTTP \(http.statusCode)")
        httpResponse = http
        
        if http.statusCode == 200 {
            do {
                try parseIssues(data: data)
                
                if let list = issuesList {
                    print("Returned \(list.issues.count) issues with normalized location: \(list.normalizedLocation)")
                }
            } catch let e {
                print("Error parsing issues: \(e.localizedDescription)")
            }
        } else {
            print("Received HTTP \(http.statusCode)")
        }
    }
    
    private func parseIssues(data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? JSONDictionary else {
            return
        }
        
        issuesList = IssuesList(dictionary: json)
    }
}
