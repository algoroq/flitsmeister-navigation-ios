//
//  ColorManager.swift
//  MapboxNavigation
//
//  Created by Marcel Hozeman on 23/04/2020.
//  Copyright © 2020 Mapbox. All rights reserved.
//

import Foundation

class ColorManager {
    static let shared = ColorManager()
    
    public var palette = Palette()
}

public struct Palette {
    public var tintColor = #colorLiteral(red: 0.1843137255, green: 0.4784313725, blue: 0.7764705882, alpha: 1)
    public var tintStrokeColor = #colorLiteral(red: 0.1843137255, green: 0.4784313725, blue: 0.7764705882, alpha: 1)
    
    public init() {
    }
}
