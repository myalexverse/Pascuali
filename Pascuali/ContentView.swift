//
//  ContentView.swift
//  Pascuali
//
//  Created by Alex Tovar on 30/12/25.
//
import SwiftUI
import MapKit

// Extensión para cerrar teclado
#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

// --- ESTRUCTURA PRINCIPAL ---
struct ContentView: View {
    @State private var mostrarFormulario = false
    var body: some View {
        if mostrarFormulario {
            VistaPrincipal()
        } else {
            PantallaCarga(estaActiva: $mostrarFormulario)
        }
    }
}

struct VistaPrincipal: View {
    @StateObject var gestor = GestorDatos()
    
    var body: some View {
        TabView {
            FormularioView(gestor: gestor)
                .tabItem { Label("Captura", systemImage: "person.crop.circle.badge.plus") }
            
            MapaDashboardView(gestor: gestor)
                .tabItem { Label("Mapa", systemImage: "map.fill") }
            
            SeccionesListView(gestor: gestor)
                .tabItem { Label("Secciones", systemImage: "chart.bar.fill") }
            
            PreviewView(gestor: gestor)
                .tabItem { Label("Lote", systemImage: "list.bullet.clipboard") }
            
            HistorialView(gestor: gestor)
                .tabItem { Label("Archivos", systemImage: "archivebox.fill") }
        }
        .accentColor(.blue)
    }
}

/// --- VISTA MAPA ---
struct MapaDashboardView: View {
    @ObservedObject var gestor: GestorDatos
    @StateObject private var seccionesManager = SeccionesManager()
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20.9144, longitude: -100.7438),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var mostrarSecciones = true
    @State private var seccionSeleccionada: SeccionElectoral? = nil
    @State private var modoMapa: String = "Electoral"
    
    var body: some View {
        ZStack {
            // MAPA
            MapViewRepresentable(
                secciones: seccionesManager.secciones,
                registros: gestor.registrosActuales,
                region: $region,
                mostrarSecciones: mostrarSecciones,
                modoMapa: modoMapa,
                seccionSeleccionada: $seccionSeleccionada
            )
            .ignoresSafeArea()
            
            // CONTROLES SUPERIORES
            VStack {
                // Selector de Modo
                Picker("Modo", selection: $modoMapa) {
                    Text("Electoral").tag("Electoral")
                    Text("Problemáticas").tag("Problemáticas")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Barra de info
                HStack(alignment: .top) {
                    // Registros en lote
                    VStack(alignment: .leading, spacing: 4) {
                        Text("REGISTROS EN LOTE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                        Text("\(gestor.registrosActuales.count)")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(.blue)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.95))
                    .cornerRadius(10)
                    .shadow(radius: 4)
                    
                    Spacer()
                    
                    // Botón Secciones
                    Button(action: { mostrarSecciones.toggle() }) {
                        VStack(spacing: 2) {
                            Image(systemName: mostrarSecciones ? "map.fill" : "map")
                                .font(.system(size: 18))
                            Text("Secciones")
                                .font(.system(size: 9))
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.95))
                        .foregroundColor(mostrarSecciones ? .blue : .gray)
                        .cornerRadius(10)
                        .shadow(radius: 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                
                Spacer()
                
                // TARJETA ANALÍTICA INFERIOR
                if let seleccionada = seccionSeleccionada {
                    tarjetaAnalitica(seleccionada)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: seccionSeleccionada?.seccion)
                }
            }
        }
    }
    
    // --- TARJETA ANALÍTICA ---
    @ViewBuilder
    func tarjetaAnalitica(_ seccion: SeccionElectoral) -> some View {
        let listaNominalTotal = seccionesManager.secciones.reduce(0) { $0 + $1.electores }
        let meta = listaNominalTotal > 0 ? Int(Double(seccion.electores) / Double(listaNominalTotal) * 31274.0) : 0
        let numRegistros = countRegistros(in: seccion)
        let prioridad = seccion.electores > 2000 ? "ALTA" : (seccion.electores > 1000 ? "MEDIA" : "BAJA")
        let colorPrioridad: Color = seccion.electores > 2000 ? .red : (seccion.electores > 1000 ? .orange : .green)
        
        VStack(spacing: 0) {
            // Encabezado
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SECCIÓN ELECTORAL")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray)
                    Text("\(seccion.seccion)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Badge de prioridad
                Text(prioridad)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(colorPrioridad)
                    .cornerRadius(6)
                
                // Botón cerrar
                Button(action: { seccionSeleccionada = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray.opacity(0.5))
                }
                .padding(.leading, 4)
            }
            .padding(.bottom, 10)
            
            Divider()
            
            // Métricas
            HStack(spacing: 16) {
                // Lista Nominal
                metrica(
                    icono: "person.3.fill",
                    color: .blue,
                    titulo: "Lista Nominal",
                    valor: "\(seccion.electores)"
                )
                
                // Meta de votos
                metrica(
                    icono: "target",
                    color: .green,
                    titulo: "Meta votos",
                    valor: "\(meta)"
                )
                
                // Registros de campo
                metrica(
                    icono: "exclamationmark.triangle.fill",
                    color: .red,
                    titulo: "Registros",
                    valor: "\(numRegistros)"
                )
            }
            .padding(.top, 10)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground).opacity(0.97))
                .shadow(color: .black.opacity(0.15), radius: 12, y: -4)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    // --- MÉTRICA INDIVIDUAL ---
    func metrica(icono: String, color: Color, titulo: String, valor: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icono)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(valor)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(titulo)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    // --- CONTAR REGISTROS EN UNA SECCIÓN ---
    func countRegistros(in seccion: SeccionElectoral) -> Int {
        let polygon = seccion.polygon
        let points = polygon.points()
        let pointCount = polygon.pointCount
        var count = 0
        
        for registro in gestor.registrosActuales {
            let testPoint = MKMapPoint(CLLocationCoordinate2D(latitude: registro.latitud, longitude: registro.longitud))
            // Ray-casting
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

// --- FORMULARIO ---
struct FormularioView: View {
    @ObservedObject var gestor: GestorDatos
    @StateObject var locationManager = LocationManager()
    
    @State private var nombre = ""; @State private var direccion = ""; @State private var telefono = ""; @State private var facebook = ""; @State private var necesidad = ""
    @State private var mostrarAlerta = false; @State private var ultimoFolio = ""
    @State private var latitudCapturada: Double = 0.0; @State private var longitudCapturada: Double = 0.0
    @State private var ubicacionLista = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Ubicación")) {
                    if ubicacionLista {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("GPS Listo")
                            Spacer()
                            Text(String(format: "%.4f, %.4f", latitudCapturada, longitudCapturada)).font(.caption)
                        }
                    } else {
                        Button(action: capturarGPS) {
                            HStack { Image(systemName: "location.fill"); Text("Capturar Ubicación") }
                        }.foregroundColor(.blue)
                    }
                }
                
                Section(header: Text("Datos")) {
                    TextField("Nombre Completo", text: $nombre)
                    TextField("Dirección", text: $direccion)
                    TextField("Teléfono", text: $telefono).keyboardType(.phonePad)
                    TextField("Facebook", text: $facebook)
                }
                
                Section(header: Text("Diagnóstico")) {
                    TextField("Necesidad", text: $necesidad)
                }
                
                Section {
                    Button(action: guardar) {
                        HStack { Spacer(); Text("Guardar Registro").bold(); Spacer() }
                    }
                    .listRowBackground(Color.blue).foregroundColor(.white)
                    .disabled(nombre.isEmpty)
                }
            }
            .navigationTitle("Registro")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Listo") { hideKeyboard() } }
            }
            .alert("Guardado", isPresented: $mostrarAlerta) { Button("OK", role: .cancel) {} } message: { Text("Folio: \(ultimoFolio)") }
            .onAppear { locationManager.requestLocation() }
        }
    }
    
    func capturarGPS() {
        if let location = locationManager.userLocation {
            latitudCapturada = location.latitude; longitudCapturada = location.longitude
            ubicacionLista = true
        } else {
            latitudCapturada = 20.9144; longitudCapturada = -100.7438; ubicacionLista = true
        }
    }
    
    func guardar() {
        if !ubicacionLista { capturarGPS() }
        gestor.agregarAmigo(nombre: nombre, dir: direccion, tel: telefono, face: facebook, necesidad: necesidad, lat: latitudCapturada, long: longitudCapturada)
        if let ultimo = gestor.registrosActuales.last { ultimoFolio = ultimo.folio }
        mostrarAlerta = true; nombre = ""; direccion = ""; telefono = ""; facebook = ""; necesidad = ""; hideKeyboard(); ubicacionLista = false
    }
}
// --- LOTE (CON BOTÓN MANUAL, BORRADO LOCAL Y CONFIRMACIÓN) ---
struct PreviewView: View {
    @ObservedObject var gestor: GestorDatos
    
    // Alerta para el archivo Excel
    @State private var mostrarAlertaCierre = false
    
    // VARIABLES NUEVAS PARA LA CONFIRMACIÓN DE BORRADO
    @State private var mostrarConfirmacionBorrado = false
    @State private var indicesPorBorrar: IndexSet? // Aquí guardamos "cuál" borrar mientras confirman
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Acciones")) {
                    Button(action: { gestor.cerrarLote(); mostrarAlertaCierre = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down.fill")
                            Text("Cerrar Lote y Generar Archivo").bold()
                        }
                    }
                    .foregroundColor(.blue).listRowBackground(Color.blue.opacity(0.1))
                }
                
                Section(header: Text("Mis Registros (Desliza para limpiar)")) {
                    if gestor.registrosActuales.isEmpty {
                        Text("Lote vacío").foregroundColor(.gray)
                    } else {
                        ForEach(gestor.registrosActuales.reversed()) { registro in
                            NavigationLink(destination: VistaEdicion(gestor: gestor, registroOriginal: registro)) {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(registro.nombre).font(.headline)
                                        Spacer()
                                        Text(registro.folio).font(.caption).foregroundColor(.blue)
                                    }
                                    Text("FB: \(registro.facebook)").font(.caption).foregroundColor(.gray)
                                }
                            }
                        }
                        .onDelete(perform: prepararBorrado) // <--- CAMBIO AQUÍ: Llamamos a la preparación, no al borrado directo
                    }
                }
            }
            .navigationTitle("Lote Actual")
            // ALERTA 1: Archivo Generado
            .alert("¡Archivo Generado!", isPresented: $mostrarAlertaCierre) {
                Button("OK", role: .cancel) {}
            }
            // ALERTA 2: Confirmación de Borrado (NUEVA)
            .alert("¿Eliminar este registro?", isPresented: $mostrarConfirmacionBorrado) {
                Button("Cancelar", role: .cancel) {
                    indicesPorBorrar = nil // Si cancela, olvidamos qué quería borrar
                }
                Button("Sí, Eliminar", role: .destructive) {
                    if let indices = indicesPorBorrar {
                        gestor.borrarLocalmente(at: indices) // ¡AQUÍ SÍ BORRAMOS!
                    }
                    indicesPorBorrar = nil // Limpiamos la variable
                }
            } message: {
                Text("Se eliminará de tu lista local, pero si ya se subió a la nube, el Administrador aún lo tendrá.")
            }
        }
    }
    
    // Función auxiliar para activar la alerta
    func prepararBorrado(at offsets: IndexSet) {
        indicesPorBorrar = offsets // Guardamos "cuál" renglón fue
        mostrarConfirmacionBorrado = true // Mostramos la pregunta
    }
}
// --- EDICIÓN (CON TODOS LOS CAMPOS + REPORTE) ---
struct VistaEdicion: View {
    @ObservedObject var gestor: GestorDatos
    @Environment(\.presentationMode) var presentationMode
    var registroOriginal: AmigoPascuali
    
    @State private var nombreEdit = ""; @State private var dirEdit = ""; @State private var telEdit = ""; @State private var faceEdit = ""; @State private var necEdit = ""
    @State private var mostrarDialogoReporte = false; @State private var motivoReporte = ""
    
    var body: some View {
        Form {
            Section(header: Text("Datos")) {
                TextField("Nombre", text: $nombreEdit)
                TextField("Dirección", text: $dirEdit)
                TextField("Teléfono", text: $telEdit).keyboardType(.phonePad)
                TextField("Facebook", text: $faceEdit)
            }
            Section(header: Text("Diagnóstico")) {
                TextEditor(text: $necEdit).frame(height: 100)
            }
            Section {
                Button("Guardar Corrección") {
                    var act = registroOriginal
                    act.nombre = nombreEdit; act.direccion = dirEdit; act.telefono = telEdit; act.facebook = faceEdit; act.necesidad = necEdit
                    gestor.actualizarRegistro(act)
                    presentationMode.wrappedValue.dismiss()
                }
                .frame(maxWidth: .infinity, alignment: .center).foregroundColor(.white)
            }
            .listRowBackground(Color.blue)
            
            Section(header: Text("Zona de Peligro")) {
                Button(action: { mostrarDialogoReporte = true }) {
                    HStack { Image(systemName: "exclamationmark.triangle.fill"); Text("Reportar Error al Admin") }
                }.foregroundColor(.red)
            }
        }
        .navigationTitle("Editar")
        .onAppear {
            nombreEdit = registroOriginal.nombre; dirEdit = registroOriginal.direccion; telEdit = registroOriginal.telefono; faceEdit = registroOriginal.facebook; necEdit = registroOriginal.necesidad
        }
        .alert("Reportar Error", isPresented: $mostrarDialogoReporte) {
            TextField("Motivo", text: $motivoReporte)
            Button("Enviar Reporte", role: .destructive) {
                gestor.reportarError(registro: registroOriginal, motivo: motivoReporte)
                presentationMode.wrappedValue.dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        }
    }
}

struct HistorialView: View {
    @ObservedObject var gestor: GestorDatos
    var body: some View {
        NavigationView {
            List(gestor.archivosDeLotes, id: \.self) { url in
                ShareLink(item: url) {
                    HStack {
                        Image(systemName: "doc.text.fill").foregroundColor(.blue)
                        Text(url.lastPathComponent)
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }.navigationTitle("Archivos Excel").onAppear { gestor.cargarListaDeArchivos() }
        }
    }
}
