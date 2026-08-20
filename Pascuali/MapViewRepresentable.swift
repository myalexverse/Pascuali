import SwiftUI
import MapKit

// Custom Annotation para la etiqueta de sección
class SeccionAnnotation: MKPointAnnotation {
    var seccion: Int = 0
}

struct MapViewRepresentable: UIViewRepresentable {
    var secciones: [SeccionElectoral]
    var registros: [AmigoPascuali]
    @Binding var region: MKCoordinateRegion
    var mostrarSecciones: Bool
    var modoMapa: String // "Electoral" o "Problemáticas"
    
    @Binding var seccionSeleccionada: SeccionElectoral?

    // --- PALETA DE COLORES VIBRANTES ---
    
    /// Paleta de 10 colores vivos y distinguibles
    let paletaVibrante: [UIColor] = [
        UIColor(red: 0.20, green: 0.60, blue: 0.86, alpha: 1.0), // Azul cielo
        UIColor(red: 0.18, green: 0.80, blue: 0.44, alpha: 1.0), // Verde esmeralda
        UIColor(red: 0.90, green: 0.49, blue: 0.13, alpha: 1.0), // Naranja cálido
        UIColor(red: 0.61, green: 0.35, blue: 0.71, alpha: 1.0), // Morado suave
        UIColor(red: 0.20, green: 0.29, blue: 0.80, alpha: 1.0), // Azul índigo
        UIColor(red: 0.90, green: 0.30, blue: 0.24, alpha: 1.0), // Rojo coral
        UIColor(red: 0.10, green: 0.74, blue: 0.61, alpha: 1.0), // Turquesa
        UIColor(red: 0.83, green: 0.33, blue: 0.61, alpha: 1.0), // Rosa fuerte
        UIColor(red: 0.95, green: 0.77, blue: 0.06, alpha: 1.0), // Amarillo oro
        UIColor(red: 0.40, green: 0.65, blue: 0.32, alpha: 1.0), // Verde bosque
    ]
    
    /// Electoral: color vibrante por sección, saturación modulada por electores
    func colorParaElectoral(seccionIndex: Int, electores: Int) -> UIColor {
        let base = paletaVibrante[seccionIndex % paletaVibrante.count]
        // Más electores = color más intenso, menos = ligeramente desaturado
        let ratio = min(CGFloat(electores) / 4000.0, 1.0)
        let factor: CGFloat = 0.75 + (ratio * 0.25) // 0.75 → 1.0 (menos desaturación)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        base.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s * factor, brightness: b, alpha: 1.0)
    }
    
    /// Problemáticas: gris (sin registros) → rojo intenso escalonado
    func colorParaProblematica(registrosEnSeccion: Int) -> UIColor {
        if registrosEnSeccion == 0 {
            return UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1.0) // Gris suave
        }
        let ratio = min(CGFloat(registrosEnSeccion) / 10.0, 1.0)
        let saturation: CGFloat = 0.5 + (ratio * 0.5)  // 0.5 → 1.0
        let brightness: CGFloat = 1.0 - (ratio * 0.15)  // 1.0 → 0.85
        return UIColor(hue: 0.02, saturation: saturation, brightness: brightness, alpha: 1.0)
    }
    
    /// Contar cuántos registros caen dentro de una sección usando punto-en-polígono
    func countRegistros(in seccion: SeccionElectoral) -> Int {
        var count = 0
        let polygon = seccion.polygon
        let pointCount = polygon.pointCount
        let points = polygon.points()
        
        for registro in registros {
            let testPoint = MKMapPoint(CLLocationCoordinate2D(latitude: registro.latitud, longitude: registro.longitud))
            if pointInPolygon(testPoint, polygonPoints: points, count: pointCount) {
                count += 1
            }
        }
        return count
    }
    
    /// Algoritmo Ray-Casting para punto-en-polígono (matemática pura, no depende de renderers)
    func pointInPolygon(_ point: MKMapPoint, polygonPoints: UnsafeMutablePointer<MKMapPoint>, count: Int) -> Bool {
        var inside = false
        var j = count - 1
        for i in 0..<count {
            let pi = polygonPoints[i]
            let pj = polygonPoints[j]
            if ((pi.y > point.y) != (pj.y > point.y)) &&
                (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x) {
                inside = !inside
            }
            j = i
        }
        return inside
    }

    // --- CICLO DE VIDA UIViewRepresentable ---
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: true)
        mapView.showsUserLocation = true
        
        // Tap gesture con delegate para no bloquear gestos nativos del mapa
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        mapView.addGestureRecognizer(tap)
        
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Actualizar referencia al parent en el coordinator
        context.coordinator.parent = self
        
        // --- 1. POLÍGONOS: Solo actualizar si realmente cambió ---
        let currentOverlayCount = mapView.overlays.compactMap { $0 as? MKPolygon }.count
        let expectedCount = mostrarSecciones ? secciones.count : 0
        
        if currentOverlayCount != expectedCount {
            // Limpiar overlays y labels existentes
            let existingPolygons = mapView.overlays.compactMap { $0 as? MKPolygon }
            mapView.removeOverlays(existingPolygons)
            let existingLabels = mapView.annotations.compactMap { $0 as? SeccionAnnotation }
            mapView.removeAnnotations(existingLabels)
            
            if mostrarSecciones {
                for seccion in secciones {
                    mapView.addOverlay(seccion.polygon)
                    
                    let annotation = SeccionAnnotation()
                    annotation.coordinate = seccion.polygon.coordinate
                    annotation.seccion = seccion.seccion
                    mapView.addAnnotation(annotation)
                }
            }
        }
        
        // --- 2. PINES (REGISTROS): Siempre sincronizar ---
        let existingPins = mapView.annotations.filter { !($0 is MKUserLocation) && !($0 is SeccionAnnotation) }
        if existingPins.count != registros.count {
            mapView.removeAnnotations(existingPins)
            for registro in registros {
                let annotation = MKPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(latitude: registro.latitud, longitude: registro.longitud)
                annotation.title = registro.nombre
                annotation.subtitle = registro.necesidad
                mapView.addAnnotation(annotation)
            }
        }
        
        // --- 3. FORZAR RE-RENDERIZADO DE COLORES (cuando cambia modoMapa o selección) ---
        for overlay in mapView.overlays {
            if let renderer = mapView.renderer(for: overlay) as? MKPolygonRenderer,
               let polygon = overlay as? MKPolygon {
                
                // Buscar modelo e índice
                var seccionModel: SeccionElectoral? = nil
                var seccionIdx = 0
                for (idx, s) in secciones.enumerated() {
                    if s.polygon === polygon {
                        seccionModel = s
                        seccionIdx = idx
                        break
                    }
                }
                
                var colorBase = UIColor.lightGray
                if let seccion = seccionModel {
                    if modoMapa == "Problemáticas" {
                        colorBase = colorParaProblematica(registrosEnSeccion: countRegistros(in: seccion))
                    } else {
                        colorBase = colorParaElectoral(seccionIndex: seccionIdx, electores: seccion.electores)
                    }
                }
                
                let seccionID = seccionModel?.seccion ?? -1
                let isSelected = seccionSeleccionada?.seccion == seccionID
                let hasSelection = seccionSeleccionada != nil
                
                renderer.fillColor = colorBase.withAlphaComponent(hasSelection && !isSelected ? 0.08 : 0.45)
                renderer.strokeColor = colorBase.withAlphaComponent(hasSelection && !isSelected ? 0.15 : 1.0)
                renderer.lineWidth = isSelected ? 4 : 2
                renderer.setNeedsDisplay()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // --- COORDINATOR ---
    
    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: MapViewRepresentable

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        // Permitir toques simultáneos con gestos nativos del mapa
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }

        // --- RENDERER: Colores iniciales al crear el polígono ---
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                
                // Buscar modelo e índice por identidad de objeto
                var seccionModel: SeccionElectoral? = nil
                var seccionIdx = 0
                for (idx, s) in parent.secciones.enumerated() {
                    if s.polygon === polygon {
                        seccionModel = s
                        seccionIdx = idx
                        break
                    }
                }
                
                var colorBase = UIColor.lightGray
                if let seccion = seccionModel {
                    if parent.modoMapa == "Problemáticas" {
                        colorBase = parent.colorParaProblematica(registrosEnSeccion: parent.countRegistros(in: seccion))
                    } else {
                        colorBase = parent.colorParaElectoral(seccionIndex: seccionIdx, electores: seccion.electores)
                    }
                }
                
                renderer.fillColor = colorBase.withAlphaComponent(0.45)
                renderer.strokeColor = colorBase.withAlphaComponent(1.0)
                renderer.lineWidth = 2
                
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // --- ANNOTATION VIEWS ---
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            
            // Etiqueta de sección
            if let seccionAnn = annotation as? SeccionAnnotation {
                let identifier = "SeccionLabel"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = false
                    
                    let label = UILabel()
                    label.tag = 100
                    label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
                    label.textColor = .darkGray
                    label.backgroundColor = UIColor.white.withAlphaComponent(0.8)
                    label.layer.cornerRadius = 4
                    label.layer.masksToBounds = true
                    label.textAlignment = .center
                    
                    view?.addSubview(label)
                } else {
                    view?.annotation = annotation
                }
                
                if let label = view?.viewWithTag(100) as? UILabel {
                    label.text = " \(seccionAnn.seccion) "
                    label.sizeToFit()
                    view?.frame = label.frame
                }
                return view
            }
            
            // Pines de registros — morado oscuro con ícono de persona para máximo contraste
            let identifier = "AmigoPin"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = true
                view?.markerTintColor = UIColor(red: 0.35, green: 0.10, blue: 0.55, alpha: 1.0) // Morado oscuro
                view?.glyphImage = UIImage(systemName: "person.fill")
                view?.glyphTintColor = .white
                view?.displayPriority = .required // Siempre visible, nunca se ocultan por clustering
            } else {
                view?.annotation = annotation
            }
            
            return view
        }
        
        // --- DETECCIÓN DE TOQUES: Punto-en-polígono directo sobre el modelo ---
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard sender.state == .ended else { return }
            guard let mapView = sender.view as? MKMapView else { return }
            
            let tapPoint = sender.location(in: mapView)
            let tapCoordinate = mapView.convert(tapPoint, toCoordinateFrom: mapView)
            let mapPoint = MKMapPoint(tapCoordinate)
            
            var tappedSeccion: SeccionElectoral? = nil
            
            // Iterar sobre el MODELO directamente, no sobre los overlays/renderers
            for seccion in parent.secciones {
                let polygon = seccion.polygon
                let points = polygon.points()
                let count = polygon.pointCount
                
                if parent.pointInPolygon(mapPoint, polygonPoints: points, count: count) {
                    tappedSeccion = seccion
                    break
                }
            }
            
            DispatchQueue.main.async {
                if let tapped = tappedSeccion {
                    if self.parent.seccionSeleccionada?.seccion == tapped.seccion {
                        self.parent.seccionSeleccionada = nil
                    } else {
                        self.parent.seccionSeleccionada = tapped
                    }
                } else {
                    self.parent.seccionSeleccionada = nil
                }
            }
        }
    }
}
