//
//  LaunchpadState.swift
//  MiniPad
//

import SwiftUI
import Combine

class LaunchpadState: ObservableObject {
    static let shared = LaunchpadState()
    
    @Published var isExpanded: Bool = false
    @Published var isPinned: Bool = false
    
    func toggle() {
        withAnimation(AppSettings.shared.animationStyle.spring) {
            isExpanded.toggle()
            if !isExpanded {
                isPinned = false
            }
        }
    }
    
    func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }
        withAnimation(AppSettings.shared.animationStyle.spring) {
            isExpanded = expanded
            if !expanded {
                isPinned = false
            }
        }
    }
}
