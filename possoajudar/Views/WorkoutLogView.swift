import SwiftUI

struct WorkoutLogView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var claude: ClaudeService
    @EnvironmentObject private var persistence: PersistenceService

    var onComplete: ((TrainerResponse) -> Void)?

    @State private var workoutType: WorkoutType = .indoorCycling
    @State private var durationMin: Int = 45
    @State private var avgHR: String = ""
    @State private var peakHR: String = ""
    @State private var rpe: Int = 7
    @State private var notes: String = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo de Treino") {
                    Picker("Modalidade", selection: $workoutType) {
                        ForEach([WorkoutType.indoorCycling, .elliptical, .outdoorCycling, .walk, .mobility, .other], id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section("Duração") {
                    Stepper("\(durationMin) min", value: $durationMin, in: 5...180, step: 5)
                }

                Section("Frequência Cardíaca") {
                    HStack {
                        Text("FC Média (bpm)")
                        Spacer()
                        TextField("ex: 162", text: $avgHR)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("FC Pico (bpm)")
                        Spacer()
                        TextField("ex: 178", text: $peakHR)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Esforço Percebido (RPE)")
                            Spacer()
                            Text("\(rpe)/10")
                                .font(.headline)
                                .foregroundColor(rpeColor)
                        }
                        Slider(value: Binding(
                            get: { Double(rpe) },
                            set: { rpe = Int($0) }
                        ), in: 1...10, step: 1)
                        .tint(rpeColor)

                        Text(rpeLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Esforço")
                }

                Section("Observações") {
                    TextField("Como foi o treino? Algo que notar...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button(action: submitWorkout) {
                        if isLoading {
                            HStack {
                                ProgressView().tint(.white)
                                Text("Analisando com o trainer...")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Label("Registrar e Analisar", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                                .font(.headline)
                        }
                    }
                    .listRowBackground(Color.blue)
                    .foregroundColor(.white)
                    .disabled(isLoading)
                }
            }
            .navigationTitle("Registrar Treino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private var rpeColor: Color {
        switch rpe {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        default: return .red
        }
    }

    private var rpeLabel: String {
        switch rpe {
        case 1...3: return "Leve — conversa fácil"
        case 4...5: return "Moderado — respiração mais forte"
        case 6...7: return "Difícil — zona de limiar"
        case 8...9: return "Muito difícil — quase máximo"
        default: return "Máximo absoluto"
        }
    }

    private func submitWorkout() {
        isLoading = true
        error = nil

        Task {
            // Build workout data
            let avgHRVal = Double(avgHR)
            let peakHRVal = Double(peakHR)

            let hrZones: HRZones?
            if let avg = avgHRVal {
                let pct = avg / 190.0
                if pct >= 0.90 {
                    hrZones = HRZones(z1Pct: 2, z2Pct: 5, z3Pct: 10, z4Pct: 30, z5Pct: 53)
                } else if pct >= 0.80 {
                    hrZones = HRZones(z1Pct: 5, z2Pct: 10, z3Pct: 20, z4Pct: 55, z5Pct: 10)
                } else if pct >= 0.70 {
                    hrZones = HRZones(z1Pct: 10, z2Pct: 20, z3Pct: 40, z4Pct: 25, z5Pct: 5)
                } else {
                    hrZones = HRZones(z1Pct: 15, z2Pct: 50, z3Pct: 25, z4Pct: 8, z5Pct: 2)
                }
            } else {
                hrZones = nil
            }

            // Estimate calories: ~8 kcal/min for high intensity cycling
            let estimatedCal = Double(durationMin) * (avgHRVal.map { $0 >= 155 ? 10.0 : 7.0 } ?? 8.0)

            let workout = WorkoutData(
                type: workoutType,
                durationMin: durationMin,
                avgHr: avgHRVal,
                peakHr: peakHRVal,
                hrZones: hrZones,
                rpe: rpe,
                caloriesEstimated: estimatedCal,
                notes: notes.isEmpty ? nil : notes,
                hasScreenshot: false
            )

            // Save manual workout entry
            let intensity: WorkoutIntensity = avgHRVal.map { $0 >= 165 ? .high : ($0 >= 145 ? .moderate : .low) } ?? .moderate
            let entry = WorkoutEntry(
                date: Date(),
                type: workoutType,
                durationMin: durationMin,
                avgHr: avgHRVal,
                peakHr: peakHRVal,
                hrZones: hrZones,
                rpe: rpe,
                caloriesEstimated: estimatedCal,
                notes: notes.isEmpty ? nil : notes,
                intensity: intensity
            )
            persistence.saveManualWorkout(entry)

            // Fetch health snapshot for context
            let snapshot = await healthKit.fetchHealthSnapshot()
            let context = await healthKit.buildContext(
                from: snapshot,
                timeOfDay: .postWorkout,
                workout: workout,
                userMessage: notes.isEmpty ? nil : notes
            )

            do {
                let response = try await claude.fetchAnalysis(context: context)
                persistence.save(response: response)
                await MainActor.run {
                    onComplete?(response)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
