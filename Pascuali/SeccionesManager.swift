import Foundation
import MapKit
import Combine
import SwiftUI

// Estructura para almacenar la información de cada sección
struct SeccionElectoral {
    let seccion: Int
    let municipio: Int
    let electores: Int
    let polygon: MKPolygon
}

class SeccionesManager: ObservableObject {
    @Published var secciones: [SeccionElectoral] = []
    
    init() {
        cargarSecciones()
    }
    
    func cargarSecciones() {
        // Carga el archivo GeoJSON desde el bundle
        guard let url = Bundle.main.url(forResource: "secciones_sma", withExtension: "geojson") else {
            print("No se encontró el archivo secciones_sma.geojson en el Bundle.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            // Decodifica el GeoJSON genérico
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let features = json["features"] as? [[String: Any]] else {
                return
            }
            
            var loadedSecciones: [SeccionElectoral] = []
            
            for feature in features {
                guard let properties = feature["properties"] as? [String: Any],
                      let geometry = feature["geometry"] as? [String: Any],
                      let type = geometry["type"] as? String,
                      let coordinates = geometry["coordinates"] as? [Any] else {
                    continue
                }
                
                let seccion = properties["seccion"] as? Int ?? 0
                let municipio = properties["municipio"] as? Int ?? 0
                let electores = properties["electores"] as? Int ?? 0
                
                // Parseamos las coordenadas (Polígonos de GeoJSON)
                if type == "Polygon" {
                    if let ring = coordinates.first as? [[Double]] {
                        let clCoordinates = ring.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
                        let polygon = MKPolygon(coordinates: clCoordinates, count: clCoordinates.count)
                        polygon.title = "Sección \(seccion)"
                        loadedSecciones.append(SeccionElectoral(seccion: seccion, municipio: municipio, electores: electores, polygon: polygon))
                    }
                } else if type == "MultiPolygon" {
                    for poly in coordinates {
                        if let polyArray = poly as? [[[Double]]], let ring = polyArray.first {
                            let clCoordinates = ring.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
                            let polygon = MKPolygon(coordinates: clCoordinates, count: clCoordinates.count)
                            polygon.title = "Sección \(seccion)"
                            loadedSecciones.append(SeccionElectoral(seccion: seccion, municipio: municipio, electores: electores, polygon: polygon))
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.secciones = loadedSecciones
            }
            
        } catch {
            print("Error leyendo el GeoJSON: \(error)")
        }
    }
}
