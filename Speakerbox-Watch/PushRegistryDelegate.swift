/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main handler for PushKit events
*/

import Foundation
import CallKit
import PushKit
import Combine

class PushRegistryDelegate: NSObject {
    private let queue = DispatchSerialQueue(label: "VOIP-Queue")
    private lazy var pushRegistry = {
        PKPushRegistry(queue: self.queue)
    }()
    weak var providerDelegate: ProviderDelegate?
    
    var pushTokenPublisher = CurrentValueSubject<String, Never>("")
    
    init(providerDelegate: ProviderDelegate) {
        self.providerDelegate = providerDelegate
        super.init()
        
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.voIP]
        
        if let raw = pushRegistry.pushToken(for: .voIP) {
            let token = raw.reduce("") { $0 + String(format: "%02.2hhx", $1) }
            pushTokenPublisher.send(token)
        }
    }
}

extension PushRegistryDelegate: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials,
                      for type: PKPushType) {
        /*
         Store push credentials on the server for the active user.
         */
        let token = pushCredentials.token.reduce("") { $0 + String(format: "%02.2hhx", $1) }
        pushTokenPublisher.send(token)
        print("pushRegistry didUpdate: \(token)\n")
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("pushRegistry invalidated: \(type)\n")
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType, completion: @escaping () -> Void) {
        let dictionaryPayload = payload.dictionaryPayload
        print("dictionaryPayload: \(dictionaryPayload)\n")

        defer {
            completion()
        }

        guard type == .voIP
//            let uuidString = payload.dictionaryPayload["UUID"] as? String,
//            let handle = payload.dictionaryPayload["handle"] as? String,
//            payload.dictionaryPayload["hasVideo"] != nil,
//            let uuid = UUID(uuidString: uuidString)
            else {
                return
        }
        DispatchQueue.main.async {
            self.providerDelegate?.reportIncomingCall(uuid: UUID(), handle: "0987654321") { _ in
                SpeakerboxWatchApp.scheduleNotification()
            }
        }
    }
}
