# 🗳️ Pascuali — Ingeniería Electoral de Campo

**App iOS profesional para trabajo de campo político en San Miguel de Allende, Guanajuato.**

Pascuali es una herramienta de ingeniería política diseñada para planificar, ejecutar y medir operaciones de campo rumbo a la presidencia municipal de San Miguel de Allende 2027. Integra datos electorales reales del INE con georreferenciación en tiempo real.

![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![iOS](https://img.shields.io/badge/iOS-17+-blue?logo=apple)
![MapKit](https://img.shields.io/badge/MapKit-Geospatial-green)
![Firebase](https://img.shields.io/badge/Firebase-Realtime_DB-yellow?logo=firebase)

---

## 📸 Capturas

| Mapa Electoral | Secciones & Avance | Captura de Campo |
|:-:|:-:|:-:|
| Mapa con 105 secciones coloreadas | Tablero de avance territorial | Formulario de registro GPS |

---

## 🏗️ Arquitectura

```
Pascuali/
├── PascualiApp.swift          # Entry point (@main)
├── ContentView.swift          # TabView principal (5 tabs)
├── MapViewRepresentable.swift # MKMapView + UIViewRepresentable
├── SeccionesManager.swift     # Parser GeoJSON → MKPolygon
├── SeccionesListView.swift    # Tablero de avance por sección
├── PascualiData.swift         # Modelo de datos + GestorDatos
├── LocationManager.swift      # CLLocationManager wrapper
├── PantallaCarga.swift        # Splash screen
└── secciones_sma.geojson      # 105 secciones electorales (WGS84)
```

## 🗺️ Funcionalidades

### Mapa Electoral Interactivo
- **105 secciones electorales** del municipio renderizadas como polígonos `MKPolygon` sobre MapKit
- **Paleta de 10 colores vibrantes** para diferenciar cada sección visualmente
- **Dos modos de visualización:** Electoral (colores por sección) y Problemáticas (heatmap rojo por densidad de registros)
- **Tap-to-select** con algoritmo Ray-Casting puro para detección punto-en-polígono
- **Tarjeta analítica flotante** al seleccionar sección: lista nominal, meta de votos, registros levantados, prioridad

### Tablero de Avance Territorial
- **Resumen ejecutivo** con meta global de 31,274 votos (basada en análisis electoral 2024)
- **Barra de progreso por sección** con colores adaptativos (rojo → naranja → amarillo → verde)
- **Meta proporcional:** cada sección recibe su cuota del objetivo global según su peso en la lista nominal
- **Ordenamiento dinámico:** por prioridad, menor avance, o número de sección

### Captura de Campo Georreferenciada
- Formulario con GPS automático (latitud/longitud)
- Cada registro genera un **pin morado** visible en el mapa sobre la sección correspondiente
- Campos: nombre, dirección, teléfono, Facebook, diagnóstico de necesidad
- Folio automático por registro

### Gestión de Lotes
- Cierre de lote y **exportación a CSV**
- Edición de registros con confirmación de borrado
- Sistema de reportes al administrador
- Historial de archivos exportados con ShareLink

## 📊 Análisis Electoral Integrado

La meta de votos se basa en datos reales de la **elección municipal 2024**:

| Concepto | Dato |
|---|---|
| Ganador 2024 (PRI) | 26,274 votos |
| Segundo lugar (Morena) | 24,788 votos |
| Margen de victoria | 1,486 votos |
| **Meta 2027** | **31,274 votos** (+5K de colchón) |
| Lista nominal | ~146,942 electores |

La meta se distribuye **proporcionalmente** a cada sección:

```
Meta_sección = (electores_sección / lista_nominal_total) × 31,274
```

## 🔧 Stack Tecnológico

| Capa | Tecnología |
|---|---|
| **UI** | SwiftUI + UIKit (UIViewRepresentable) |
| **Mapas** | MapKit (MKMapView, MKPolygon, MKPolygonRenderer) |
| **Geolocalización** | CoreLocation |
| **Backend** | Firebase Realtime Database |
| **Datos electorales** | INE Datos Abiertos (GeoJSON procesado) |
| **Algoritmos** | Ray-Casting (punto-en-polígono) |

## ⚙️ Setup

1. Clona el repositorio:
   ```bash
   git clone https://github.com/myalexverse/Pascuali.git
   ```

2. Agrega tu archivo `GoogleService-Info.plist` de Firebase (no incluido por seguridad).

3. Abre `Pascuali.xcodeproj` en Xcode 16+.

4. Selecciona un simulador iPhone o dispositivo físico.

5. `Cmd + R` para compilar y ejecutar.

## 📋 Requisitos

- iOS 17.0+
- Xcode 16.0+
- Cuenta de Firebase (para Realtime Database)

## 👨‍💻 Autor

**Alex Tovar** — Politólogo & Desarrollador iOS  
Diseñado para trabajo de campo político real en San Miguel de Allende, Guanajuato.

## 📄 Licencia

Este proyecto es de uso privado. Todos los derechos reservados.
