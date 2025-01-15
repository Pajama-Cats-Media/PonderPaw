//
//  PlayerViewModel.swift
//  PonderPaw
//
//  Created by Homer Quan on 1/15/25.
//

import SwiftUI

class PlayerViewModel: ObservableObject {
    private let webEventController = WebEventController()
    
    func turnPage() {
        let message = #"""
        {
          "topic": "next_page"
        }
        """#
        webEventController.sendEvent(message)
    }
    
    // Expose webEventController safely
    var eventController: WebEventController {
        webEventController
    }
}
