//
//  CityTemperatureView.swift
//  ComposableWeather
//
//  Created by William Lopez on 6/6/22.
//

import SwiftUI
import ComposableArchitecture

struct CityTemperatureView: View {
    let store: Store<AppState, AppAction>
    let city: City
    var body: some View {
        WithViewStore(self.store) { viewStore in
            HStack {
                VStack(alignment: .leading) {
                    Text(city.city)
                        .font(.headline)
                    
                    Group {
                        if city.state.isEmpty {
                            Text(city.country)
                        } else {
                            Text(city.state + ", " + city.country)
                        }
                    }
                    .font(.subheadline)
                }
                
                Spacer()
                
                if viewStore.selectedTemp.contains("Fahrenheit"){
                    Text("\(city.farenheitTemp) °F")
                } else {
                    Text("\(city.celsiusTemp) °C")
                }
                city.imageIcon
            }
        }
    }
}
