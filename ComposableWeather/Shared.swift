//
//  Shared.swift
//  ComposableWeather
//
//  Created by William Lopez on 4/3/22.
//

import SwiftUI

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
