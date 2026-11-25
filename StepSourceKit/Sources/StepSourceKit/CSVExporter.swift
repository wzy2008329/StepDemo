import Foundation

public enum CSVExporter {

    public static func csv(from samples: [StepSnapshot]) -> String {
        var lines = ["timestamp,steps,cadence_steps_per_min,stride_meters,distance_meters,total_steps,total_distance_meters,speed_kmh"]

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for sample in samples {
            let row = [
                formatter.string(from: sample.timestamp),
                String(sample.steps),
                String(format: "%.2f", sample.cadence),
                String(format: "%.3f", sample.strideMeters),
                String(format: "%.2f", sample.distanceMeters),
                String(sample.totalSteps),
                String(format: "%.2f", sample.totalDistanceMeters),
                String(format: "%.2f", sample.speedKmh)
            ]
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    public static func writeTempFile(from samples: [StepSnapshot]) throws -> URL {
        let stampFormatter = DateFormatter()
        stampFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "step-sim-\(stampFormatter.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try csv(from: samples).write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
