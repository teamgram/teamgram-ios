load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ReactionButtonListComponent",
    module_name = "ReactionButtonListComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/WebPBinding:WebPBinding",
        "//submodules/AnimatedAvatarSetNode:AnimatedAvatarSetNode",
        "//submodules/Components/ReactionImageComponent:ReactionImageComponent",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView:EmojiTextAttachmentView",
        "//submodules/TelegramUI/Components/AnimationCache:AnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer:MultiAnimationRenderer",
        "//submodules/TextFormat:TextFormat",
        "//submodules/AppBundle",
        "//submodules/TelegramUI/Components/AnimatedTextComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
