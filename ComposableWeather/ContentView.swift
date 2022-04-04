//
//  ContentView.swift
//  ComposableWeather
//
//  Created by William Lopez on 3/12/22.
//

import SwiftUI
import ComposableArchitecture

struct AppState: Equatable {
    var locations: IdentifiedArrayOf<Location> = []
    var cities: [City] = []
    var cityQuery = ""
    var city: String = ""
    var state: String = ""
    var country: String = ""
    var requestInFlightCity: Location?
    var requestInFlightCity2: City?
    var measurements = ["Fahrenheit °F", "Celsius °C"]
    var selectedTemp: String = "Fahrenheit °F"
    var savedLocations: [Int] = []
    var lat: Double = 0
    var lon: Double = 0
    var completedCity: City?
    var isRefreshing: Bool = false
}

extension AppState {
    var searchCityState: SearchCityState {
        get {
            SearchCityState(cityQuery: self.cityQuery,
                            locations: self.locations,
                            cities: self.cities,
                            city: self.city,
                            state: self.state,
                            country: self.country,
                            requestInFlightCity: self.requestInFlightCity,
                            savedLocations: self.savedLocations,
                            lat: self.lat,
                            lon: self.lon,
                            completedCity: self.completedCity
                            
            )
        }
        set {
            self.cityQuery = newValue.cityQuery
            self.locations = newValue.locations
            self.cities = newValue.cities
            self.city = newValue.city
            self.state = newValue.state
            self.country = newValue.country
            self.requestInFlightCity = newValue.requestInFlightCity
            self.savedLocations = newValue.savedLocations
            self.lat = newValue.lat
            self.lon = newValue.lon
            self.completedCity = newValue.completedCity
        }
    }
}

enum AppAction: Equatable {
    case deleteCity(IndexSet)
    case searchCityView(SearchCityAction)
    case clearCities
    case scaleChanged(String)
    case updateWeather(City)
    case isRefreshing
    case weatherResponse(Result<LocationWeather, WeatherClient.Failure>)
}

struct AppEnvironment {
    var weatherClient: WeatherClient
    var mainQueue: AnySchedulerOf<DispatchQueue>
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine( Reducer { state, action, environment in
    switch action {
    case let .deleteCity(indexSet):
        state.cities.remove(atOffsets: indexSet)
        return .none
        
    case .searchCityView(_):
        return .none
        
    case .clearCities:
        state.cities = []
        return .none
        
    case let .scaleChanged(unit):
        state.selectedTemp = unit
        return .none
        
    case .isRefreshing:
        state.isRefreshing.toggle()
        return .none
        
    case let .updateWeather(city):
        
        return environment.weatherClient.weather(city.lat, city.lon)
        .receive(on: environment.mainQueue)
        .catchToEffect(AppAction.weatherResponse)

    case let .weatherResponse(.success(response)):
        
        if let row = state.cities.firstIndex(where: {$0.id == response.id}) {
            state.cities[row].farenheitTemp = response.farenheitTemp
            state.cities[row].celsiusTemp = response.celsiusTemp
            state.cities[row].imageIcon = response.imageIcon
        }
        return .none
        
    case let .weatherResponse(.failure(response)):
        return .none
    }
    
},  searchCityReducer.pullback(
    state: \AppState.searchCityState,
    action: /AppAction.searchCityView,
    environment: { SearchCityEnvironment(weatherClient: $0.weatherClient, mainQueue: $0.mainQueue)})
)

struct ContentView: View {
    let store: Store<AppState, AppAction>
    
    var body: some View {
        NavigationView {
            WithViewStore(self.store) { viewStore in
                List {
                    ForEach(viewStore.cities) { city in
                        CityTemperatureView(store: self.store, city: city)
                    }
                    .onDelete { viewStore.send(.deleteCity($0))}
                }
                .navigationTitle("Weather")
                .toolbar {
                    ToolbarItemGroup {
                        HStack {
                            Button(action: {
                                viewStore.send(.isRefreshing)
                                for city in viewStore.cities {
                                    viewStore.send(.updateWeather(city))
                                }
                                viewStore.send(.isRefreshing)                                
                            }) { Text("Refresh")}
                                .disabled(viewStore.isRefreshing)
                            
                            searchCityItem
                            configurationMenuItems
                        }
                    }
                }
            }
        }
    }
    
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
    
    var searchCityItem: some View {
        NavigationLink(destination: SearchCityView(store: self.store.scope(state: \.searchCityState, action: AppAction.searchCityView))){
            HStack {
                Image(systemName: "magnifyingglass")
                Text("Search City")
            }
            .padding(5)
            .background(Color.black)
            .foregroundColor(.white)
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
                .foregroundColor(.black)
        }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            store: Store(initialState: AppState(),
                         reducer: appReducer, environment: AppEnvironment(weatherClient: .live, mainQueue: .main)))
    }
}
