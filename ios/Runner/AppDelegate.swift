import UIKit
import Flutter
import HealthKit

@main
@objc class AppDelegate: FlutterAppDelegate {

    let healthStore = HKHealthStore()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        GeneratedPluginRegistrant.register(with: self)

        guard let controller = window?.rootViewController as? FlutterViewController else {
            fatalError("rootViewController is not FlutterViewController")
        }

        // 📢 EKG MethodChannel
        let ekgChannel = FlutterMethodChannel(name: "com.bitirme/ekg", binaryMessenger: controller.binaryMessenger)
        ekgChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            if call.method == "getEKG" {
                self.fetchEKG(result: result)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        // 📢 HealthKit MethodChannel
        let healthChannel = FlutterMethodChannel(name: "com.uyg/health", binaryMessenger: controller.binaryMessenger)
        healthChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }

            switch call.method {
            case "fetchHealthData":
                if let dateStr = call.arguments as? String {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let date = formatter.date(from: dateStr) {
                        self.fetchHealthData(for: date) { data in
                            result(data)
                        }
                    } else {
                        result(FlutterError(code: "INVALID_DATE", message: "Tarih formatı hatalı", details: nil))
                    }
                } else {
                    result(FlutterError(code: "MISSING_ARGUMENT", message: "Tarih argümanı eksik", details: nil))
                }
            case "requestAuthorization":
                self.requestHealthAuthorization(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // 📊 Sağlık Verilerini Çek
    func fetchHealthData(for date: Date, completion: @escaping ([String: Any]) -> Void) {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!

        let types: [HKQuantityTypeIdentifier] = [
            .stepCount, .distanceWalkingRunning, .activeEnergyBurned,
            .appleExerciseTime, .appleStandTime
        ]

        var results: [String: Any] = [
            "steps": 0,
            "distance": 0.0,
            "calories": 0.0,
            "moveCalories": 0.0,
            "exerciseMinutes": 0,
            "standHours": 0
        ]

        let group = DispatchGroup()

        for type in types {
            group.enter()
            if let quantityType = HKObjectType.quantityType(forIdentifier: type) {
                let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
                let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                    if let sum = stats?.sumQuantity() {
                        switch type {
                        case .stepCount:
                            results["steps"] = Int(sum.doubleValue(for: .count()))
                        case .distanceWalkingRunning:
                            results["distance"] = sum.doubleValue(for: HKUnit.meter())
                        case .activeEnergyBurned:
                            results["calories"] = sum.doubleValue(for: .kilocalorie())
                            results["moveCalories"] = sum.doubleValue(for: .kilocalorie())
                        case .appleExerciseTime:
                            results["exerciseMinutes"] = Int(sum.doubleValue(for: HKUnit.minute()))
                        case .appleStandTime:
                            results["standHours"] = Int(sum.doubleValue(for: HKUnit.hour()))
                        default:
                            break
                        }
                    }
                    group.leave()
                }
                healthStore.execute(query)
            } else {
                group.leave() // Geçersiz tip için gruptan çık
            }
        }

        group.notify(queue: .main) {
            completion(results)
        }
    }

    // 📢 HealthKit Yetki İsteği
    func requestHealthAuthorization(result: @escaping FlutterResult) {
        var typesToRead: Set<HKObjectType> = []
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .stepCount, .distanceWalkingRunning, .activeEnergyBurned,
            .appleExerciseTime, .appleStandTime
        ]
        for type in quantityTypes {
            if let quantityType = HKObjectType.quantityType(forIdentifier: type) {
                typesToRead.insert(quantityType)
            }
        }
        typesToRead.insert(HKObjectType.electrocardiogramType()) // ⚠️ force unwrap kaldırıldı

        healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
            if success {
                result(true)
            } else {
                result(FlutterError(code: "AUTH_ERROR", message: "HealthKit yetkisi alınamadı", details: error?.localizedDescription))
            }
        }
    }

    // 🩺 EKG Verilerini Çek
    private func fetchEKG(result: @escaping FlutterResult) {
        guard HKHealthStore.isHealthDataAvailable() else {
            result(FlutterError(code: "UNAVAILABLE", message: "Health data not available", details: nil))
            return
        }

        let ekgType = HKObjectType.electrocardiogramType() // ⚠️ force unwrap kaldırıldı
        healthStore.requestAuthorization(toShare: nil, read: [ekgType]) { granted, error in
            if !granted {
                result(FlutterError(code: "PERMISSION_DENIED", message: "EKG yetkisi verilmedi", details: nil))
                return
            }

            let query = HKSampleQuery(
                sampleType: ekgType,
                predicate: nil,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { [weak self] _, samples, error in
                guard let self = self, let samples = samples as? [HKElectrocardiogram], error == nil else {
                    result(FlutterError(code: "QUERY_FAILED", message: "EKG sorgusu başarısız", details: nil))
                    return
                }

                var output: [[String: Any]] = []
                let group = DispatchGroup()

                for ekg in samples {
                    group.enter()
                    self.readVoltages(for: ekg) { voltages in
                        let data: [String: Any] = [
                            "date": ISO8601DateFormatter().string(from: ekg.startDate),
                            "classification": ekg.classification.description,
                            "averageHeartRate": ekg.averageHeartRate?.doubleValue(for: .count().unitDivided(by: .minute())) ?? 0,
                            "voltages": voltages
                        ]
                        output.append(data)
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    result(output)
                }
            }

            self.healthStore.execute(query)
        }
    }

    private func readVoltages(for ekg: HKElectrocardiogram, completion: @escaping ([Double]) -> Void) {
        var voltages: [Double] = []

        let voltageQuery = HKElectrocardiogramQuery(electrocardiogram: ekg) { (_, voltageMeasurement, done, _) in
            if let voltageMeasurement = voltageMeasurement,
               let quantity = voltageMeasurement.quantity(for: .appleWatchSimilarToLeadI) {
                let microvolts = quantity.doubleValue(for: .init(from: "µV"))
                voltages.append(microvolts)
            }
            if done {
                completion(voltages)
            }
        }
        healthStore.execute(voltageQuery)
    }
}

// MARK: - EKG Classification Açıklamaları
extension HKElectrocardiogram.Classification {
    var description: String {
        switch self {
        case .notSet: return "Bilinmiyor"
        case .sinusRhythm: return "Sinüs Ritmi"
        case .atrialFibrillation: return "Atriyal Fibrilasyon"
        case .inconclusiveLowHeartRate: return "Düşük Nabız - Belirsiz"
        case .inconclusiveHighHeartRate: return "Yüksek Nabız - Belirsiz"
        case .inconclusivePoorReading: return "Zayıf Okuma"
        case .inconclusiveOther: return "Belirsiz"
        case .unrecognized: return "Tanımlanamayan"
        @unknown default: return "Bilinmeyen"
        }
    }
}