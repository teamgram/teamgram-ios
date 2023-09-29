import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import BundleIconComponent
import SolidRoundedButtonComponent
import Markdown
import BalancedTextComponent
import ConfettiEffect
import AvatarNode
import TextFormat
import TelegramStringFormatting
import UndoUI

private final class PremiumGiftCodeSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let giftCode: PremiumGiftCodeInfo
    let action: () -> Void
    let cancel: () -> Void
    let openPeer: (EnginePeer) -> Void
    
    init(
        context: AccountContext,
        giftCode: PremiumGiftCodeInfo,
        action: @escaping () -> Void,
        cancel: @escaping  () -> Void,
        openPeer: @escaping (EnginePeer) -> Void
    ) {
        self.context = context
        self.giftCode = giftCode
        self.action = action
        self.cancel = cancel
        self.openPeer = openPeer
    }
    
    static func ==(lhs: PremiumGiftCodeSheetContent, rhs: PremiumGiftCodeSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.giftCode != rhs.giftCode {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private var disposable: Disposable?
        var initialized = false
        
        var peerMap: [EnginePeer.Id: EnginePeer] = [:]
        
        var cachedCloseImage: (UIImage, PresentationTheme)?
        
        init(context: AccountContext, giftCode: PremiumGiftCodeInfo) {
            self.context = context
            
            super.init()
            
            var peerIds: [EnginePeer.Id] = []
            peerIds.append(giftCode.fromPeerId)
            if let toPeerId = giftCode.toPeerId {
                peerIds.append(toPeerId)
            }
            
            self.disposable = (context.engine.data.get(
                EngineDataMap(
                    peerIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                        return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                    }
                )
            ) |> deliverOnMainQueue).startStrict(next: { [weak self] peers in
                if let strongSelf = self {
                    var peersMap: [EnginePeer.Id: EnginePeer] = [:]
                    for peerId in peerIds {
                        if let maybePeer = peers[peerId], let peer = maybePeer {
                            peersMap[peerId] = peer
                        }
                    }
                    strongSelf.peerMap = peersMap
                    strongSelf.initialized = true
                
                    strongSelf.updated(transition: .immediate)
                }
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, giftCode: self.giftCode)
    }
    
    static var body: Body {
        let closeButton = Child(Button.self)
        let title = Child(MultilineTextComponent.self)
        let star = Child(PremiumStarComponent.self)
        let description = Child(BalancedTextComponent.self)
        let linkButton = Child(Button.self)
        let table = Child(TableComponent.self)
        let additional = Child(BalancedTextComponent.self)
        let button = Child(SolidRoundedButtonComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            let dateTimeFormat = environment.dateTimeFormat
            
            let state = context.state
            let giftCode = component.giftCode
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 32.0 + environment.safeInsets.left
            
            let closeImage: UIImage
            if let (image, theme) = state.cachedCloseImage, theme === environment.theme {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0x808084, alpha: 0.1), foregroundColor: theme.actionSheet.inputClearButtonColor)!
                state.cachedCloseImage = (closeImage, theme)
            }
            
            let closeButton = closeButton.update(
                component: Button(
                    content: AnyComponent(Image(image: closeImage)),
                    action: { [weak component] in
                        component?.cancel()
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: .immediate
            )
            
            let titleText: String
            let descriptionText: String
            let additionalText: String
            let buttonText: String
            if let usedDate = giftCode.usedDate {
                let dateString = stringForMediumDate(timestamp: usedDate, strings: strings, dateTimeFormat: dateTimeFormat)
                titleText = "Used Gift Link"
                descriptionText = "This link was used to activate a **Telegram Premium** subscription."
                additionalText = "This link was used on \(dateString)."
                buttonText = strings.Common_OK
            } else {
                titleText = "Gift Link"
                descriptionText = "This link allows you to activate a **Telegram Premium** subscription."
                additionalText = "You can also [send this link]() to a friend as a gift."
                buttonText = "Use Link"
            }
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: titleText,
                        font: Font.semibold(17.0),
                        textColor: theme.actionSheet.primaryTextColor,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let star = star.update(
                component: PremiumStarComponent(isIntro: false, isVisible: true, hasIdleAnimations: true),
                availableSize: CGSize(width: context.availableSize.width, height: 200.0),
                transition: .immediate
            )
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = theme.actionSheet.primaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            let description = description.update(
                component: BalancedTextComponent(
                    text: .markdown(text: descriptionText, attributes: markdownAttributes),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            
            let link = "https://t.me/giftcode/\(giftCode.slug)"
            let linkButton = linkButton.update(
                component: Button(
                    content: AnyComponent(
                        LinkButtonContentComponent(theme: environment.theme, text: link)
                    ),
                    action: {
                        UIPasteboard.general.string = link
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: .immediate
            )
            
            let tableFont = Font.regular(15.0)
            let tableTextColor = theme.list.itemPrimaryTextColor
            let tableLinkColor = theme.list.itemAccentColor
            var tableItems: [TableComponent.Item] = []
            
            let fromPeer = state.peerMap[giftCode.fromPeerId]
            tableItems.append(.init(
                id: "from",
                title: "From",
                component: AnyComponent(
                    Button(
                        content: AnyComponent(PeerCellComponent(context: context.component.context, textColor: tableLinkColor, peer: fromPeer)),
                        action: {
                            if let peer = fromPeer {
                                component.openPeer(peer)
                            }
                        }
                    )
                )
            ))
            if let toPeerId = giftCode.toPeerId {
                let toPeer = state.peerMap[toPeerId]
                tableItems.append(.init(
                    id: "to",
                    title: "To",
                    component: AnyComponent(
                        Button(
                            content: AnyComponent(PeerCellComponent(context: context.component.context, textColor: tableLinkColor, peer: toPeer)),
                            action: {
                                if let peer = toPeer {
                                    component.openPeer(peer)
                                }
                            }
                        )
                    )
                ))
            }
            let giftTitle: String
            if giftCode.months == 12 {
                giftTitle = "Telegram Premium for 1 year"
            } else {
                giftTitle = "Telegram Premium for \(giftCode.months) months"
            }
            tableItems.append(.init(
                id: "gift",
                title: "Gift",
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: giftTitle, font: tableFont, textColor: tableTextColor)))
                )
            ))
            
            let giftReason = giftCode.isGiveaway ? "Giveaway" : "Gift"
            tableItems.append(.init(
                id: "reason",
                title: "Reason",
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: giftReason, font: tableFont, textColor: tableLinkColor)))
                )
            ))
            tableItems.append(.init(
                id: "date",
                title: "Date",
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: giftCode.date, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                )
            ))
            
            let table = table.update(
                component: TableComponent(
                    theme: environment.theme,
                    items: tableItems
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let additional = additional.update(
                component: BalancedTextComponent(
                    text: .markdown(text: additionalText, attributes: markdownAttributes),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
          
            let button = button.update(
                component: SolidRoundedButtonComponent(
                    title: buttonText,
                    theme: SolidRoundedButtonComponent.Theme(theme: theme),
                    font: .bold,
                    fontSize: 17.0,
                    height: 50.0,
                    cornerRadius: 10.0,
                    gloss: !giftCode.isUsed,
                    iconName: nil,
                    animationName: nil,
                    iconPosition: .left,
                    action: {
                        if giftCode.isUsed {
                            component.cancel()
                        } else {
                            component.action()
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: context.transition
            )
            
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: 28.0))
            )
            
            context.add(star
                .position(CGPoint(x: context.availableSize.width / 2.0, y: star.size.height / 2.0))
            )
            
            var originY: CGFloat = 0.0
            originY += star.size.height - 32.0
            
            context.add(description
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + description.size.height / 2.0))
            )
            originY += description.size.height + 21.0
            
            context.add(linkButton
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + linkButton.size.height / 2.0))
            )
            originY += linkButton.size.height + 16.0
            
            context.add(table
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + table.size.height / 2.0))
            )
            originY += table.size.height + 23.0
            
            context.add(additional
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + additional.size.height / 2.0))
            )
            originY += additional.size.height + 23.0
            
            let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: originY), size: button.size)
            context.add(button
                .position(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
            )
            
            context.add(closeButton
                .position(CGPoint(x: context.availableSize.width - environment.safeInsets.left - closeButton.size.width, y: 28.0))
            )
            
            let contentSize = CGSize(width: context.availableSize.width, height: buttonFrame.maxY + 5.0 + environment.safeInsets.bottom)
        
            return contentSize
        }
    }
}

private final class PremiumGiftCodeSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let giftCode: PremiumGiftCodeInfo
    let action: () -> Void
    let cancel: () -> Void
    let openPeer: (EnginePeer) -> Void

    init(
        context: AccountContext,
        giftCode: PremiumGiftCodeInfo,
        action: @escaping () -> Void,
        cancel: @escaping () -> Void,
        openPeer: @escaping (EnginePeer) -> Void
    ) {
        self.context = context
        self.giftCode = giftCode
        self.action = action
        self.cancel = cancel
        self.openPeer = openPeer
    }
    
    static func ==(lhs: PremiumGiftCodeSheetComponent, rhs: PremiumGiftCodeSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.giftCode != rhs.giftCode {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(PremiumGiftCodeSheetContent(
                        context: context.component.context,
                        giftCode: context.component.giftCode,
                        action: context.component.action,
                        cancel: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        },
                        openPeer: context.component.openPeer
                    )),
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                animateOut.invoke(Action { _ in
                                    if let controller = controller() {
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else {
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

public class PremiumGiftCodeScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    public var disposed: () -> Void = {}
    
    private let hapticFeedback = HapticFeedback()
    
    public init(
        context: AccountContext,
        giftCode: PremiumGiftCodeInfo,
        forceDark: Bool = false,
        cancel: @escaping () -> Void = {},
        action: @escaping () -> Void,
        openPeer: @escaping (EnginePeer) -> Void = { _ in }
    ) {
        self.context = context
        
        super.init(context: context, component: PremiumGiftCodeSheetComponent(context: context, giftCode: giftCode, action: action, cancel: cancel, openPeer: openPeer), navigationBarAppearance: .none, statusBarStyle: .ignore, theme: forceDark ? .dark : .default)
        
        self.navigationPresentation = .flatModal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposed()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
}

private final class LinkButtonContentComponent: CombinedComponent {
    let theme: PresentationTheme
    let text: String
    
    public init(
        theme: PresentationTheme,
        text: String
    ) {
        self.theme = theme
        self.text = text
    }
    
    static func ==(lhs: LinkButtonContentComponent, rhs: LinkButtonContentComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        return true
    }
    
    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let text = Child(MultilineTextComponent.self)
        let icon = Child(BundleIconComponent.self)
        
        return { context in
            let component = context.component
            
            let sideInset: CGFloat = 38.0
            
            let background = background.update(
                component: RoundedRectangle(color: component.theme.list.itemInputField.backgroundColor, cornerRadius: 10.0),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            let text = text.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.text.replacingOccurrences(of: "https://", with: ""),
                        font: Font.regular(17.0),
                        textColor: component.theme.list.itemPrimaryTextColor,
                        paragraphAlignment: .natural
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset - sideInset, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let icon = icon.update(
                component: BundleIconComponent(name: "Chat/Context Menu/Copy", tintColor: component.theme.list.itemAccentColor),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            context.add(text
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            context.add(icon
                .position(CGPoint(x: context.availableSize.width - icon.size.width / 2.0 - 14.0, y: context.availableSize.height / 2.0))
            )
            return context.availableSize
        }
    }
}

private final class TableComponent: CombinedComponent {
    class Item: Equatable {
        public let id: AnyHashable
        public let title: String
        public let component: AnyComponent<Empty>

        public init<IdType: Hashable>(id: IdType, title: String, component: AnyComponent<Empty>) {
            self.id = AnyHashable(id)
            self.title = title
            self.component = component
        }

        public static func == (lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.component != rhs.component {
                return false
            }
            return true
        }
    }
    
    private let theme: PresentationTheme
    private let items: [Item]

    public init(theme: PresentationTheme, items: [Item]) {
        self.theme = theme
        self.items = items
    }

    public static func ==(lhs: TableComponent, rhs: TableComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedBorderImage: (UIImage, PresentationTheme)?
    }
    
    func makeState() -> State {
        return State()
    }

    public static var body: Body {
        let leftColumnBackground = Child(Rectangle.self)
        let verticalBorder = Child(Rectangle.self)
        let titleChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let valueChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let borderChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let outerBorder = Child(Image.self)

        return { context in
            let verticalPadding: CGFloat = 11.0
            let horizontalPadding: CGFloat = 12.0
            let borderWidth: CGFloat = 1.0
            
            let backgroundColor = context.component.theme.actionSheet.opaqueItemBackgroundColor
            let borderColor = backgroundColor.mixedWith(context.component.theme.list.itemBlocksSeparatorColor, alpha: 0.6)
            
            var leftColumnWidth: CGFloat = 0.0
            
            var updatedTitleChildren: [_UpdatedChildComponent] = []
            var updatedValueChildren: [_UpdatedChildComponent] = []
            var updatedBorderChildren: [_UpdatedChildComponent] = []
            
            for item in context.component.items {
                let titleChild = titleChildren[item.id].update(
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: item.title, font: Font.regular(15.0), textColor: context.component.theme.list.itemPrimaryTextColor))
                    )),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                updatedTitleChildren.append(titleChild)
                
                if titleChild.size.width > leftColumnWidth {
                    leftColumnWidth = titleChild.size.width
                }
            }
            
            leftColumnWidth = max(100.0, leftColumnWidth + horizontalPadding * 2.0)
            let rightColumnWidth = context.availableSize.width - leftColumnWidth
            
            var i = 0
            var rowHeights: [Int: CGFloat] = [:]
            var totalHeight: CGFloat = 0.0
            
            for item in context.component.items {
                let titleChild = updatedTitleChildren[i]
                let valueChild = valueChildren[item.id].update(
                    component: item.component,
                    availableSize: CGSize(width: rightColumnWidth - horizontalPadding * 2.0, height: context.availableSize.height),
                    transition: context.transition
                )
                updatedValueChildren.append(valueChild)
                
                let rowHeight = max(40.0, max(titleChild.size.height, valueChild.size.height) + verticalPadding * 2.0)
                rowHeights[i] = rowHeight
                totalHeight += rowHeight
                
                if i < context.component.items.count - 1 {
                    let borderChild = borderChildren[item.id].update(
                        component: AnyComponent(Rectangle(color: borderColor)),
                        availableSize: CGSize(width: context.availableSize.width, height: borderWidth),
                        transition: context.transition
                    )
                    updatedBorderChildren.append(borderChild)
                }
                
                i += 1
            }
            
            let leftColumnBackground = leftColumnBackground.update(
                component: Rectangle(color: context.component.theme.list.itemInputField.backgroundColor),
                availableSize: CGSize(width: leftColumnWidth, height: totalHeight),
                transition: context.transition
            )
            context.add(
                leftColumnBackground
                    .position(CGPoint(x: leftColumnWidth / 2.0, y: totalHeight / 2.0))
            )
            
            let borderImage: UIImage
            if let (currentImage, theme) = context.state.cachedBorderImage, theme === context.component.theme {
                borderImage = currentImage
            } else {
                let borderRadius: CGFloat = 5.0
                borderImage = generateImage(CGSize(width: 16.0, height: 16.0), rotatedContext: { size, context in
                    let bounds = CGRect(origin: .zero, size: size)
                    context.setFillColor(backgroundColor.cgColor)
                    context.fill(bounds)
                    
                    let path = CGPath(roundedRect: bounds.insetBy(dx: borderWidth / 2.0, dy: borderWidth / 2.0), cornerWidth: borderRadius, cornerHeight: borderRadius, transform: nil)
                    context.setBlendMode(.clear)
                    context.addPath(path)
                    context.fillPath()
                    
                    context.setBlendMode(.normal)
                    context.setStrokeColor(borderColor.cgColor)
                    context.setLineWidth(borderWidth)
                    context.addPath(path)
                    context.strokePath()
                })!.stretchableImage(withLeftCapWidth: 5, topCapHeight: 5)
                context.state.cachedBorderImage = (borderImage, context.component.theme)
            }
            
            let outerBorder = outerBorder.update(
                component: Image(image: borderImage),
                availableSize: CGSize(width: context.availableSize.width, height: totalHeight),
                transition: context.transition
            )
            context.add(outerBorder
                .position(CGPoint(x: context.availableSize.width / 2.0, y: totalHeight / 2.0))
            )
            
            let verticalBorder = verticalBorder.update(
                component: Rectangle(color: borderColor),
                availableSize: CGSize(width: borderWidth, height: totalHeight),
                transition: context.transition
            )
            context.add(
                verticalBorder
                    .position(CGPoint(x: leftColumnWidth - borderWidth / 2.0, y: totalHeight / 2.0))
            )
            
            i = 0
            var originY: CGFloat = 0.0
            for (titleChild, valueChild) in zip(updatedTitleChildren, updatedValueChildren) {
                let rowHeight = rowHeights[i] ?? 0.0
                
                let titleFrame = CGRect(origin: CGPoint(x: horizontalPadding, y: originY + verticalPadding), size: titleChild.size)
                let valueFrame = CGRect(origin: CGPoint(x: leftColumnWidth + horizontalPadding, y: originY + verticalPadding), size: valueChild.size)
                
                context.add(titleChild
                    .position(titleFrame.center)
                )
                
                context.add(valueChild
                    .position(valueFrame.center)
                )
                
                if i < updatedBorderChildren.count {
                    let borderChild = updatedBorderChildren[i]
                    context.add(borderChild
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + rowHeight - borderWidth / 2.0))
                    )
                }
                
                originY += rowHeight
                i += 1
            }
            
            return CGSize(width: context.availableSize.width, height: totalHeight)
        }
    }
}

private final class PeerCellComponent: Component {
    let context: AccountContext
    let textColor: UIColor
    let peer: EnginePeer?

    init(context: AccountContext, textColor: UIColor, peer: EnginePeer?) {
        self.context = context
        self.textColor = textColor
        self.peer = peer
    }

    static func ==(lhs: PeerCellComponent, rhs: PeerCellComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.textColor !== rhs.textColor {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        return true
    }

    final class View: UIView {
        private let avatarNode: AvatarNode
        private let text = ComponentView<Empty>()
                
        private var component: PeerCellComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 14.0))
            
            super.init(frame: frame)
            
            self.addSubnode(self.avatarNode)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: PeerCellComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
                                    
            self.avatarNode.setPeer(
                context: component.context,
                theme: component.context.sharedContext.currentPresentationData.with({ $0 }).theme,
                peer: component.peer,
                synchronousLoad: true
            )
            
            let avatarSize = CGSize(width: 22.0, height: 22.0)
            let spacing: CGFloat = 6.0
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.peer?.compactDisplayTitle ?? "", font: Font.regular(15.0), textColor: component.textColor, paragraphAlignment: .left))
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - avatarSize.width - spacing, height: availableSize.height)
            )
            
            let size = CGSize(width: avatarSize.width + textSize.width + spacing, height: textSize.height)
            
            let avatarFrame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((size.height - avatarSize.height) / 2.0)), size: avatarSize)
            self.avatarNode.frame = avatarFrame
            
            if let view = self.text.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                let textFrame = CGRect(origin: CGPoint(x: avatarSize.width + spacing, y: floorToScreenPixels((size.height - textSize.height) / 2.0)), size: textSize)
                transition.setFrame(view: view, frame: textFrame)
            }
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}