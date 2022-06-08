//
//  ComposableWeatherApp.swift
//  ComposableWeather
//
//  Created by William Lopez on 3/12/22.
//

import SwiftUI
import ComposableArchitecture


@main
struct ComposableWeatherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                store: Store(initialState: AppState(),
                             reducer: appReducer, environment: AppEnvironment(weatherClient: .live, mainQueue: .main))
            )
        }
    }
    
    init(){
        UITableView.appearance().backgroundColor = .clear
    }
}
