import SwiftUI
import MapKit

struct SeccionesListView: View {
    @ObservedObject var gestor: GestorDatos
    @StateObject private var seccionesManager = SeccionesManager()
    
    @State private var ordenamiento: String = "Prioridad"
    
    // --- CONSTANTES ESTRATÉGICAS (Elección 2024) ---
    private let metaGlobal: Int = 31_274           // Ganador 2024 (26,274) + 5,000
    private let ganador2024: Int = 26_274          // Votos del ganador 2024
    
    /// Meta proporcional por sección: distribuye la meta global según peso electoral
    func metaParaSeccion(_ seccion: SeccionElectoral) -> Int {
        let listaNominalTotal = seccionesManager.secciones.reduce(0) { $0 + $1.electores }
        guard listaNominalTotal > 0 else { return 0 }
        return Int(Double(seccion.electores) / Double(listaNominalTotal) * Double(metaGlobal))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // --- RESUMEN EJECUTIVO ---
                    tarjetaResumen
                    
                    // --- ORDENAMIENTO ---
                    Picker("Ordenar por", selection: $ordenamiento) {
                        Text("Prioridad").tag("Prioridad")
                        Text("Menor avance").tag("Avance")
                        Text("Sección").tag("Sección")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 16)
                    
                    // --- LISTA DE SECCIONES ---
                    LazyVStack(spacing: 12) {
                        ForEach(seccionesOrdenadas, id: \.seccion) { seccion in
                            let registros = countRegistros(in: seccion)
                            let meta = metaParaSeccion(seccion)
                            let avance = meta > 0 ? Double(registros) / Double(meta) : 0.0
                            
                            tarjetaSeccion(
                                seccion: seccion,
                                registros: registros,
                                meta: meta,
                                avance: avance
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Avance Territorial")
        }
    }
    
    // --- SECCIONES ORDENADAS ---
    var seccionesOrdenadas: [SeccionElectoral] {
        switch ordenamiento {
        case "Prioridad":
            return seccionesManager.secciones.sorted { $0.electores > $1.electores }
        case "Avance":
            return seccionesManager.secciones.sorted {
                let a0 = avanceParaSeccion($0)
                let a1 = avanceParaSeccion($1)
                return a0 < a1
            }
        case "Sección":
            return seccionesManager.secciones.sorted { $0.seccion < $1.seccion }
        default:
            return seccionesManager.secciones
        }
    }
    
    func avanceParaSeccion(_ seccion: SeccionElectoral) -> Double {
        let meta = metaParaSeccion(seccion)
        let registros = countRegistros(in: seccion)
        return meta > 0 ? Double(registros) / Double(meta) : 0.0
    }
    
    // --- TARJETA RESUMEN EJECUTIVO ---
    var tarjetaResumen: some View {
        let totalSecciones = seccionesManager.secciones.count
        let totalRegistros = gestor.registrosActuales.count
        let avanceGlobal = metaGlobal > 0 ? Double(totalRegistros) / Double(metaGlobal) : 0.0
        
        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ESTRATEGIA 2027")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.gray)
                    Text("San Miguel de Allende")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Meta: \(formatearNumero(metaGlobal)) votos (+5K sobre 2024)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.blue)
                }
                Spacer()
                Image(systemName: "flag.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            Divider()
            
            // Métricas en fila
            HStack(spacing: 0) {
                metricaResumen(valor: "\(totalSecciones)", titulo: "Secciones", color: .blue)
                metricaResumen(valor: "\(totalRegistros)", titulo: "Registros", color: .orange)
                metricaResumen(valor: formatearNumero(metaGlobal), titulo: "Meta", color: .green)
                metricaResumen(valor: formatearNumero(ganador2024), titulo: "2024", color: .gray)
            }
            
            // Barra de progreso global
            VStack(spacing: 4) {
                HStack {
                    Text("Avance global")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", avanceGlobal * 100))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(colorParaAvance(avanceGlobal))
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorParaAvance(avanceGlobal))
                            .frame(width: geo.size.width * min(CGFloat(avanceGlobal), 1.0), height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        )
        .padding(.horizontal, 16)
    }
    
    // --- MÉTRICA DEL RESUMEN ---
    func metricaResumen(valor: String, titulo: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(valor)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(color)
            Text(titulo)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // --- TARJETA DE SECCIÓN INDIVIDUAL ---
    func tarjetaSeccion(seccion: SeccionElectoral, registros: Int, meta: Int, avance: Double) -> some View {
        let prioridad = seccion.electores > 2000 ? "ALTA" : (seccion.electores > 1000 ? "MEDIA" : "BAJA")
        let colorPrioridad: Color = seccion.electores > 2000 ? .red : (seccion.electores > 1000 ? .orange : .green)
        
        return VStack(spacing: 10) {
            // Encabezado
            HStack {
                // Número de sección
                Text("\(seccion.seccion)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("SECCIÓN")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                    Text("Mpio. \(seccion.municipio)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Badge de prioridad
                Text(prioridad)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colorPrioridad)
                    .cornerRadius(5)
            }
            
            // Métricas en fila
            HStack(spacing: 16) {
                datoSeccion(icono: "person.3.fill", color: .blue, titulo: "Nominal", valor: formatearNumero(seccion.electores))
                datoSeccion(icono: "target", color: .green, titulo: "Meta", valor: formatearNumero(meta))
                datoSeccion(icono: "doc.text.fill", color: .orange, titulo: "Registros", valor: "\(registros)")
            }
            
            // Barra de progreso
            VStack(spacing: 3) {
                HStack {
                    Text("Avance")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", min(avance, 1.0) * 100))
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(colorParaAvance(avance))
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colorParaAvance(avance))
                            .frame(width: geo.size.width * min(CGFloat(avance), 1.0), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        )
    }
    
    // --- DATO INDIVIDUAL DE SECCIÓN ---
    func datoSeccion(icono: String, color: Color, titulo: String, valor: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icono)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(valor)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(titulo)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // --- COLOR SEGÚN AVANCE ---
    func colorParaAvance(_ avance: Double) -> Color {
        if avance < 0.25 {
            return .red
        } else if avance < 0.50 {
            return .orange
        } else if avance < 0.75 {
            return Color(red: 0.9, green: 0.75, blue: 0.0) // Amarillo oscuro
        } else {
            return .green
        }
    }
    
    // --- FORMATEAR NÚMERO CON SEPARADOR ---
    func formatearNumero(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
    
    // --- CONTAR REGISTROS EN UNA SECCIÓN (Ray-Casting) ---
    func countRegistros(in seccion: SeccionElectoral) -> Int {
        let polygon = seccion.polygon
        let points = polygon.points()
        let pointCount = polygon.pointCount
        var count = 0
        
        for registro in gestor.registrosActuales {
            let testPoint = MKMapPoint(CLLocationCoordinate2D(latitude: registro.latitud, longitude: registro.longitud))
            var inside = false
            var j = pointCount - 1
            for i in 0..<pointCount {
                let pi = points[i]
                let pj = points[j]
                if ((pi.y > testPoint.y) != (pj.y > testPoint.y)) &&
                    (testPoint.x < (pj.x - pi.x) * (testPoint.y - pi.y) / (pj.y - pi.y) + pi.x) {
                    inside = !inside
                }
                j = i
            }
            if inside { count += 1 }
        }
        return count
    }
}
