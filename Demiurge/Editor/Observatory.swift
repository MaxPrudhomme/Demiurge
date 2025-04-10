//
//  Observatory.swift
//  Demiurge
//
//  Created by Max PRUDHOMME on 08/04/2025.
//

import SwiftUI
import MetalKit

struct PlanetConfig: Codable {
    var seed: Int
    var planetName: String
    var elevationController: [Float]
    var temperatureController: [Float]
    var humidityController: [Float]
}

class ObservatoryViewModel: ObservableObject {
    var renderControl: RenderControl

    init(renderControl: RenderControl) {
        self.renderControl = renderControl
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    func savePlanetConfiguration() {
        let url = getDocumentsDirectory().appendingPathComponent("\(renderControl.planetName).json")

        let config = PlanetConfig(
            seed: renderControl.seed,
            planetName: renderControl.planetName,
            elevationController: renderControl.elevationController,
            temperatureController: renderControl.temperatureController,
            humidityController: renderControl.humidityController
        )

        do {
            let encoded = try JSONEncoder().encode(config)
            try encoded.write(to: url)
            print("Planet configuration saved as \(renderControl.planetName).json")
        } catch {
            print("Error saving planet configuration: \(error)")
        }
    }

    func deletePlanetConfiguration(planetName: String) {
        let url = getDocumentsDirectory().appendingPathComponent("\(planetName).json")
        do {
            try FileManager.default.removeItem(at: url)
            print("Planet configuration \(planetName).json deleted.")
        } catch {
            print("Error deleting planet configuration \(planetName).json: \(error)")
        }
    }
}

struct ObservatoryView: View {
    @StateObject private var viewModel: ObservatoryViewModel
    @State private var savedPlanets: [PlanetConfig] = []
    @State private var entryHeight: CGFloat = 50

    init(renderControl: RenderControl) {
        _viewModel = StateObject(wrappedValue: ObservatoryViewModel(renderControl: renderControl))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                ForEach(savedPlanets, id: \.planetName) { planet in
                    SwipeToDeleteEntryView(planet: planet, renderControl: viewModel.renderControl, entryHeight: $entryHeight) { planetToDelete in
                        deletePlanet(planetToDelete)
                    }
                    .frame(height: entryHeight)
                    .padding(.top, 5)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .onAppear {
                loadSavedPlanets()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Observatory")
                        .font(.system(size: 20, weight: .bold))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        viewModel.savePlanetConfiguration()
                        loadSavedPlanets()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .padding(.trailing, 8)
                    .accessibilityIdentifier("saveButton")
                }
            }
        }
    }

    func loadSavedPlanets() {
        let fileManager = FileManager.default
        let documentsDirectory = viewModel.getDocumentsDirectory()
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)

            let jsonFiles = files.filter { $0.pathExtension == "json" }

            savedPlanets = try jsonFiles.map { fileURL in
                let data = try Data(contentsOf: fileURL)
                let planetConfig = try JSONDecoder().decode(PlanetConfig.self, from: data)
                return planetConfig
            }

            savedPlanets.sort { url1, url2 in
                return url1.planetName > url2.planetName
            }
        } catch {
            print("Error loading saved planets: \(error)")
        }
    }

    func deletePlanet(_ planetToDelete: PlanetConfig) {
        viewModel.deletePlanetConfiguration(planetName: planetToDelete.planetName)
        savedPlanets.removeAll { $0.planetName == planetToDelete.planetName }
    }
}

struct SwipeToDeleteEntryView: View {
    var planet: PlanetConfig
    var renderControl: RenderControl
    @Binding var entryHeight: CGFloat
    var onDelete: (PlanetConfig) -> Void

    @State private var offsetX: CGFloat = 0
    @State private var showDeleteButton = false

    var body: some View {
        ZStack(alignment: .trailing) {
            EntryView(planetName: planet.planetName, planetConfig: planet, renderControl: renderControl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: offsetX)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offsetX = value.translation.width
                            if offsetX < -60 {
                                showDeleteButton = true
                            } else {
                                showDeleteButton = false
                            }
                        }
                        .onEnded { _ in
                            if offsetX < -60 {
                                offsetX = -80
                            } else {
                                offsetX = 0
                                showDeleteButton = false
                            }
                        }
                )

            if showDeleteButton {
                Button(role: .destructive) {
                    onDelete(planet)
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .transition(.move(edge: .trailing))
            }
        }
        .frame(height: entryHeight)
        .clipped()
        .animation(.easeInOut(duration: 0.3), value: offsetX)
    }
}
