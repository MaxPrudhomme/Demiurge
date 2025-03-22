import Foundation

class Elevation {
    var tectonicActivityFactor: Float
    var volcanicActivityFactor: Float
    var noiseFrequency: Float
    var noiseAmplitude: Float
    var seaLevel: Float = 0.0

    init(tectonicActivityFactor: Float, volcanicActivityFactor: Float, noiseFrequency: Float, noiseAmplitude: Float) {
        self.tectonicActivityFactor = tectonicActivityFactor
        self.volcanicActivityFactor = volcanicActivityFactor
        self.noiseFrequency = noiseFrequency
        self.noiseAmplitude = noiseAmplitude
    }

    func generateElevationMap(size: Int) -> [Float] {
        var values: [Float] = []
        values = (0..<size * size).map { _ in
            var elevation = generateNoise() * noiseAmplitude
            elevation += generateTectonicActivity()
            elevation += generateVolcanicActivity()
            return elevation
        }
        return values
    }

    private func generateNoise() -> Float {
        // Simplex or Perlin noise generation here
        return Float.random(in: -1.0...1.0)
    }

    private func generateTectonicActivity() -> Float {
        // Simulate tectonic activity based on the tectonicActivityFactor
        return Float.random(in: -tectonicActivityFactor...tectonicActivityFactor)
    }

    private func generateVolcanicActivity() -> Float {
        // Simulate volcanic activity based on the volcanicActivityFactor
        return Float.random(in: 0.0...volcanicActivityFactor)
    }
}
