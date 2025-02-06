//
//  AlertPresenter.swift
//  PonderPaw
//
//  Created by Homer Quan on 2/6/25.
//

//
//  AlertPresenter.swift
//  PonderPaw
//
//  Created by Your Name on [Date].
//

import UIKit

class AlertPresenter {
    /// Presents an alert with the given title and message on the key window’s root view controller.
    static func showAlert(title: String, message: String) {
        // Obtain the key window's root view controller.
        guard let rootViewController = UIApplication.shared
            .connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else {
                print("Unable to find the root view controller.")
                return
        }
        
        // Create the alert controller.
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        // Present the alert on the main thread.
        DispatchQueue.main.async {
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }
}

extension UIWindowScene {
    /// Returns the key window for the scene.
    var keyWindow: UIWindow? {
        return windows.first(where: { $0.isKeyWindow })
    }
}
