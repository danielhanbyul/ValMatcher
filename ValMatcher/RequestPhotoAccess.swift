//
//  RequestPhotoAccess.swift
//  ValMatcher
//
//  Created by Daniel Han on 8/31/24.
//

import Photos
import UIKit

func requestPhotoLibraryAccess() {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    switch status {
    case .authorized:
        print("Photo Library Access: Full access granted.")
        // Proceed with your app logic

    case .limited:
        print("Photo Library Access: Limited access granted. Requesting full access.")
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
            DispatchQueue.main.async {
                if newStatus == .authorized {
                    print("Photo Library Access: Full access granted.")
                } else {
                    print("Photo Library Access: User declined full access.")
                }
            }
        }

    case .denied, .restricted:
        print("Photo Library Access: Denied or restricted. Direct user to settings.")
        // Optionally, guide users to settings
        if let appSettingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(appSettingsURL)
        }

    case .notDetermined:
        print("Photo Library Access: Not determined. Requesting access.")
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
            DispatchQueue.main.async {
                if newStatus == .authorized {
                    print("Photo Library Access: Full access granted.")
                } else {
                    print("Photo Library Access: User declined full access.")
                }
            }
        }

    @unknown default:
        break
    }
}
