//
//  ConnectionPool.swift
//  Mendoza
//
//  Created by Tomas Camin on 27/01/2019.
//

import Foundation
import Shout

class ConnectionPool<SourceValue> {
    struct Source<Value> {
        let node: Node
        let value: Value
        let logger: ExecuterLogger?
    }
    
    private let sources: [Source<SourceValue>]
    private let syncQueue = DispatchQueue(label: String(describing: ConnectionPool.self))
    private var executers = [Executer]()
    
    init(sources: [Source<SourceValue>]) {
        self.sources = sources
    }
    
    func execute(block: @escaping (_ executer: Executer, _ source: Source<SourceValue>) throws -> Void) throws {
        var errors = [Swift.Error]()
        
        let group = DispatchGroup()
        for source in sources {
            group.enter()
            
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                guard let self = self else { return }
                
                do {
                    let executer = try source.node.makeExecuter(logger: source.logger)
                    self.syncQueue.sync { self.executers.append(executer) }
                    
                    try block(executer, source)
                } catch {
                    self.syncQueue.sync { errors.append(error) }
                }
                
                group.leave()
            }
        }
        
        group.wait()
        
        for error in errors {
            throw error
        }
    }
    
    func terminate() {
        executers.forEach { $0.terminate() }
    }
}

extension ConnectionPool.Source where Value == Void {
    init(node: Node, logger: ExecuterLogger?) {
        self.node = node
        self.value = ()
        self.logger = logger
    }
}
