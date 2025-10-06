import SwiftUI
import AVFoundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct EscanerQRView: View {
    @Environment(\.dismiss) var dismiss
    var onCodigoEscaneado: (String) -> Void
    @StateObject private var viewModel = QRScannerViewModel()

    var body: some View {
        VStack {
            QRScannerPreview(session: viewModel.session)
                .frame(height: 300)
                .cornerRadius(10)
                .padding()

            Text("Escanea un código QR")
                .font(.headline)

            Button("Cerrar") {
                dismiss()
            }
            .padding()
        }
        .onAppear {
            viewModel.startScanning()
            viewModel.onCodigoDetectado = { code in
                onCodigoEscaneado(code)
                dismiss()
            }
        }
        .onDisappear {
            viewModel.stopScanning()
        }
    }
}


struct DetalleEnvioView: View {
    @State var envio: Envio
    @State private var escaneandoQR = false
    @State private var mostrarEditor = false
    @State private var mostrarAlertaQRRepetido = false
    @State private var codigoRepetido = ""
    private let db = Firestore.firestore()

    func colorEstado(_ estado: EstadoEnvio) -> Color {
        switch estado {
        case .pendiente:
            return .orange
        case .enProceso:
            return .blue
        case .finalizado:
            return .green
        }
    }

    
    var body: some View {
        VStack(alignment: .leading) {
            // Encabezado del envío
            VStack(alignment: .leading, spacing: 0) {
                
                HStack {
                    Spacer()
                    Button(action: {
                        mostrarEditor = true
                    }) {
                        Image(systemName: "pencil")
                            .imageScale(.medium)
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Circle())
                    }
                }

                
                HStack {
                                    Text(envio.estado.rawValue)
                                        .font(.caption)
                                        .bold()
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(colorEstado(envio.estado))
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                    Spacer()
                                }
                                .padding(.bottom, 8)
                
                HStack {
                    Image(systemName: "doc.text")
                    Text("Orden:")
                        .bold()
                    Spacer()
                    Text(envio.numeroOrden)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)

                Divider()

                HStack {
                    Image(systemName: "person.crop.circle")
                    Text("Cliente:")
                        .bold()
                    Spacer()
                    Text(envio.cliente)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)

                Divider()

                HStack {
                    Image(systemName: "calendar")
                    Text("Fecha compromiso:")
                        .bold()
                    Spacer()
                    Text(envio.fechaCompromiso.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
            .padding(.horizontal)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)



            // Botón para escanear QR
            Button(action: {
                escaneandoQR = true
            }) {
                Label("Escanear código QR", systemImage: "qrcode.viewfinder")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            Divider().padding(.vertical, 10)

            // Lista de códigos escaneados
            Text("Códigos escaneados:")
                .font(.headline)
                .padding(.horizontal)

            List(envio.codigosQR, id: \.self) { code in
                Text(code)
            }
        }
        .navigationTitle("Detalle del Envío")
        
        .sheet(isPresented: $escaneandoQR) {
            EscanerQRView { codigoEscaneado in
                let codigoRef = db.collection("codigosQRGlobales").document(codigoEscaneado)

                codigoRef.getDocument { document, error in
                    if let document = document, document.exists {
                        // Ya existe: mostramos alerta
                        codigoRepetido = codigoEscaneado
                        mostrarAlertaQRRepetido = true
                    } else {
                        // No existe: lo agregamos
                        envio.codigosQR.append(codigoEscaneado)
                        guardarEnvioActualizado()

                        codigoRef.setData(["usadoEnEnvio": envio.id ?? ""])
                    }
                }
            }
        }
        
        
        .alert("Código ya utilizado", isPresented: $mostrarAlertaQRRepetido) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("El código '\(codigoRepetido)' ya ha sido escaneado en otro envío.")
        }


        
        // ✅ Sheet para editar el envío
        .sheet(isPresented: $mostrarEditor) {
            FormularioEnvioView(envio: envio) { envioActualizado in
                self.envio = envioActualizado
                guardarEnvioActualizado()
            }
        }
    }

    func guardarEnvioActualizado() {
        guard let id = envio.id else { return }
        do {
            try db.collection("envios").document(id).setData(from: envio)
        } catch {
            print("❌ Error al actualizar envío: \(error)")
        }
    }
}



func guardarEnvioEnFirestore(_ envio: Envio) {
    let db = Firestore.firestore()
    db.collection("envios").addDocument(data: [
        "numeroOrden": envio.numeroOrden,
        "cliente": envio.cliente,
        "fechaCompromiso": envio.fechaCompromiso
    ]) { error in
        if let error = error {
            print("❌ Error al guardar en Firestore: \(error.localizedDescription)")
        } else {
            print("✅ Envío guardado correctamente")
        }
    }
}


// MARK: - Enum del menú
enum MenuOption: String, CaseIterable, Identifiable {
    case scanner = "Escáner QR"
    case dashboardEnvios = "Dashboard envíos"
    case dashboardKPI = "Dashboard KPI Electrónica"
    case lotes2024 = "Lotes 2024"
    case timesheet = "Timesheet"
    case numerosSerie = "Números de serie 2022-2023"
    case colaboradores = "Colaboradores"
    case productos = "Productos"
    case rma = "RMA"
    case planProduccion = "Plan de Producción 2025"
    case etiquetado = "Etiquetado de cajas"

    var id: String { self.rawValue }

    var iconName: String {
        switch self {
        case .scanner: return "qrcode.viewfinder"
        case .dashboardEnvios: return "list.bullet.rectangle"
        case .dashboardKPI: return "chart.line.uptrend.xyaxis"
        case .lotes2024: return "shippingbox.circle"
        case .timesheet: return "checklist"
        case .numerosSerie: return "cube.box.fill"
        case .colaboradores: return "person.2.fill"
        case .productos: return "dot.arrowtriangles.up.right.down.left.circle"
        case .rma: return "doc.text.viewfinder"
        case .planProduccion: return "calendar"
        case .etiquetado: return "archivebox"
        }
    }
}

// MARK: - Vista principal con menú hamburguesa
struct MainView: View {
    @State private var showMenu = false
    @State private var selectedOption: MenuOption = .dashboardEnvios

    var body: some View {
        ZStack {
            NavigationView {
                Group {
                    switch selectedOption {
                    case .scanner:
                        QRScannerView()
                    case .dashboardEnvios:
                        DashboardEnviosView()
                    default:
                        PlaceholderView(text: selectedOption.rawValue)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            withAnimation {
                                showMenu.toggle()
                            }
                        }) {
                            Image(systemName: "line.horizontal.3")
                                .imageScale(.large)
                        }
                    }

                    ToolbarItem(placement: .principal) {
                        Text("Producción Electrónica")
                            .font(.headline)
                            .padding(.top, 8)
                    }
                }
            }

            // Fondo oscuro + Menú lateral
            if showMenu {
                ZStack(alignment: .leading) {
                    // Fondo semitransparente
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            withAnimation {
                                showMenu = false
                            }
                        }

                    // Menú pegado a la izquierda
                    SideMenu(selectedOption: $selectedOption, showMenu: $showMenu)
                        .frame(width: 280)
                        .transition(.move(edge: .leading))
                }
                .zIndex(1) // Asegura que esté sobre la vista principal
            }
        }
    }
}


// MARK: - Menú lateral
struct SideMenu: View {
    @Binding var selectedOption: MenuOption
    @Binding var showMenu: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "building.columns")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .foregroundColor(.orange)

                Text("Producción Electrónica 2.0")
                    .font(.headline)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            Divider()
                .padding(.top, 20)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(MenuOption.allCases) { option in
                    Button(action: {
                        withAnimation {
                            selectedOption = option
                            showMenu = false
                        }
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: option.iconName)
                                .foregroundColor(.gray)
                                .frame(width: 24, alignment: .center)

                            Text(option.rawValue)
                                .foregroundColor(selectedOption == option ? .orange : .primary)
                                .fontWeight(selectedOption == option ? .bold : .regular)

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .background(selectedOption == option ? Color.orange.opacity(0.1) : Color.clear)
                        .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Vista temporal
struct PlaceholderView: View {
    let text: String

    var body: some View {
        Text("Sección: \(text)")
            .font(.title)
            .padding()
    }
}

// MARK: - Vista Escáner QR
struct QRScannerView: View {
    @StateObject private var viewModel = QRScannerViewModel()
    @State private var torchIsOn = false

    var body: some View {
        VStack {
            QRScannerPreview(session: viewModel.session)
                .frame(height: 300)
                .cornerRadius(12)
                .padding()

            HStack {
                Button(action: {
                    torchIsOn.toggle()
                    viewModel.toggleTorch(torchIsOn)
                }) {
                    Image(systemName: torchIsOn ? "bolt.fill" : "bolt.slash.fill")
                        .padding()
                        .background(Circle().fill(Color.gray.opacity(0.2)))
                }

                Button("Limpiar") {
                    viewModel.scannedCodes.removeAll()
                }
                .padding()
                .background(Capsule().fill(Color.gray.opacity(0.2)))
            }

            List(viewModel.scannedCodes, id: \.self) { code in
                Text(code)
            }
        }
        .onAppear {
            viewModel.startScanning()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
    }
}

// MARK: - Preview de la cámara
struct QRScannerPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds

        view.layer.insertSublayer(previewLayer, at: 0)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

// MARK: - ViewModel del escáner QR
class QRScannerViewModel: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    var onCodigoDetectado: ((String) -> Void)?
    private let metadataOutput = AVCaptureMetadataOutput()
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.yourapp.session.queue")
    private var captureDevice: AVCaptureDevice?
    @Published var scannedCodes: [String] = []

    override init() {
        super.init()
        setupCaptureSession()
    }

    private func setupCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            guard let device = AVCaptureDevice.default(for: .video) else {
                print("Error: No se pudo acceder a la cámara")
                return
            }

            self.captureDevice = device

            do {
                let input = try AVCaptureDeviceInput(device: device)

                self.session.beginConfiguration()

                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }

                if self.session.canAddOutput(self.metadataOutput) {
                    self.session.addOutput(self.metadataOutput)
                    self.metadataOutput.metadataObjectTypes = [.qr]
                    self.metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                }

                self.session.commitConfiguration()
            } catch {
                print("Error al configurar la cámara: \(error.localizedDescription)")
            }
        }
    }

    func startScanning() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopScanning() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func toggleTorch(_ on: Bool) {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let device = self.captureDevice,
                  device.hasTorch else { return }

            do {
                try device.lockForConfiguration()
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
            } catch {
                print("Error al configurar el flash: \(error)")
            }
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadata.stringValue else { return }
        
        if !scannedCodes.contains(stringValue) {
            scannedCodes.append(stringValue)
            onCodigoDetectado?(stringValue)
        }
        
    }
}

// MARK: - Modelo de Envío
enum EstadoEnvio: String, Codable, CaseIterable {
    case pendiente = "Pendiente"
    case enProceso = "En proceso"
    case finalizado = "Finalizado"
}

struct Envio: Identifiable, Codable, Equatable {
    @DocumentID var id: String? = UUID().uuidString
    var numeroOrden: String
    var cliente: String
    var fechaCompromiso: Date
    var codigosQR: [String] = []
    var estado: EstadoEnvio = .pendiente
}

// MARK: - Dashboard de Envíos
struct DashboardEnviosView: View {
    @State private var envios: [Envio] = []
    @State private var showingForm = false
    @State private var envioAEditar: Envio? = nil
    @State private var mostrarAlertaEliminacion = false
    @State private var indiceAEliminar: IndexSet? = nil
    @State private var envioSeleccionado: Envio?

    private let db = Firestore.firestore()

    var body: some View {
        NavigationView {
            List {
                    ForEach(envios) { envio in
                        NavigationLink(destination: DetalleEnvioView(envio: envio)) {
                            VStack(alignment: .leading) {
                                Text("Orden: \(envio.numeroOrden)").bold()
                                Text("Cliente: \(envio.cliente)")
                                Text("Fecha compromiso: \(envio.fechaCompromiso.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                .onDelete { indexSet in
                    indiceAEliminar = indexSet
                    mostrarAlertaEliminacion = true
                }
            }
            .navigationTitle("Dashboard envíos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        envioAEditar = nil
                        showingForm = true
                    }) {
                        Image(systemName: "plus")
                            .imageScale(.large)
                    }
                }
            }
            .onAppear {
                suscribirseAEnvios()
            }
            .sheet(isPresented: $showingForm) {
                FormularioEnvioView(envio: envioAEditar) { nuevoEnvio in
                    guardarEnvio(nuevoEnvio)
                }
            }
            // Alerta para confirmar eliminación de orden
            .alert("¿Eliminar esta orden?", isPresented: $mostrarAlertaEliminacion, actions: {
                Button("Eliminar", role: .destructive) {
                    if let indexSet = indiceAEliminar {
                        eliminarEnvio(at: indexSet)
                    }
                }
                Button("Cancelar", role: .cancel) {
                    indiceAEliminar = nil
                }
            }, message: {
                Text("Esta acción no se puede deshacer.")
            })
        }
    }


    // Suscripción en tiempo real
    func suscribirseAEnvios() {
        db.collection("envios")
            .order(by: "fechaCompromiso")
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("❌ Error al leer envíos: \(error?.localizedDescription ?? "Desconocido")")
                    return
                }

                self.envios = documents.compactMap { doc in
                    try? doc.data(as: Envio.self)
                }
            }
    }

    // 💾 Guardar o actualizar envío
    func guardarEnvio(_ envio: Envio) {
        do {
            if let id = envio.id {
                try db.collection("envios").document(id).setData(from: envio)
            }
        } catch {
            print("❌ Error al guardar envío: \(error.localizedDescription)")
        }
    }

    // 🗑️ Eliminar envío
    func eliminarEnvio(at offsets: IndexSet) {
        offsets.forEach { index in
            if let id = envios[index].id {
                db.collection("envios").document(id).delete { error in
                    if let error = error {
                        print("❌ Error al eliminar: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

// MARK: - Formulario para agregar un nuevo envío
struct FormularioEnvioView: View {
    @Environment(\.dismiss) var dismiss
    @State var envio: Envio?
    @State private var estado: EstadoEnvio = .pendiente
    var onGuardar: (Envio) -> Void

    @State private var numeroOrden = ""
    @State private var cliente = ""
    @State private var fechaCompromiso = Date()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Datos del envío")) {
                    TextField("Número de orden", text: $numeroOrden)
                    TextField("Cliente", text: $cliente)
                    DatePicker("Fecha compromiso", selection: $fechaCompromiso, displayedComponents: .date)

                    // ✅ Picker para seleccionar el estado del envío
                    Picker("Estado", selection: $estado) {
                        ForEach(EstadoEnvio.allCases, id: \.self) { estado in
                            Text(estado.rawValue)
                        }
                    }
                    .pickerStyle(.segmented) // Estilo Apple
                }
            }
            .navigationTitle(envio == nil ? "Nuevo envío" : "Editar envío")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let nuevo = Envio(
                            id: envio?.id ?? UUID().uuidString,
                            numeroOrden: numeroOrden,
                            cliente: cliente,
                            fechaCompromiso: fechaCompromiso,
                            codigosQR: envio?.codigosQR ?? [],
                            estado: estado
                        )
                        onGuardar(nuevo)
                        dismiss()
                    }
                    .disabled(numeroOrden.isEmpty || cliente.isEmpty)
                }
            }
        }
        .onAppear {
            if let envio = envio {
                numeroOrden = envio.numeroOrden
                cliente = envio.cliente
                fechaCompromiso = envio.fechaCompromiso
                estado = envio.estado
            }
        }
    }
}

