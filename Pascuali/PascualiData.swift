import Foundation
import FirebaseDatabase
import SwiftUI
import Combine

// 1. EL MODELO DE DATOS
struct AmigoPascuali: Identifiable, Codable {
    var id: String
    var folio: String
    var nombre: String
    var direccion: String
    var telefono: String
    var facebook: String
    var necesidad: String
    var fecha: Int64
    var latitud: Double
    var longitud: Double
    
    // Compatibilidad
    var necesidadSMA: String {
        get { return necesidad }
        set { necesidad = newValue }
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id, "folio": folio, "nombre": nombre, "direccion": direccion,
            "telefono": telefono, "facebook": facebook, "necesidad": necesidad,
            "fecha": fecha, "latitud": latitud, "longitud": longitud
        ]
    }
}

// 2. EL GESTOR DE DATOS CON MEMORIA PERSISTENTE
class GestorDatos: ObservableObject {
    @Published var registrosActuales: [AmigoPascuali] = []
    @Published var archivosDeLotes: [URL] = []
    
    private let ref = Database.database().reference().child("registros_globales")
    private let refReportes = Database.database().reference().child("solicitudes_borrado")
    
    // CLAVE PARA GUARDAR EN EL DISCO DEL IPHONE
    private let keyGuardadoLocal = "pascuali_registros_pendientes"
    
    init() {
        cargarListaDeArchivos()
        cargarMemoriaLocal() // <--- RECUPERAR DATOS AL ABRIR LA APP
    }
    
    // --- FUNCIÓN CLAVE: GUARDAR EN DISCO ---
    private func guardarEnDisco() {
        if let encoded = try? JSONEncoder().encode(registrosActuales) {
            UserDefaults.standard.set(encoded, forKey: keyGuardadoLocal)
        }
    }
    
    // --- FUNCIÓN CLAVE: LEER DEL DISCO ---
    private func cargarMemoriaLocal() {
        if let data = UserDefaults.standard.data(forKey: keyGuardadoLocal),
           let decoded = try? JSONDecoder().decode([AmigoPascuali].self, from: data) {
            self.registrosActuales = decoded
        }
    }
    
    func agregarAmigo(nombre: String, dir: String, tel: String, face: String, necesidad: String, lat: Double, long: Double) {
        let letras = String(nombre.prefix(2)).uppercased()
        let numeros = Int.random(in: 1000...9999)
        let folioGen = "\(letras)-\(numeros)"
        let id = UUID().uuidString
        let fecha = Int64(Date().timeIntervalSince1970 * 1000)
        
        let nuevo = AmigoPascuali(id: id, folio: folioGen, nombre: nombre, direccion: dir, telefono: tel, facebook: face, necesidad: necesidad, fecha: fecha, latitud: lat, longitud: long)
        
        // 1. Enviar a Nube (Global)
        ref.child(id).setValue(nuevo.toDictionary())
        
        // 2. Guardar en Lista Local
        registrosActuales.append(nuevo)
        guardarEnDisco() // <--- ¡AQUÍ ASEGURAMOS QUE NO SE OLVIDE!
    }
    
    // Borrar SOLO de la lista del celular (limpiar lote)
    func borrarLocalmente(at offsets: IndexSet) {
        registrosActuales.remove(atOffsets: offsets)
        guardarEnDisco() // <--- ACTUALIZAR MEMORIA
    }
    
    func actualizarRegistro(_ editado: AmigoPascuali) {
        // Nube
        ref.child(editado.id).updateChildValues(editado.toDictionary())
        
        // Local
        if let index = registrosActuales.firstIndex(where: { $0.id == editado.id }) {
            registrosActuales[index] = editado
            guardarEnDisco() // <--- ACTUALIZAR MEMORIA
        }
    }
    
    func reportarError(registro: AmigoPascuali, motivo: String) {
        let reporteRef = refReportes.childByAutoId()
        let datosReporte: [String: Any] = [
            "folio": registro.folio,
            "idRegistro": registro.id,
            "nombre": registro.nombre,
            "motivo": motivo,
            "fechaReporte": ServerValue.timestamp()
        ]
        reporteRef.setValue(datosReporte)
    }
    
    // --- GENERAR EXCEL ---
    func cerrarLote() {
        let formatoFecha = DateFormatter()
        formatoFecha.dateFormat = "yyyy-MM-dd_HH-mm"
        let fechaString = formatoFecha.string(from: Date())
        
        let nombreArchivo = "Lote_Trabajo_\(fechaString).csv"
        let textoCSV = generarCSV()
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(nombreArchivo)
            do {
                let bom = "\u{FEFF}"
                try (bom + textoCSV).write(to: fileURL, atomically: true, encoding: .utf8)
                cargarListaDeArchivos()
                // OPCIONAL: Si quisieras limpiar la lista al generar el archivo, descomenta esto:
                // registrosActuales.removeAll()
                // guardarEnDisco()
            } catch { print("Error guardando CSV") }
        }
    }
    
    func generarCSV() -> String {
        var csv = "Folio,Nombre,Direccion,Telefono,Facebook,Necesidad\n"
        for r in registrosActuales {
            let necesidadLimpia = r.necesidad.replacingOccurrences(of: "\n", with: " ")
            let facebookLimpio = r.facebook.replacingOccurrences(of: ",", with: " ")
            csv += "\(r.folio),\(r.nombre),\(r.direccion),\(r.telefono),\(facebookLimpio),\(necesidadLimpia)\n"
        }
        return csv
    }
    
    func cargarListaDeArchivos() {
        let fm = FileManager.default
        if let docDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let items = try fm.contentsOfDirectory(at: docDir, includingPropertiesForKeys: nil)
                archivosDeLotes = items.filter { $0.pathExtension == "csv" }
                archivosDeLotes.sort {
                    let date1 = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2
                }
            } catch { print("Error listando archivos") }
        }
    }
}
