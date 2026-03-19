import Foundation

/// On-device readiness score calculation — no API call required.
/// Algorithm matches system prompt specification exactly.
enum ReadinessCalculator {

    /// HRV baseline for Matheus (updated over time via UserDefaults)
    static var hrvBaseline: Double {
        get { UserDefaults.standard.double(forKey: "hrv_baseline").nonZero ?? 45.0 }
        set { UserDefaults.standard.set(newValue, forKey: "hrv_baseline") }
    }

    /// Resting HR baseline for Matheus
    static var hrBaseline: Double {
        get { UserDefaults.standard.double(forKey: "hr_baseline").nonZero ?? 58.0 }
        set { UserDefaults.standard.set(newValue, forKey: "hr_baseline") }
    }

    struct Result {
        let score: Int
        let label: String
        let color: String // "green" | "yellow" | "red" | "blue"
        let primarySignal: String
        let breakdown: Breakdown
    }

    struct Breakdown {
        let hrvContribution: Int   // -35 … +35
        let hrContribution: Int    // -25 … +25
        let sleepContribution: Int // -25 … 0
        let fatigueContribution: Int // -15 … 0
        let baseScore: Int         // always 100 before adjustments
    }

    static func calculate(hrv: Double?,
                          restingHR: Double?,
                          sleepHours: Double?,
                          consecutiveDays: Int) -> Result {

        var score = 100
        var primarySignal = ""
        var dominantFactor = ""
        var dominantValue = 0

        // ── HRV (weight 35%) ────────────────────────────────────────────
        var hrvContrib = 0
        if let hrv {
            let delta = (hrv - hrvBaseline) / max(hrvBaseline, 1)
            hrvContrib = Int(delta * 35)
            hrvContrib = max(-35, min(35, hrvContrib))
            score += hrvContrib
            if abs(hrvContrib) > abs(dominantValue) {
                dominantValue = hrvContrib
                dominantFactor = String(format: "HRV %.0f ms (%+.0f%%)", hrv, delta * 100)
            }
        }

        // ── Resting HR (weight 25%) ──────────────────────────────────────
        var hrContrib = 0
        if let rhr = restingHR {
            let delta = (hrBaseline - rhr) / max(hrBaseline, 1)
            hrContrib = Int(delta * 25)
            hrContrib = max(-25, min(25, hrContrib))
            score += hrContrib
            if abs(hrContrib) > abs(dominantValue) {
                dominantValue = hrContrib
                dominantFactor = String(format: "FC repouso %.0f bpm", rhr)
            }
        }

        // ── Sleep (weight 25%) ───────────────────────────────────────────
        var sleepContrib = 0
        if let sleep = sleepHours {
            if sleep < 5 { sleepContrib = -25 }
            else if sleep < 6 { sleepContrib = -15 }
            else if sleep < 7 { sleepContrib = -5 }
            score += sleepContrib
            if abs(sleepContrib) > abs(dominantValue) {
                dominantValue = sleepContrib
                dominantFactor = String(format: "Sono %.1fh", sleep)
            }
        }

        // ── Consecutive training days (weight 15%) ───────────────────────
        var fatigueContrib = 0
        if consecutiveDays >= 5 { fatigueContrib = -15 }
        else if consecutiveDays >= 4 { fatigueContrib = -8 }
        else if consecutiveDays >= 3 { fatigueContrib = -3 }
        score += fatigueContrib
        if abs(fatigueContrib) > abs(dominantValue) {
            dominantValue = fatigueContrib
            dominantFactor = "\(consecutiveDays) dias seguidos de treino"
        }

        let finalScore = max(0, min(100, score))

        // ── Label & color ────────────────────────────────────────────────
        let (label, color) = labelAndColor(score: finalScore)

        // ── Primary signal ───────────────────────────────────────────────
        if dominantFactor.isEmpty {
            primarySignal = "Dados insuficientes"
        } else if dominantValue > 0 {
            primarySignal = dominantFactor
        } else {
            primarySignal = dominantFactor
        }

        // Update baselines with exponential moving average (α = 0.1)
        if let hrv { updateHRVBaseline(newValue: hrv) }
        if let rhr = restingHR { updateHRBaseline(newValue: rhr) }

        return Result(
            score: finalScore,
            label: label,
            color: color,
            primarySignal: primarySignal,
            breakdown: Breakdown(
                hrvContribution: hrvContrib,
                hrContribution: hrContrib,
                sleepContribution: sleepContrib,
                fatigueContribution: fatigueContrib,
                baseScore: 100
            )
        )
    }

    private static func labelAndColor(score: Int) -> (String, String) {
        switch score {
        case 80...: return ("Em forma", "blue")
        case 65..<80: return ("Pronto", "green")
        case 45..<65: return ("Recuperando", "yellow")
        default: return ("Fatigado", "red")
        }
    }

    private static func updateHRVBaseline(newValue: Double) {
        let alpha = 0.1
        let updated = alpha * newValue + (1 - alpha) * hrvBaseline
        hrvBaseline = updated
    }

    private static func updateHRBaseline(newValue: Double) {
        let alpha = 0.1
        let updated = alpha * newValue + (1 - alpha) * hrBaseline
        hrBaseline = updated
    }
}

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
