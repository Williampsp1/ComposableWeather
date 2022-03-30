//
//  ContentView.swift
//  ComposableWeather
//
//  Created by William Lopez on 3/12/22.
//

import SwiftUI
import ComposableArchitecture

struct City: Equatable, Identifiable {
    let id: Int
    var state: String
    var farenheitTemp: Int
    var celsiusTemp: Int
    var country: String
    var city: String
    var lat: Double
    var lon: Double
    var imageIcon: Image
}

struct AppState: Equatable {
    var locations: IdentifiedArrayOf<Location> = []
    var cities: [City] = []
    var cityQuery = ""
    var city: String = ""
    var state: String = ""
    var country: String = ""
    var requestInFlightCity: Location?
    var measurements = ["Fahrenheit °F", "Celsius °C"]
    var selectedTemp: String = "Fahrenheit °F"
    var savedLocations: [Int] = []
    var lat: Double = 0
    var lon: Double = 0
    var completedCity: City?
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

enum AppAction {
    case deleteCity(IndexSet)
    case searchCityView(SearchCityAction)
    case clearCities
    case scaleChanged(String)
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
    }
},  searchCityReducer.pullback(
    state: \AppState.searchCityState,
    action: /AppAction.searchCityView,
    environment: { SearchCityEnvironment(weatherClient: $0.weatherClient, mainQueue: $0.mainQueue)})
)

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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            store: Store(initialState: AppState(),
                         reducer: appReducer, environment: AppEnvironment(weatherClient: .live, mainQueue: .main)))
    }
}
