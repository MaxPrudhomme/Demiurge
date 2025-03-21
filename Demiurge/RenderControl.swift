//
//  RenderControl.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 21/03/2025.
//

import SwiftUI

class RenderControl: ObservableObject {
    @Published var rotate: Bool = false
    @Published var rescale: Bool = false
}
