load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AttachmentTextInputPanelNode",
    module_name = "AttachmentTextInputPanelNode",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TextFormat:TextFormat",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TouchDownGesture:TouchDownGesture",
        "//submodules/ActivityIndicator:ActivityIndicator",
        "//submodules/Speak:Speak",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/ObjCRuntimeUtils:ObjCRuntimeUtils",
        "//submodules/InvisibleInkDustNode:InvisibleInkDustNode",
        "//submodules/TextInputMenu:TextInputMenu",
        "//submodules/ChatPresentationInterfaceState:ChatPresentationInterfaceState",
        "//submodules/Pasteboard:Pasteboard",
        "//submodules/ContextUI:ContextUI",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView:EmojiTextAttachmentView",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Components/LottieAnimationComponent:LottieAnimationComponent",
        "//submodules/TelegramUI/Components/AnimationCache:AnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer:MultiAnimationRenderer",
        "//submodules/TelegramUI/Components/TextNodeWithEntities:TextNodeWithEntities",
        "//submodules/TelegramUI/Components/Chat/ChatInputTextNode",
        "//submodules/AnimatedCountLabelNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
