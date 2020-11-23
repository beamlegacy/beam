//
//  Animation.swift
//  Beam
//
//  Created by Sebastien Metrot on 20/11/2020.
//

import Foundation
import Combine

enum AnimationState {
    case stopped
    case running
    case finished
}

class Animation {
    private var duration: CFTimeInterval
    private var currentTime: CFTimeInterval = 0
    private var scope: Cancellable?
    var easing: (CFTimeInterval) -> CFTimeInterval = { t in t }

    @Published var state: AnimationState = .stopped

    init(duration: CFTimeInterval) {
        self.duration = duration
    }

    func start(_ tickPublisher: AnyPublisher<Tick, Never>) {
        guard duration > 0 else {
            currentTime = 0
            update(1)
            state = .finished
            return
        }

        state = .running

        scope = tickPublisher.sink { [weak self] tick in
            guard let self = self else { return }
            self.advanceTime(by: tick.delta)
        }
    }

    func stop() {
        scope = nil
    }

    private func advanceTime(by value: CFTimeInterval) {
        if state == .running {
            currentTime += value
            guard currentTime < duration else {
                currentTime = duration
                _update()
                state = .finished
                return
            }

            _update()
        }
    }

    private func _update() {
        update(easing(currentTime / duration))
    }

    func update(_ value: CFTimeInterval) {
    }

    func interpolate<T: FloatingPoint>(_ start: T, _ end: T, _ t: T) -> T {
        return (start) + (end - start) * t
    }
}
