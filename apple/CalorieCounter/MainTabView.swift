//
//  MainTabView.swift
//  iOS 26 tab bar (Liquid Glass) over the three primary screens. The tab bar
//  minimizes on scroll-down for a content-forward feel.
//

import SwiftUI

struct MainTabView: View {
    enum Screen: Hashable { case today, history, settings }
    @State private var selection: Screen = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-screen-history") { return .history }
        if args.contains("-screen-settings") { return .settings }
        return .today
    }()

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "fork.knife", value: Screen.today) {
                TodayView()
            }
            Tab("History", systemImage: "chart.bar.xaxis", value: Screen.history) {
                HistoryView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: Screen.settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
