//
//  WeatherClient.swift
//  ComposableWeather
//
//  Created by William Lopez on 3/13/22.
//

import Foundation
import ComposableArchitecture
import SwiftUI

private var apiKey: String = "1f3e31b4cdc18fd0785da5bd61117a14"
private var searchResultLimit = "15"
private var unitOfMeasurement = "imperial"

struct Location: Decodable, Equatable, Identifiable  {
    var city: String
    var lat: Double
    var lon: Double
    var country: String
    var state: String?
    let id = UUID()
    
    var actualState: String {
        return state ?? ""
    }
    
    var countryName: String {
        return Locale(identifier: "en_US").localizedString(forRegionCode: country) ?? country
    }
    
    enum CodingKeys: String, CodingKey {
        case city = "name"
        case lat, lon, country, state
    }
    
}

struct LocationWeather: Decodable, Equatable, Identifiable {
    let weather: [WeatherDescription]
    let main: MainTemperature
    let name: String
    let sys: MoreInfo
    let id: Int
    
    struct WeatherDescription: Decodable, Equatable   {
        let id: Int
        let main: String
        let description: String
        let icon: WeatherDescription.Icon
    }
    
    struct MainTemperature: Decodable, Equatable  {
        let temp: Double
        let feels_like: Double
        let temp_min: Double
        let temp_max: Double
        let pressure: Double
        let humidity: Double
    }
    
    struct MoreInfo: Decodable, Equatable {
        var country: String
        var sunrise: Int
        var sunset: Int
    }
}

struct WeatherClient {
    var searchCity: (String)-> Effect<IdentifiedArrayOf<Location>, Failure>
    var weather: (Double, Double) -> Effect<LocationWeather,Failure>
    
    struct Failure: Error, Equatable {}
}

extension WeatherClient{
    static let live = Self(
        searchCity: { city in
            var components = URLComponents(string: "https://api.openweathermap.org/geo/1.0/direct")!
            components.queryItems = [URLQueryItem(name: "q", value: city), URLQueryItem(name: "limit", value: searchResultLimit), URLQueryItem(name: "appid", value: apiKey)]
            print(components.url!)
            return URLSession.shared.dataTaskPublisher(for: components.url!)
                .map { data, _ in
                    print("JSON String: \(String(data: data, encoding: .utf8))")
                    return data
                }
                .decode(type: IdentifiedArrayOf<Location>.self, decoder: JSONDecoder())
                .mapError { _ in Failure()}
                .eraseToEffect()
        },
        weather: { lat, lon in
            var components = URLComponents(string: "https://api.openweathermap.org/data/2.5/weather")!
            components.queryItems = [URLQueryItem(name: "lat", value: "\(lat)"), URLQueryItem(name: "lon", value: "\(lon)"), URLQueryItem(name: "appid", value: apiKey), URLQueryItem(name: "units", value: unitOfMeasurement)]
            print(components.url!)
            return URLSession.shared.dataTaskPublisher(for: components.url!)
                .map { data, _ in data }
                .decode(type: LocationWeather.self, decoder: JSONDecoder())
                .mapError { _ in Failure()}
                .eraseToEffect()
            
        })
}
extension WeatherClient {
    static let failing = Self(
        searchCity: { _ in .failing("WeatherClient.searchCity")},
        weather: { _,_  in .failing("WeatherClient.weather")}
    )
}

extension LocationWeather{
    var farenheitTemp: Int {
        Int(main.temp)
    }
    
    var celsiusTemp: Int {
        Int(5/9 * (main.temp - 32))
    }
    
    var imageIcon: Image {
        weather.first?.icon.image ?? Image(systemName: "bandage")
    }
}

extension LocationWeather.WeatherDescription {
    enum Icon: String, Decodable {
        case clearDay = "01d"
        case clearNight = "01n"
        case partyCloudyDay = "02d"
        case partyCloudyNight = "02n"
        case cloudy = "03d"
        case cloudyNight = "03n"
        case brokenCloud = "04d"
        case brokenCloudNight = "04n"
        case showerRain = "09d"
        case showerRainNight = "09n"
        case nightRain = "10n"
        case sunnyRain = "10d"
        case thunderStorm = "11d"
        case thunderStormNight = "11n"
        case snowDay = "13d"
        case snowNight = "13n"
        case mistDay = "50d"
        case mistNight = "50n"
        
        var image: Image {
            switch self {
            case .clearDay:
                return Image(systemName: "sun.max.fill")
            case .clearNight:
                return Image(systemName: "moon.stars.fill")
            case .partyCloudyDay:
                return Image(systemName: "cloud.sun.fill")
            case .partyCloudyNight:
                return Image(systemName: "cloud.moon.fill")
            case .cloudy:
                return Image(systemName: "cloud.fill")
            case .cloudyNight:
                return Image(systemName: "cloud.fill")
            case .brokenCloud:
                return Image(systemName: "cloud.fill")
            case .brokenCloudNight:
                return Image(systemName: "cloud.fill")
            case .showerRain:
                return Image(systemName: "cloud.heavyrain.fill")
            case .showerRainNight:
                return Image(systemName: "cloud.heavyrain.fill")
            case .nightRain:
                return Image(systemName: "cloud.moon.rain.fill")
            case .sunnyRain:
                return Image(systemName: "cloud.sun.rain.fill")
            case .thunderStorm:
                return Image(systemName: "cloud.bolt.rain.fill")
            case .thunderStormNight:
                return Image(systemName: "cloud.bolt.rain.fill")
            case .snowDay:
                return Image(systemName: "snow")
            case .snowNight:
                return Image(systemName: "snow")
            case .mistDay:
                return Image(systemName: "cloud.fog.fill")
            case .mistNight:
                return Image(systemName: "cloud.fog.fill")
            }
        }
    }
}
