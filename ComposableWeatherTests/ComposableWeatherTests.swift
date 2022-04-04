//
//  ComposableWeatherTests.swift
//  ComposableWeatherTests
//
//  Created by William Lopez on 3/12/22.
//

import XCTest
@testable import ComposableWeather
import ComposableArchitecture
import Combine
import SwiftUI

class ComposableWeatherTests: XCTestCase {
    let scheduler = DispatchQueue.test
    
    private let mockLocations: IdentifiedArrayOf<Location> = [
        Location(city: "omaha", lat: 42, lon: 43, country: "US", state: "NE"),
        Location(city: "Los Angeles", lat: 22, lon: 93, country: "US", state: "CA"),
        Location(city: "San Diego", lat: 41, lon: 13, country: "US", state: "CA")
    ]
    
    private let mockCities: [City] = [
        City(id: 1, state: "NE", farenheitTemp: 2, celsiusTemp: 3, country: "US", city: "Omaha", lat: 23, lon: 25, imageIcon: Image(systemName: "Bandage")),
        City(id: 5, state: "NE", farenheitTemp: 2, celsiusTemp: 3, country: "US", city: "Omaha", lat: 23, lon: 25, imageIcon: Image(systemName: "Bandage")),
        City(id: 8, state: "NE", farenheitTemp: 2, celsiusTemp: 3, country: "US", city: "Omaha", lat: 23, lon: 25, imageIcon: Image(systemName: "Bandage"))
    ]
        
    private let mockWeatherDescription: [LocationWeather.WeatherDescription] = [
        .init(id: 2, main: "dummy", description: "rainy", icon: .showerRain)
    ]
    
    private let mockMainTemp = LocationWeather.MainTemperature(temp: 22, feels_like: 22, temp_min: 22, temp_max: 22, pressure: 22, humidity: 22)
    
    private let mockMoreInfo = LocationWeather.MoreInfo(country: "US", sunrise: 1, sunset: 1)
    
    func testSearchAndClearQuery() {
        let store = TestStore(
            initialState: .init(),
            reducer: searchCityReducer,
            environment: SearchCityEnvironment(weatherClient: .failing, mainQueue: self.scheduler.eraseToAnyScheduler())
        )
        
        store.environment.weatherClient.searchCity = { _ in Effect(value: self.mockLocations)}
        store.send(.cityQueryChanged("A")) {
            $0.cityQuery = "A"
        }
        self.scheduler.advance(by: 0.3)
        store.receive(.locationResponse(.success(mockLocations))) {
            $0.locations = self.mockLocations
        }
        store.send(.cityQueryChanged("")) {
            $0.locations = []
            $0.cityQuery = ""
        }
    }
    
    func testSearchFailure() {
        let store = TestStore(
            initialState: .init(),
            reducer: searchCityReducer,
            environment: SearchCityEnvironment(weatherClient: .failing, mainQueue: self.scheduler.eraseToAnyScheduler())
        )
        
        store.environment.weatherClient.searchCity = { _ in Effect(error: .init())}
        
        store.send(.cityQueryChanged("Q")) {
            $0.cityQuery = "Q"
        }
        self.scheduler.advance(by: 0.3)
        store.receive(.locationResponse(.failure(.init())))
    }
    
    func testClearQueryCancelsInFlightSearchRequest() {
        let store = TestStore(
            initialState: .init(),
            reducer: searchCityReducer,
            environment: SearchCityEnvironment(weatherClient: .failing, mainQueue: self.scheduler.eraseToAnyScheduler())
        )
        
        store.environment.weatherClient.searchCity = { _ in Effect(value: self.mockLocations)}
        
        store.send(.cityQueryChanged("P")) {
            $0.cityQuery = "P"
        }
        self.scheduler.advance(by: 0.2)
        store.send(.cityQueryChanged("")){
            $0.cityQuery = ""
        }
        self.scheduler.run()
    }
    
    func testAddLocation() {
        let specialLocationWeather = LocationWeather(weather: mockWeatherDescription, main: mockMainTemp, name: "omaha", sys: mockMoreInfo, id: 1)
        let specialLocation = Location(city: "omaha", lat: 42, lon: 42, country: "US", state: "NE")
        
        let store = TestStore(
            initialState: .init(),
            reducer: searchCityReducer,
            environment: SearchCityEnvironment(weatherClient: .failing, mainQueue: self.scheduler.eraseToAnyScheduler())
        )
        store.environment.weatherClient.weather = { _,_ in Effect(value: specialLocationWeather)}
        
        store.send(.locationTapped(specialLocation)) {
            $0.requestInFlightCity = specialLocation

        }
        self.scheduler.advance()
        store.receive(.weatherResponse(.success(specialLocationWeather))) {
            let city = City(id: specialLocationWeather.id, state: "NE", farenheitTemp: specialLocationWeather.farenheitTemp, celsiusTemp: specialLocationWeather.celsiusTemp, country: "US", city: "omaha", lat: 42, lon: 42, imageIcon: specialLocationWeather.imageIcon)
            $0.completedCity = city
            $0.cities = [city]
            $0.requestInFlightCity = nil
        }
    }
    
    func testAddLocationFailure() {
        let store = TestStore(
            initialState: .init(),
            reducer: searchCityReducer,
            environment: SearchCityEnvironment(weatherClient: .failing, mainQueue: self.scheduler.eraseToAnyScheduler())
        )
        store.environment.weatherClient.weather = { _,_ in Effect(error: .init())}
        
        store.send(.locationTapped(mockLocations.first!)){
            $0.requestInFlightCity = self.mockLocations.first!
        }
        self.scheduler.advance()
        store.receive(.weatherResponse(.failure(.init()))) {
            $0.requestInFlightCity = nil
        }
    }
    
    func testDeleteCity() {
        let state = AppState(cities: mockCities)
        let store = TestStore(
            initialState: state,
            reducer: appReducer,
            environment: AppEnvironment(weatherClient: .failing, mainQueue: self.scheduler.eraseToAnyScheduler()))
        
        store.send(.deleteCity([1])){
            $0.cities = [
                $0.cities[0],
                $0.cities[2]]
        }
    }
    
    func testClearCities() {
        let state = AppState(cities: mockCities)
        let store = TestStore(
            initialState: state,
            reducer: appReducer,
            environment: AppEnvironment(weatherClient: .failing, mainQueue: self.scheduler.eraseToAnyScheduler()))
        
        store.send(.clearCities) {
            $0.cities = []
        }
    }
    
    func testScaleChanges() {
        let store = TestStore(
            initialState: .init(),
            reducer: appReducer,
            environment: AppEnvironment(weatherClient: .failing, mainQueue: self.scheduler.eraseToAnyScheduler()))
        
        store.send(.scaleChanged("Celsius °C")) {
            $0.selectedTemp = "Celsius °C"
        }
    }
    
    func testUpdateWeather() {
        let specialLocationWeather = LocationWeather(weather: mockWeatherDescription, main: mockMainTemp, name: "omaha", sys: mockMoreInfo, id: 1)
        let state = AppState(cities: mockCities)
        let store = TestStore(initialState: state, reducer: appReducer, environment: AppEnvironment(weatherClient: .failing, mainQueue: self.scheduler.eraseToAnyScheduler()))
        
        store.environment.weatherClient.weather = { _,_ in Effect(value: specialLocationWeather)}
        store.send(.isRefreshing) {
            $0.isRefreshing = true
        }
        store.send(.updateWeather(mockCities[0])) { _ in 

        }
        self.scheduler.advance()
        store.receive(.weatherResponse(.success(specialLocationWeather))){
            $0.cities[0].farenheitTemp = specialLocationWeather.farenheitTemp
            $0.cities[0].celsiusTemp = specialLocationWeather.celsiusTemp
            $0.cities[0].imageIcon = specialLocationWeather.imageIcon
        }
        store.send(.isRefreshing) {
            $0.isRefreshing = false
        }
    }
}
