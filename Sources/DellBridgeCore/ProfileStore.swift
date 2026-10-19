import Foundation

/// Loading and matching of per-model profiles.
public enum ProfileStore {
    public static func load(from url: URL) throws -> DisplayProfile {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(DisplayProfile.self, from: data)
    }

    /// Loads every `*.json` file in a directory. Malformed files are skipped
    /// and reported in the returned errors rather than aborting the batch.
    public static func loadAll(in directory: URL) -> (profiles: [DisplayProfile], errors: [String]) {
        var profiles: [DisplayProfile] = []
        var errors: [String] = []

        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension.lowercased() == "json" }
        } catch {
            return ([], ["cannot read \(directory.path): \(error.localizedDescription)"])
        }

        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            do {
                profiles.append(try load(from: file))
            } catch {
                errors.append("\(file.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return (profiles, errors)
    }

    /// Finds the most specific profile for a display. A profile with a
    /// product code only matches when the code is present and equal.
    public static func match(
        _ profiles: [DisplayProfile],
        manufacturer: String?,
        model: String?,
        productCode: String? = nil
    ) -> DisplayProfile? {
        guard let model, !model.isEmpty else { return nil }

        return profiles.first { profile in
            if let wanted = profile.match.productCode {
                guard let productCode, wanted.caseInsensitiveCompare(productCode) == .orderedSame else {
                    return false
                }
            }
            if let manufacturer, profile.match.manufacturer.caseInsensitiveCompare(manufacturer) != .orderedSame {
                return false
            }
            return model.uppercased().contains(profile.match.model.uppercased())
        }
    }
}
