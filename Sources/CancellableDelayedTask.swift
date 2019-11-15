//
//  CancellableDelayedTask.swift
//  Mendoza
//
//  Created by tomas on 14/11/2019.
//

import Foundation

class CancellableDelayedTask {
    var cancelled = false
    
    private var didRun = false
    private let synchQueue = DispatchQueue(label: String(describing: CancellableDelayedTask.self))
    private let delay: TimeInterval
    private let runQueue: DispatchQueue
    
    init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.runQueue = queue
    }
    
    func run(task: @escaping () -> Void ) {
        assert(didRun == false, "CancellableDelayedTask is one shot, create a new instance")
        didRun = true
        
        runQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self,
                  self.synchQueue.sync(execute: { self.cancelled }) == false else {
                return
            }
            
            task()
        }
    }

    func cancel() {
        synchQueue.sync { cancelled = true }
    }
}
