/*
 Copyright 2022 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import Foundation
import UIKit
import AEPServices

class QuickConnectManager {

    private let quickConnectService = QuickConnectService()
    private let parentExtension: Assurance
    private let LOG_TAG = "QuickConnectManager"

    init(assurance: Assurance) {
        parentExtension = assurance
    }

    func detectShakeGesture() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleShakeGesture),
                                               name: NSNotification.Name(AssuranceConstants.QuickConnect.SHAKE_NOTIFICATION_KEY),
                                               object: nil)
    }
    
    func createDevice(completion: @escaping (AssuranceNetworkError?)-> Void) {
        quickConnectService.registerDevice(clientID: parentExtension.clientID, orgID: parentExtension.getURLEncodedOrgID() ?? "changeme", completion: { error in
            // Let the view decide how to handle the completion
            completion(error)
            if error == nil {
                self.checkDeviceStatus()
            }
         })
     }
    
    func checkDeviceStatus() {
        
        guard let orgID = parentExtension.getURLEncodedOrgID() else {
            // log here
            Log.debug(label: LOG_TAG, "orgID is unexpectedly nil")
            return
        }
        quickConnectService.getDeviceStatus(clientID: parentExtension.clientID, orgID: orgID, completion: { [self] result in
            switch result {
            case .success((let sessionId, let token)):
                
                deleteDevice()
                self.quickConnectView.onSuccessfulApproval()
                //wss://connect%@.griffon.adobe.com/client/v1?sessionId=%@&token=%@&orgId=%@&clientId=%@
                let socketURL = String(format: AssuranceConstants.BASE_SOCKET_URL,
                                       self.parentExtension.environment.urlFormat,
                                       sessionId,
                                       token,
                                       orgID,
                                       self.parentExtension.clientID)

                guard let url = URL(string: socketURL) else {
                    return
                }
                
                self.parentExtension.assuranceSession?.connectToSocketWith(url: url)
                break
            case .failure(_):
                self.quickConnectView.onFailedApproval()
                    //self.registrationUI?.showStatus(status: "API failure to check the device status.")
                break
            }
            
        })
    }
    
    func deleteDevice() {
        guard let orgID = parentExtension.getURLEncodedOrgID() else {
            Log.debug(label: LOG_TAG, "orgID is unexpectedly nil")
            return
        }
        
        quickConnectService.deleteDevice(clientID: parentExtension.clientID, orgID: orgID, callback: { error in
            guard let error = error else {
                return
            }

            Log.debug(label: self.LOG_TAG, "Failed to delete device with error: \(error)")
        })

    }

    func cancelRetryGetDeviceStatus() {
        quickConnectService.shouldRetryGetDeviceStatus = false
    }
    

    @objc private func handleShakeGesture() {
        parentExtension.shouldProcessEvents = true
        parentExtension.invalidateTimer()
        quickConnectService.shouldRetryGetDeviceStatus = true
        DispatchQueue.main.async {
             self.quickConnectView.show()
        }
    }
}


#if DEBUG
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if(motion == UIEvent.EventSubtype.motionShake) {
            NotificationCenter.default.post(name: NSNotification.Name(AssuranceConstants.QuickConnect.SHAKE_NOTIFICATION_KEY),
                                            object: nil)
        }
    }
}
#endif
