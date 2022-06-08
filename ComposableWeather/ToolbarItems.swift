//
//  ToolbarItems.swift
//  ComposableWeather
//
//  Created by William Lopez on 6/6/22.
//

import SwiftUI
import ComposableArchitecture

struct ToolbarItems: View {
    let store: Store<AppState, AppAction>
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        WithViewStore(self.store) { viewStore in
            HStack {
                refresh
                searchCityItem
                configurationMenuItems
            }
        }
    }
    
    var refresh: some View {
        WithViewStore(self.store) { viewStore in
            Button(action: {
                viewStore.send(.isRefreshing)
                for city in viewStore.cities {
                    viewStore.send(.updateWeather(city))
                }
                viewStore.send(.isRefreshing)
            }) { Image(systemName: "arrow.clockwise.circle")
            }
            .disabled(viewStore.isRefreshing)
        }
    }
    
    var searchCityItem: some View {
        NavigationLink(destination: SearchCityView(store: self.store.scope(state: \.searchCityState, action: AppAction.searchCityView))){
            HStack {
                Image(systemName: "magnifyingglass")
                Text("Search City")
            }
            .padding(5)
            .background(colorScheme == .dark ? .white : .black)
            .foregroundColor(colorScheme == .dark ? .black : .white)
            .cornerRadius(15)
        }
    }
    
    var configurationMenuItems: some View {
        WithViewStore(self.store) { viewStore in
            Menu {
                Picker(
                    "Scale", selection: viewStore.binding(
                        get: \.selectedTemp,
                        send: AppAction.scaleChanged
                    )) {
                        ForEach(viewStore.measurements, id: \.self) {
                            Text($0)
                        }
                    }
                Button(action: {
                    viewStore.send(.clearCities)
                }) {
                    Text("Clear All")
                }
            }
        label: {
            Image(systemName: "gearshape")
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
        }
    }
}
