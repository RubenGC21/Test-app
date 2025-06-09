//
//  Test_appApp.swift
//  Test app
//
//  Created by Rubén Gómez on 02/06/25.
//
import SwiftUI
import Firebase

@main
struct TuApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
