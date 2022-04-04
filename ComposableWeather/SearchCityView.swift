//
//  SearchCityView.swift
//  ComposableWeather
//
//  Created by William Lopez on 4/3/22.
//

import SwiftUI
import ComposableArchitecture

struct SearchCityState: Equatable {
    var cityQuery = ""
    var locations: IdentifiedArrayOf<Location> = []
    var cities: [City] = []
    var city: String = ""
    var state: String = ""
    var country: String = ""
    var requestInFlightCity: Location?
    var savedLocations: [Int] = []
    var lat: Double = 0
    var lon: Double = 0
    var completedCity: City?
}

enum SearchCityAction: Equatable {
    case cityQueryChanged(String)
    case locationResponse(Result<IdentifiedArrayOf<Location>, WeatherClient.Failure>)
    case weatherResponse(Result<LocationWeather, WeatherClient.Failure>)
    case locationTapped(Location)
}

struct SearchCityEnvironment{
    var weatherClient: WeatherClient
    var mainQueue: AnySchedulerOf<DispatchQueue>
}

let searchCityReducer: Reducer<SearchCityState, SearchCityAction, SearchCityEnvironment> = Reducer { state, action, environment in
    switch action {
    case let .cityQueryChanged(query):
        struct SearchLocationId: Hashable {}
        
        state.cityQuery = query
        
        if query.isEmpty {
            state.locations = []
            state.completedCity = nil
            return .cancel(id: SearchLocationId())
        }
        
        return environment.weatherClient
            .searchCity(query)
            .debounce(id: SearchLocationId(), for: 0.3, scheduler: environment.mainQueue)
            .catchToEffect(SearchCityAction.locationResponse)
        
    case let .locationResponse(.success(response)):
        state.locations = response
        print(state.locations)
        return .none
        
    case .locationResponse(.failure):
        state.locations = []
        return .none
        
    case let .weatherResponse(.success(response)):
        guard let city = state.requestInFlightCity else {
            return .none
        }
        
        state.completedCity = City(id: response.id, state: city.actualState, farenheitTemp: response.farenheitTemp, celsiusTemp: response.celsiusTemp, country: city.country, city: city.city, lat: city.lat, lon: city.lon, imageIcon: response.imageIcon)
        
        guard let completedCity = state.completedCity else {
            return .none
        }
        
        state.cities.append(completedCity)
        state.requestInFlightCity = nil
        return .none
        
    case let .weatherResponse(.failure(response)):
        state.completedCity = nil
        state.requestInFlightCity = nil
        return .none
        
    case let .locationTapped(location):
        state.requestInFlightCity = location
        
        return environment.weatherClient.weather(location.lat, location.lon)
            .receive(on: environment.mainQueue)
            .catchToEffect(SearchCityAction.weatherResponse)
    }
}

struct SearchCityView: View {
    let store: Store<SearchCityState, SearchCityAction>
    
    var body: some View {
        WithViewStore(self.store) { viewStore in
            HStack {
                searchCityView
            }
            .padding()
            List {
                locationsView
            }
            .navigationTitle("Search City")
        }
    }
    
    var searchCityView: some View {
        WithViewStore(self.store) { viewStore in
            Image(systemName: "magnifyingglass")
            TextField("Chicago, New York....",
                      text: viewStore.binding(get: \.cityQuery, send: SearchCityAction.cityQueryChanged))
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
    }
    
    var locationsView: some View {
        WithViewStore(self.store) { viewStore in
            ForEach(viewStore.locations) { location in
                HStack {
                    VStack(alignment: .leading) {
                        Text(location.city)
                            .font(.headline)
                        
                        Group {
                            if location.actualState.isEmpty {
                                Text(location.countryName)
                            } else {
                                Text(location.actualState + ", " + location.countryName)
                            }
                        }
                        .font(.footnote)
                    }
                    
                    Spacer()
                    
                    if !viewStore.cities.contains(where: { $0.lat == location.lat && $0.lon == location.lon }) {
                        Button(action: { viewStore.send(.locationTapped(location))}) {
                            Text("Add")
                                .font(.footnote)
                        }
                        .buttonStyle(BlueButton())
                    } else {
                        Text("Added")
                    }
                }
            }
        }
    }
    
}
struct BlueButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(10)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 1.2 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

