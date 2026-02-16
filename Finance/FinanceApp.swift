//
//  FinanceApp.swift
//  Finance
//
//

import SwiftUI
import UserNotifications
import AppIntents

@main
struct FinanceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared

    init() {
        FinanceAppShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Benutzer um Berechtigungen für Benachrichtigungen bitten
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Fehler bei der Berechtigungsanfrage: \(error.localizedDescription)")
            }
            
            if granted {
                print("Benachrichtigungen erlaubt.")
                self.scheduleWeeklyNotification()
            } else {
                print("Benachrichtigungen nicht erlaubt.")
            }
        }
        return true
    }

    func scheduleWeeklyNotification() {
        // Benachrichtigungsinhalt erstellen
        let content = UNMutableNotificationContent()
        content.title = "Finance"
        content.body = "Schulden eintreiben!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 20

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "weeklyNotification", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Fehler beim Planen der wöchentlichen Benachrichtigung: \(error.localizedDescription)")
            } else {
                print("Wöchentliche Benachrichtigung erfolgreich geplant.")
            }
        }
    }
}
