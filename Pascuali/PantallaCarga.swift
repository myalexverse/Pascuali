//
//  PantallaCarga.swift
//  Pascuali
//
//  Created by Alex Tovar on 30/12/25.
//
import SwiftUI

struct PantallaCarga: View {
    @Binding var estaActiva: Bool
    
    // Definimos el azul profesional que pediste
    let azulProfesional = Color(red: 0.0, green: 0.3, blue: 0.7)
    
    var body: some View {
        ZStack {
            // 1. FONDO: Foto real con filtro elegante
            Image("fondo_profesional") // ¡Asegúrate de tener esta imagen en Assets!
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .overlay(
                    // Capa azul degradada encima de la foto para que el texto resalte
                    LinearGradient(
                        gradient: Gradient(colors: [azulProfesional.opacity(0.6), Color.black.opacity(0.8)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // 2. CONTENIDO CENTRAL
            VStack(spacing: 10) {
                Spacer()
                
                // Título Principal con fuente IMPACT
                Text("REGISTRO")
                    .font(.custom("Impact", size: 50)) // Usamos la fuente personalizada
                    .foregroundColor(.white) // Blanco para contraste
                    .shadow(color: azulProfesional, radius: 10, x: 0, y: 0) // Resplandor azul
                
                Text("CIUDADANO")
                    .font(.custom("Impact", size: 65))
                    .foregroundColor(azulProfesional) // Azul profesional
                    .shadow(color: .black, radius: 5, x: 0, y: 5) // Sombra para profundidad
                
                Spacer()
                
                // Indicador de carga azul
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(azulProfesional)
                    .padding(.bottom, 60)
            }
            .padding()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation(.easeOut(duration: 0.8)) {
                    estaActiva = true
                }
            }
        }
    }
}
