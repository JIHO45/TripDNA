//
//  TripDNAApp.swift
//  TripDNA
//
//  Created by 박지호 on 7/24/26.
//

import SwiftUI

@main
struct TripDNAApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appDelegate.router)
                .task { await Subscription.finishUpdates() }
        }
    }
}
