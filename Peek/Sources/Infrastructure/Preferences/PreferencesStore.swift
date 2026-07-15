import Foundation

protocol PreferencesStoring {
    func array(forKey defaultName: String) -> [Any]?
    func bool(forKey defaultName: String) -> Bool
    func integer(forKey defaultName: String) -> Int
    func object(forKey defaultName: String) -> Any?
    func string(forKey defaultName: String) -> String?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: PreferencesStoring {}
