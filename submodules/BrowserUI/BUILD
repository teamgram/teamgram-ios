load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "BrowserUI",
    module_name = "BrowserUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
    	"//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/PresentationDataUtils",
        "//submodules/AppBundle",
        "//submodules/InstantPageUI",
        "//submodules/ContextUI",
        "//submodules/UndoUI",
        "//submodules/TranslateUI",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Components/ViewControllerComponent:ViewControllerComponent",
        "//submodules/Components/MultilineTextComponent:MultilineTextComponent",
        "//submodules/Components/BundleIconComponent:BundleIconComponent",
        "//submodules/Components/BlurredBackgroundComponent:BlurredBackgroundComponent",
        "//submodules/TelegramUI/Components/MinimizedContainer",
        "//submodules/Pasteboard",
        "//submodules/SaveToCameraRoll",
        "//submodules/TelegramUI/Components/NavigationStackComponent",
        "//submodules/LocationUI",
        "//submodules/OpenInExternalAppUI",
        "//submodules/GalleryUI",
        "//submodules/TelegramUI/Components/ContextReferenceButtonComponent",
        "//submodules/Svg",
        "//submodules/PromptUI",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/PhotoResources",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/UrlWhitelist",
        "//submodules/TelegramUI/Components/Chat/ChatHistorySearchContainerNode",
        "//submodules/SearchUI",
        "//submodules/SearchBarNode",
        "//submodules/TelegramUI/Components/SaveProgressScreen",
        "//submodules/TelegramUI/Components/ListActionItemComponent",
        "//submodules/Utils/DeviceModel",
        "//submodules/LegacyMediaPickerUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
