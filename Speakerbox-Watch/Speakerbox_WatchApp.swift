/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The main class for the Watch's SpeakerBox App
*/

import SwiftUI
import PushKit
import WatchKit
import Foundation
import UserNotifications

@main
struct SpeakerboxWatchApp: App {
    
    @WKApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @Environment(\.scenePhase) private var phase
    var callProvider = ProviderDelegate(callManager: SpeakerboxCallManager())
    var pushRegistry: PushRegistryDelegate
    
    @State var pushToken: String = ""
    
    init() {
        pushRegistry = PushRegistryDelegate(providerDelegate: callProvider)
    }
    
    var body: some Scene {
        
        WindowGroup {
            ContentView(token: pushToken, incomingCallback: { (handle: String, video: Bool) in
                callProvider.reportIncomingCall(uuid: UUID(), handle: handle, hasVideo: video) { _ in
    
                }
                
            }).onReceive(pushRegistry.pushTokenPublisher, perform: { value in
                pushToken = value
            })
            .background(Color.blue)
            .task {
                let center = UNUserNotificationCenter.current()
                _ = try? await center.requestAuthorization(
                    options: [.alert, .sound, .badge]
                )
            }
            .onContinueUserActivity("INStartCallIntent", perform: { userActivity in
                guard let handle = userActivity.startCallHandle else {
                    print("Could not determine start call handle from user activity: \(userActivity)")
                    return
                }

                guard let video = userActivity.isVideo else {
                    print("Could not determine video from user activity: \(userActivity)")
                    return
                }

                SpeakerboxCallManager().startCall(handle: handle, video: video)
            })
        }
        .onChange(of: phase) { newPhase in
            switch newPhase {
            case .active:
                // App became active
                print("<--- ACTIVE")
//                SpeakerboxWatchApp.scheduleNotification()
            case .inactive:
                // App became inactive
                print("<--- INACTIVE")
            case .background:
                // App is running in the background
                print("<--- BACKGROUND")
            @unknown default:
                // Fallback for future cases
                break
            }
        }
        
        WKNotificationScene(
            controller: NotificationController.self,
            category: SpeakerboxCallManager.NotificationIdentifier
        )
    }
    
    static func scheduleNotification() {
        
        print("<--- sample notification")
        let content = UNMutableNotificationContent()
        content.title = "Take Watch!"
        content.subtitle = "Take Watch sub"
        content.categoryIdentifier = SpeakerboxCallManager.NotificationIdentifier
        content.sound = .default
//        content.setValue("YES", forKeyPath: "shouldAlwaysAlertWhileAppIsForeground")

        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 0.1,
            repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger)
        
        UNUserNotificationCenter.current()
            .add(request)
    }
}

class AppDelegate: NSObject, WKApplicationDelegate {
    
    var notiDelegate = NotiDelegate()
    
    func applicationDidFinishLaunching() {
        print("<-- applicationDidFinishLaunching")
        WKApplication.shared().registerForRemoteNotifications()
        
        UNUserNotificationCenter.current().delegate = self.notiDelegate
    }
    
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        print("<-- Device token : \(deviceToken.reduce("") { $0 + String(format: "%02.2hhx", $1) })")
    }
    
    func didReceiveRemoteNotification(_ userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (WKBackgroundFetchResult) -> Void) {
        SpeakerboxWatchApp.scheduleNotification()
        completionHandler(.newData)
    }
}

class NotiDelegate: NSObject, UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("<--- didReceive :  \(response)")
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("<--- willPresent : \(notification)")
        completionHandler([.sound,.badge])
    }

}

struct NotificationViewModel {
    let title: String
    let subtitle: String
}

struct NotificationView: View {
    
    let viewModel: NotificationViewModel

    var body: some View {
        VStack {
            Text(viewModel.title).font(.title)
            Text(viewModel.subtitle).font(.subheadline)
        }
    }
}

final class NotificationController: WKUserNotificationHostingController<NotificationView> {
    
    override class var sashColor: Color? {
        return .yellow
    }
    
    var viewModel: NotificationViewModel?
    
    override var body: NotificationView {
        guard let viewModel = viewModel else {
            let model = NotificationViewModel(title: "Title", subtitle: "Content")
            return NotificationView(viewModel: model)
        }
        
        return NotificationView(viewModel: viewModel)
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        print("willActivate")
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        print("didDeactivate")
    }

    
    override func didReceive(_ notification: UNNotification) {
        print("<-- NotificationController notification : \(notification)")
        
        self.viewModel = NotificationViewModel(title: notification.request.content.title, subtitle: notification.request.identifier)
    }
}
