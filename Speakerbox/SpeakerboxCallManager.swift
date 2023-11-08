/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The manager of SpeakerboxCalls, which demonstrates using a CallKit CXCallController to request actions on calls.
*/

import UIKit
import CallKit
import WatchConnectivity
import UserNotifications
import Combine

final class SpeakerboxCallManager: NSObject, ObservableObject, WCSessionDelegate {
    
    static let NotificationIdentifier = "NotificationIdentifier"
    
    let callController = CXCallController()
    
    @Published var active: Bool = false
    @Published var deactive: Bool = true
    @Published var activationState: Int = 0
    @Published var reachabilty: Bool = false
    
    var cancelBag = Set<AnyCancellable>()
    
    override init() {
        super.init()
        WCSession.default.delegate = self
        WCSession.default.activate()
        
        WCSession.default.publisher(for: \.activationState).receive(on: DispatchQueue.main).sink { value in
            
            switch value {
            case .activated:
                self.active = true
                self.deactive = false
            case .inactive:
                self.active = false
                self.deactive = false
            case .notActivated:
                self.active = false
                self.deactive = true
            default:
                break
            }
            self.activationState = value.rawValue
        }.store(in: &self.cancelBag)
        
        WCSession.default.publisher(for: \.isReachable).receive(on: DispatchQueue.main).sink { value in
            self.reachabilty = value
        }.store(in: &self.cancelBag)
        
#if !os(watchOS)
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            print("<--- \(WCSession.default.isWatchAppInstalled) | \(WCSession.default.isPaired)")
        }
        
#endif
        
    }

    // MARK: - Actions

    /// Starts a new call with the specified handle and indication if the call includes video.
    /// - Parameters:
    ///   - handle: The caller's phone number.
    ///   - video: Indicates if the call includes video.
    func startCall(handle: String, video: Bool = false) {
        let handle = CXHandle(type: .phoneNumber, value: handle)
        let startCallAction = CXStartCallAction(call: UUID(), handle: handle)

        startCallAction.isVideo = video

        let transaction = CXTransaction()
        transaction.addAction(startCallAction)

        requestTransaction(transaction)
    }

    /// Ends the specified call.
    /// - Parameter call: The call to end.
    func end(call: SpeakerboxCall) {
        let endCallAction = CXEndCallAction(call: call.uuid)
        let transaction = CXTransaction()
        transaction.addAction(endCallAction)

        requestTransaction(transaction)
    }

    /// Sets the specified call's on hold status.
    /// - Parameters:
    ///   - call: The call to update on hold status for.
    ///   - onHold: Specifies whether the call should be placed on hold.
    func setOnHoldStatus(for call: SpeakerboxCall, to onHold: Bool) {
        let setHeldCallAction = CXSetHeldCallAction(call: call.uuid, onHold: onHold)
        let transaction = CXTransaction()
        transaction.addAction(setHeldCallAction)

        requestTransaction(transaction)
    }

    /// Requests that the actions in the specified transaction be asynchronously performed by the telephony provider.
    /// - Parameter transaction: A transaction that contains actions to be performed.
    private func requestTransaction(_ transaction: CXTransaction) {
        callController.request(transaction) { error in
            if let error = error {
                print("Error requesting transaction:", error.localizedDescription)
            } else {
                print("Requested transaction successfully")
            }
        }
    }

    // MARK: - Call Management

    /// A publisher of active calls.
    @Published private(set) var calls = [SpeakerboxCall]()

    /// Returns the call with the specified UUID if it exists.
    /// - Parameter uuid: The call's unique identifier.
    /// - Returns: The call with the specified UUID if it exists, otherwise `nil`.
    func callWithUUID(uuid: UUID) -> SpeakerboxCall? {
        guard let index = calls.firstIndex(where: { $0.uuid == uuid }) else { return nil }

        return calls[index]
    }

    /// Adds a call to the array of active calls.
    /// - Parameter call: The call  to add.
    func addCall(_ call: SpeakerboxCall) {
        calls.append(call)
    }

    /// Removes a call from the array of active calls if it exists.
    /// - Parameter call: The call to remove.
    func removeCall(_ call: SpeakerboxCall) {
        guard let index = calls.firstIndex(where: { $0 === call }) else { return }

        calls.remove(at: index)
    }

    /// Empties the array of active calls.
    func removeAllCalls() {
        calls.removeAll()
    }
    
    func sendWatch() {
        
        self.reachabilty = WCSession.default.isReachable
        
        UNUserNotificationCenter.current().getPendingNotificationRequests { request in
            print("<--- PENDING : \(request.count)")
        }
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let content = UNMutableNotificationContent()
        content.title = "본체 본체 본체"
        content.subtitle = "받아져라얍얍얍"
        content.categoryIdentifier = SpeakerboxCallManager.NotificationIdentifier
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 0.1,
            repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger)
        
        UNUserNotificationCenter.current()
            .add(request)
        
        print("<-- sendWatch notification: \(SpeakerboxCallManager.NotificationIdentifier)")
        
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            switch activationState {
            case .activated:
                self.active = true
                self.deactive = false
            case .inactive:
                self.active = false
                self.deactive = false
            case .notActivated:
                self.active = false
                self.deactive = true
            default:
                break
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            print("<-- sessionReachabilityDidChange: \(session.isReachable)")
            self.reachabilty = session.isReachable
        }
    }
    
#if !os(watchOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        self.active = false
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        self.deactive = true
    }
#endif
    
#if os(watchOS)
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("<--- \(message)")
        
        SpeakerboxWatchApp.scheduleNotification()
        
        replyHandler(["Result": true])
    }
    
#endif
    
}
