import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import TelegramCore

public enum MediaAutoDownloadNetworkType {
    case wifi
    case cellular
}

public extension MediaAutoDownloadNetworkType {
    init(_ networkType: NetworkType) {
        switch networkType {
        case .none, .cellular:
            self = .cellular
        case .wifi:
            self = .wifi
        }
    }
}

public enum MediaAutoDownloadPreset: Int32 {
    case low
    case medium
    case high
    case custom
}

public struct MediaAutoDownloadPresets: Codable, Equatable {
    public var low: MediaAutoDownloadCategories
    public var medium: MediaAutoDownloadCategories
    public var high: MediaAutoDownloadCategories
    
    public init(low: MediaAutoDownloadCategories, medium: MediaAutoDownloadCategories, high: MediaAutoDownloadCategories) {
        self.low = low
        self.medium = medium
        self.high = high
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.low = try container.decode(MediaAutoDownloadCategories.self, forKey: "low")
        self.medium = try container.decode(MediaAutoDownloadCategories.self, forKey: "medium")
        self.high = try container.decode(MediaAutoDownloadCategories.self, forKey: "high")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.low, forKey: "low")
        try container.encode(self.medium, forKey: "medium")
        try container.encode(self.high, forKey: "high")
    }
}

public struct MediaAutoDownloadConnection: Codable, Equatable {
    public var enabled: Bool
    public var preset: MediaAutoDownloadPreset
    public var custom: MediaAutoDownloadCategories?
    
    public init(enabled: Bool, preset: MediaAutoDownloadPreset, custom: MediaAutoDownloadCategories?) {
        self.enabled = enabled
        self.preset = preset
        self.custom = custom
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.enabled = try container.decode(Int32.self, forKey: "enabled") != 0
        self.preset = MediaAutoDownloadPreset(rawValue: try container.decode(Int32.self, forKey: "preset")) ?? .medium
        self.custom = try container.decodeIfPresent(MediaAutoDownloadCategories.self, forKey: "custom")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.enabled ? 1 : 0) as Int32, forKey: "enabled")
        try container.encode(self.preset.rawValue, forKey: "preset")
        try container.encodeIfPresent(self.custom, forKey: "custom")
    }
}

public struct MediaAutoDownloadCategories: Codable, Equatable, Comparable {
    public var basePreset: MediaAutoDownloadPreset
    public var photo: MediaAutoDownloadCategory
    public var video: MediaAutoDownloadCategory
    public var file: MediaAutoDownloadCategory
    public var stories: MediaAutoDownloadCategory
    
    public init(basePreset: MediaAutoDownloadPreset, photo: MediaAutoDownloadCategory, video: MediaAutoDownloadCategory, file: MediaAutoDownloadCategory, stories: MediaAutoDownloadCategory) {
        self.basePreset = basePreset
        self.photo = photo
        self.video = video
        self.file = file
        self.stories = stories
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.basePreset = MediaAutoDownloadPreset(rawValue: try container.decode(Int32.self, forKey: "preset")) ?? .medium
        self.photo = try container.decode(MediaAutoDownloadCategory.self, forKey: "photo")
        self.video = try container.decode(MediaAutoDownloadCategory.self, forKey: "video")
        self.file = try container.decode(MediaAutoDownloadCategory.self, forKey: "file")
        self.stories = try container.decodeIfPresent(MediaAutoDownloadCategory.self, forKey: "stories") ?? MediaAutoDownloadSettings.defaultSettings.presets.high.stories
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.basePreset.rawValue, forKey: "preset")
        try container.encode(self.photo, forKey: "photo")
        try container.encode(self.video, forKey: "video")
        try container.encode(self.file, forKey: "file")
        try container.encode(self.stories, forKey: "stories")
    }
    
    public static func < (lhs: MediaAutoDownloadCategories, rhs: MediaAutoDownloadCategories) -> Bool {
        let lhsSizeLimit: Int64 = Int64((isAutodownloadEnabledForAnyPeerType(category: lhs.video) ? lhs.video.sizeLimit : 0)) + Int64((isAutodownloadEnabledForAnyPeerType(category: lhs.file) ? lhs.file.sizeLimit : 0))
        let rhsSizeLimit: Int64 = Int64((isAutodownloadEnabledForAnyPeerType(category: rhs.video) ? rhs.video.sizeLimit : 0)) + Int64((isAutodownloadEnabledForAnyPeerType(category: rhs.file) ? rhs.file.sizeLimit : 0))
        return lhsSizeLimit < rhsSizeLimit
    }
}

public struct MediaAutoDownloadCategory: Codable, Equatable {
    public var contacts: Bool
    public var otherPrivate: Bool
    public var groups: Bool
    public var channels: Bool
    public var sizeLimit: Int64
    public var predownload: Bool
    
    public init(contacts: Bool, otherPrivate: Bool, groups: Bool, channels: Bool, sizeLimit: Int64, predownload: Bool) {
        self.contacts = contacts
        self.otherPrivate = otherPrivate
        self.groups = groups
        self.channels = channels
        self.sizeLimit = sizeLimit
        self.predownload = predownload
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.contacts = try container.decode(Int32.self, forKey: "contacts") != 0
        self.otherPrivate = try container.decode(Int32.self, forKey: "otherPrivate") != 0
        self.groups = try container.decode(Int32.self, forKey: "groups") != 0
        self.channels = try container.decode(Int32.self, forKey: "channels") != 0
        if let sizeLimit = try container.decodeIfPresent(Int64.self, forKey: "size64") {
            self.sizeLimit = sizeLimit
        } else {
            self.sizeLimit = Int64(try container.decode(Int32.self, forKey: "size"))
        }
        self.predownload = try container.decode(Int32.self, forKey: "predownload") != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.contacts ? 1 : 0) as Int32, forKey: "contacts")
        try container.encode((self.otherPrivate ? 1 : 0) as Int32, forKey: "otherPrivate")
        try container.encode((self.groups ? 1 : 0) as Int32, forKey: "groups")
        try container.encode((self.channels ? 1 : 0) as Int32, forKey: "channels")
        try container.encode(self.sizeLimit, forKey: "size64")
        try container.encode((self.predownload ? 1 : 0) as Int32, forKey: "predownload")
    }
}

public struct MediaAutoSaveConfiguration: Codable, Equatable {
    public var photo: Bool
    public var video: Bool
    public var maximumVideoSize: Int64
    
    public static var `default` = MediaAutoSaveConfiguration(
        photo: false,
        video: false,
        maximumVideoSize: 100 * 1024 * 1024
    )
    
    public init(photo: Bool, video: Bool, maximumVideoSize: Int64) {
        self.photo = photo
        self.video = video
        self.maximumVideoSize = maximumVideoSize
    }
}

public struct MediaAutoSaveSettings: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case configurations
        case exceptions
    }
    
    public enum PeerType: String, Codable {
        case users = "users"
        case groups = "groups"
        case channels = "channels"
    }
    
    private struct ConfigurationItem: Codable {
        var peerType: PeerType
        var configuration: MediaAutoSaveConfiguration
    }
    
    public struct ExceptionItem: Codable, Equatable {
        public var id: PeerId
        public var configuration: MediaAutoSaveConfiguration
        
        public init(id: PeerId, configuration: MediaAutoSaveConfiguration) {
            self.id = id
            self.configuration = configuration
        }
    }
    
    public var configurations: [PeerType: MediaAutoSaveConfiguration]
    public var exceptions: [ExceptionItem]
    
    public static let `default` = MediaAutoSaveSettings(configurations: [:], exceptions: [])
    
    public init(configurations: [PeerType: MediaAutoSaveConfiguration], exceptions: [ExceptionItem]) {
        self.configurations = configurations
        self.exceptions = exceptions
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.configurations = [:]
        if let data = try container.decodeIfPresent(Data.self, forKey: .configurations) {
            if let value = try? JSONDecoder().decode([ConfigurationItem].self, from: data) {
                self.configurations = [:]
                for item in value {
                    self.configurations[item.peerType] = item.configuration
                }
            }
        }
        
        self.exceptions = []
        if let data = try container.decodeIfPresent(Data.self, forKey: .exceptions) {
            if let value = try? JSONDecoder().decode([ExceptionItem].self, from: data) {
                self.exceptions = value
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        var configurations: [ConfigurationItem] = []
        for (key, value) in self.configurations {
            configurations.append(ConfigurationItem(peerType: key, configuration: value))
        }
        configurations.sort(by: { $0.peerType.rawValue < $1.peerType.rawValue })
        
        let jsonConfigurations = try JSONEncoder().encode(configurations)
        try container.encode(jsonConfigurations, forKey: .configurations)
        
        let jsonExceptions = try JSONEncoder().encode(self.exceptions)
        try container.encode(jsonExceptions, forKey: .exceptions)
    }
}

public struct EnergyUsageSettings: Codable, Equatable {
    private enum CodingKeys: CodingKey {
        case activationThreshold
        case autoplayVideo
        case autoplayGif
        case loopStickers
        case loopEmoji
        case fullTranslucency
        case extendBackgroundWork
        case autodownloadInBackground
    }
    
    public static let `default`: EnergyUsageSettings = {
        var length: Int = 4
        var cpuCount: UInt32 = 0
        sysctlbyname("hw.ncpu", &cpuCount, &length, nil, 0)
        
        let isCapable = cpuCount >= 4
        
        return EnergyUsageSettings(
            activationThreshold: 15,
            autoplayVideo: true,
            autoplayGif: true,
            loopStickers: true,
            loopEmoji: isCapable,
            fullTranslucency: isCapable,
            extendBackgroundWork: true,
            autodownloadInBackground: true
        )
    }()
    
    public static var powerSavingDefault: EnergyUsageSettings {
        return EnergyUsageSettings(
            activationThreshold: 15,
            autoplayVideo: false,
            autoplayGif: false,
            loopStickers: false,
            loopEmoji: false,
            fullTranslucency: false,
            extendBackgroundWork: false,
            autodownloadInBackground: false
        )
    }
    
    public var activationThreshold: Int32
    
    public var autoplayVideo: Bool
    public var autoplayGif: Bool
    public var loopStickers: Bool
    public var loopEmoji: Bool
    public var fullTranslucency: Bool
    public var extendBackgroundWork: Bool
    public var autodownloadInBackground: Bool
    
    public init(
        activationThreshold: Int32,
        autoplayVideo: Bool,
        autoplayGif: Bool,
        loopStickers: Bool,
        loopEmoji: Bool,
        fullTranslucency: Bool,
        extendBackgroundWork: Bool,
        autodownloadInBackground: Bool
    ) {
        self.activationThreshold = activationThreshold
        self.autoplayVideo = autoplayVideo
        self.autoplayGif = autoplayGif
        self.loopStickers = loopStickers
        self.loopEmoji = loopEmoji
        self.fullTranslucency = fullTranslucency
        self.extendBackgroundWork = extendBackgroundWork
        self.autodownloadInBackground = autodownloadInBackground
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.activationThreshold = try container.decodeIfPresent(Int32.self, forKey: .activationThreshold) ?? EnergyUsageSettings.default.activationThreshold
        self.autoplayVideo = try container.decodeIfPresent(Bool.self, forKey: .autoplayVideo) ?? EnergyUsageSettings.default.autoplayVideo
        self.autoplayGif = try container.decodeIfPresent(Bool.self, forKey: .autoplayGif) ?? EnergyUsageSettings.default.autoplayGif
        self.loopStickers = try container.decodeIfPresent(Bool.self, forKey: .loopStickers) ?? EnergyUsageSettings.default.loopStickers
        self.loopEmoji = try container.decodeIfPresent(Bool.self, forKey: .loopEmoji) ?? EnergyUsageSettings.default.loopEmoji
        self.fullTranslucency = try container.decodeIfPresent(Bool.self, forKey: .fullTranslucency) ?? EnergyUsageSettings.default.fullTranslucency
        self.extendBackgroundWork = try container.decodeIfPresent(Bool.self, forKey: .extendBackgroundWork) ?? EnergyUsageSettings.default.extendBackgroundWork
        self.autodownloadInBackground = try container.decodeIfPresent(Bool.self, forKey: .autodownloadInBackground) ?? EnergyUsageSettings.default.autodownloadInBackground
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.activationThreshold, forKey: .activationThreshold)
        try container.encode(self.autoplayVideo, forKey: .autoplayVideo)
        try container.encode(self.autoplayGif, forKey: .autoplayGif)
        try container.encode(self.loopEmoji, forKey: .loopEmoji)
        try container.encode(self.loopStickers, forKey: .loopStickers)
        try container.encode(self.fullTranslucency, forKey: .fullTranslucency)
        try container.encode(self.extendBackgroundWork, forKey: .extendBackgroundWork)
        try container.encode(self.autodownloadInBackground, forKey: .autodownloadInBackground)
    }
}

public struct MediaAutoDownloadSettings: Codable, Equatable {
    public var presets: MediaAutoDownloadPresets
    public var cellular: MediaAutoDownloadConnection
    public var wifi: MediaAutoDownloadConnection
    
    public var downloadInBackground: Bool
    public var energyUsageSettings: EnergyUsageSettings
    public var highQualityStories: Bool
    
    public static var defaultSettings: MediaAutoDownloadSettings {
        let mb: Int64 = 1024 * 1024
        let presets = MediaAutoDownloadPresets(low:
            MediaAutoDownloadCategories(
                basePreset: .low,
                photo: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false),
                video: MediaAutoDownloadCategory(contacts: false, otherPrivate: false, groups: false, channels: false, sizeLimit: 1 * mb, predownload: false),
                file: MediaAutoDownloadCategory(contacts: false, otherPrivate: false, groups: false, channels: false, sizeLimit: 1 * mb, predownload: false),
                stories: MediaAutoDownloadCategory(contacts: false, otherPrivate: false, groups: false, channels: false, sizeLimit: 20 * mb, predownload: false)
            ),
            medium: MediaAutoDownloadCategories(
                basePreset: .medium,
                photo: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false),
                video: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: Int64(2.5 * CGFloat(mb)), predownload: false),
                file: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false),
                stories: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 20 * mb, predownload: false)
            ),
            high: MediaAutoDownloadCategories(
                basePreset: .high,
                photo: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false),
                video: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 10 * mb, predownload: true),
                file: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 3 * mb, predownload: false),
                stories: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 20 * mb, predownload: false)
            )
        )
        return MediaAutoDownloadSettings(presets: presets, cellular: MediaAutoDownloadConnection(enabled: true, preset: .medium, custom: nil), wifi: MediaAutoDownloadConnection(enabled: true, preset: .high, custom: nil), downloadInBackground: true, energyUsageSettings: EnergyUsageSettings.default, highQualityStories: false)
    }
    
    public init(presets: MediaAutoDownloadPresets, cellular: MediaAutoDownloadConnection, wifi: MediaAutoDownloadConnection, downloadInBackground: Bool, energyUsageSettings: EnergyUsageSettings, highQualityStories: Bool) {
        self.presets = presets
        self.cellular = cellular
        self.wifi = wifi
        self.downloadInBackground = downloadInBackground
        self.energyUsageSettings = energyUsageSettings
        self.highQualityStories = highQualityStories
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        let defaultSettings = MediaAutoDownloadSettings.defaultSettings
        
        self.presets = defaultSettings.presets

        self.cellular = (try? container.decodeIfPresent(MediaAutoDownloadConnection.self, forKey: "cellular")) ?? defaultSettings.cellular
        self.wifi = (try? container.decodeIfPresent(MediaAutoDownloadConnection.self, forKey: "wifi")) ?? defaultSettings.wifi

        self.downloadInBackground = try container.decode(Int32.self, forKey: "downloadInBackground") != 0
        self.energyUsageSettings = (try container.decodeIfPresent(EnergyUsageSettings.self, forKey: "energyUsageSettings")) ?? EnergyUsageSettings.default
        self.highQualityStories = try container.decodeIfPresent(Bool.self, forKey: "highQualityStories") ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.cellular, forKey: "cellular")
        try container.encode(self.wifi, forKey: "wifi")
        try container.encode((self.downloadInBackground ? 1 : 0) as Int32, forKey: "downloadInBackground")
        try container.encode(self.energyUsageSettings, forKey: "energyUsageSettings")
        try container.encode(self.highQualityStories, forKey: "highQualityStories")
    }
    
    public func connectionSettings(for networkType: MediaAutoDownloadNetworkType) -> MediaAutoDownloadConnection {
        switch networkType {
        case .cellular:
            return self.cellular
        case .wifi:
            return self.wifi
        }
    }
    
    public func updatedWithAutodownloadSettings(_ autodownloadSettings: AutodownloadSettings) -> MediaAutoDownloadSettings {
        var settings = self
        settings.presets = presetsWithAutodownloadSettings(autodownloadSettings)
        return settings
    }
}

private func categoriesWithAutodownloadPreset(_ autodownloadPreset: AutodownloadPresetSettings, preset: MediaAutoDownloadPreset) -> MediaAutoDownloadCategories {
    let videoEnabled = autodownloadPreset.videoSizeMax > 0
    let videoSizeMax = autodownloadPreset.videoSizeMax > 0 ? autodownloadPreset.videoSizeMax : 1 * 1024 * 1024
    let fileEnabled = autodownloadPreset.fileSizeMax > 0
    let fileSizeMax = autodownloadPreset.fileSizeMax > 0 ? autodownloadPreset.fileSizeMax : 1 * 1024 * 1024
    
    return MediaAutoDownloadCategories(
        basePreset: preset,
        photo: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: autodownloadPreset.photoSizeMax, predownload: false),
        video: MediaAutoDownloadCategory(contacts: videoEnabled, otherPrivate: videoEnabled, groups: videoEnabled, channels: videoEnabled, sizeLimit: videoSizeMax, predownload: autodownloadPreset.preloadLargeVideo),
        file: MediaAutoDownloadCategory(contacts: fileEnabled, otherPrivate: fileEnabled, groups: fileEnabled, channels: fileEnabled, sizeLimit: fileSizeMax, predownload: false),
        stories: MediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: autodownloadPreset.photoSizeMax, predownload: false)
    )
}

private func presetsWithAutodownloadSettings(_ autodownloadSettings: AutodownloadSettings) -> MediaAutoDownloadPresets {
    return MediaAutoDownloadPresets(low: categoriesWithAutodownloadPreset(autodownloadSettings.lowPreset, preset: .low), medium: categoriesWithAutodownloadPreset(autodownloadSettings.mediumPreset, preset: .medium), high: categoriesWithAutodownloadPreset(autodownloadSettings.highPreset, preset: .high))
}

public func updateMediaDownloadSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (MediaAutoDownloadSettings) -> MediaAutoDownloadSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings, { entry in
            let currentSettings: MediaAutoDownloadSettings
            if let entry = entry?.get(MediaAutoDownloadSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = MediaAutoDownloadSettings.defaultSettings
            }
            let updated = f(currentSettings)
            return PreferencesEntry(updated)
        })
    }
}

public enum MediaAutoDownloadPeerType {
    case contact
    case otherPrivate
    case group
    case channel
}

public struct InstantPageSourceLocation {
    public var userLocation: MediaResourceUserLocation
    public var peerType: MediaAutoDownloadPeerType
    
    public init(userLocation: MediaResourceUserLocation, peerType: MediaAutoDownloadPeerType) {
        self.userLocation = userLocation
        self.peerType = peerType
    }
}

public func effectiveAutodownloadCategories(settings: MediaAutoDownloadSettings, networkType: MediaAutoDownloadNetworkType) -> MediaAutoDownloadCategories {
    let connection = settings.connectionSettings(for: networkType)
    switch connection.preset {
        case .custom:
            return connection.custom ?? settings.presets.medium
        case .low:
            return settings.presets.low
        case .medium:
            return settings.presets.medium
        case .high:
            return settings.presets.high
    }
}

private func categoryAndSizeForMedia(_ media: Media?, isStory: Bool, categories: MediaAutoDownloadCategories) -> (MediaAutoDownloadCategory, Int32?)? {
    if isStory {
        return (categories.stories, 0)
    }
    
    guard let media = media else {
        return (categories.photo, 0)
    }
    
    if media is TelegramMediaImage || media is TelegramMediaWebFile {
        return (categories.photo, 0)
    } else if let file = media as? TelegramMediaFile {
        for attribute in file.attributes {
            switch attribute {
                case .Video:
                    return (categories.video, file.size.flatMap(Int32.init))
                case let .Audio(isVoice, _, _, _, _):
                    if isVoice {
                        return (categories.file, file.size.flatMap(Int32.init))
                    }
                case .Animated:
                    return (categories.video, file.size.flatMap(Int32.init))
                default:
                    break
            }
        }
        return (categories.file, file.size.flatMap(Int32.init))
    } else {
        return nil
    }
}

public func isAutodownloadEnabledForPeerType(_ peerType: MediaAutoDownloadPeerType, category: MediaAutoDownloadCategory) -> Bool {
    switch peerType {
        case .contact:
            return category.contacts
        case .otherPrivate:
            return category.otherPrivate
        case .group:
            return category.groups
        case .channel:
            return category.channels
    }
}

public func isAutodownloadEnabledForAnyPeerType(category: MediaAutoDownloadCategory) -> Bool {
    return category.contacts || category.otherPrivate || category.groups || category.channels
}

public func shouldDownloadMediaAutomatically(settings: MediaAutoDownloadSettings, peerType: MediaAutoDownloadPeerType, networkType: MediaAutoDownloadNetworkType, authorPeerId: PeerId? = nil, contactsPeerIds: Set<PeerId> = Set(), media: Media?, isStory: Bool = false, isAd: Bool = false) -> Bool {
    if isAd {
        return true
    }
    if (networkType == .cellular && !settings.cellular.enabled) || (networkType == .wifi && !settings.wifi.enabled) {
        return false
    }
    if let file = media as? TelegramMediaFile, file.isSticker {
        return true
    }
    
    var peerType = peerType
    if case .group = peerType, let authorPeerId = authorPeerId, contactsPeerIds.contains(authorPeerId) {
        peerType = .contact
    }
    
    if let (category, size) = categoryAndSizeForMedia(media, isStory: isStory, categories: effectiveAutodownloadCategories(settings: settings, networkType: networkType)) {
        if let size = size {
            var sizeLimit = category.sizeLimit
            if let file = media as? TelegramMediaFile, file.isVoice {
                sizeLimit = max(2 * 1024 * 1024, sizeLimit)
            } else if !isAutodownloadEnabledForPeerType(peerType, category: category) {
                return false
            }
            return size <= sizeLimit
        } else if media?.id?.namespace == Namespaces.Media.LocalFile {
            return true
        } else if category.sizeLimit == Int32.max {
            return true
        } else {
            return false
        }
    } else {
        return false
    }
}

public func shouldPredownloadMedia(settings: MediaAutoDownloadSettings, peerType: MediaAutoDownloadPeerType, networkType: MediaAutoDownloadNetworkType, media: Media) -> Bool {
    if #available(iOSApplicationExtension 10.3, *) {
        if (networkType == .cellular && !settings.cellular.enabled) || (networkType == .wifi && !settings.wifi.enabled) {
            return false
        }
        
        if let (category, _) = categoryAndSizeForMedia(media, isStory: false, categories: effectiveAutodownloadCategories(settings: settings, networkType: networkType)) {
            guard isAutodownloadEnabledForPeerType(peerType, category: category) else {
                return false
            }
            return category.sizeLimit > 2 * 1024 * 1024 && category.predownload
        } else {
            return false
        }
    } else {
        return false
    }
}

public func updateMediaAutoSaveSettingsInteractively(account: Account, _ f: @escaping (MediaAutoSaveSettings) -> MediaAutoSaveSettings) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.mediaAutoSaveSettings, { entry in
            let currentSettings: MediaAutoSaveSettings
            if let entry = entry?.get(MediaAutoSaveSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = .default
            }
            let updated = f(currentSettings)
            return PreferencesEntry(updated)
        })
    }
    |> ignoreValues
}
