import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import ContextUI
import PhotoResources
import TelegramUIPreferences
import ItemListPeerItem
import ItemListPeerActionItem
import MergeLists
import ItemListUI
import ChatControllerInteraction
import MultilineTextComponent
import BalancedTextComponent
import Markdown
import PeerInfoPaneNode
import GiftItemComponent
import PlainButtonComponent
import GiftViewScreen
import SolidRoundedButtonNode

public final class PeerInfoGiftsPaneNode: ASDisplayNode, PeerInfoPaneNode, UIScrollViewDelegate {
    private let context: AccountContext
    private let peerId: PeerId
    private let profileGifts: ProfileGiftsContext
    
    private var dataDisposable: Disposable?
    
    private let chatControllerInteraction: ChatControllerInteraction
    private let openPeerContextAction: (Bool, Peer, ASDisplayNode, ContextGesture?) -> Void
    
    public weak var parentController: ViewController?
    
    private let backgroundNode: ASDisplayNode
    private let scrollNode: ASScrollNode
    
    private var unlockBackground: UIImageView?
    private var unlockText: ComponentView<Empty>?
    private var unlockButton: SolidRoundedButtonNode?
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, isScrollingLockedAtTop: Bool, presentationData: PresentationData)?
    
    private var theme: PresentationTheme?
    private let presentationDataPromise = Promise<PresentationData>()
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    public var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }

    private let statusPromise = Promise<PeerInfoStatusData?>(nil)
    public var status: Signal<PeerInfoStatusData?, NoError> {
        self.statusPromise.get()
    }
    
    public var tabBarOffsetUpdated: ((ContainedViewLayoutTransition) -> Void)?
    public var tabBarOffset: CGFloat {
        return 0.0
    }
            
    private var starsProducts: [ProfileGiftsContext.State.StarGift]?
    
    private var starsItems: [AnyHashable: ComponentView<Empty>] = [:]
    
    public init(context: AccountContext, peerId: PeerId, chatControllerInteraction: ChatControllerInteraction, openPeerContextAction: @escaping (Bool, Peer, ASDisplayNode, ContextGesture?) -> Void, profileGifts: ProfileGiftsContext) {
        self.context = context
        self.peerId = peerId
        self.chatControllerInteraction = chatControllerInteraction
        self.openPeerContextAction = openPeerContextAction
        self.profileGifts = profileGifts
        
        self.backgroundNode = ASDisplayNode()
        self.scrollNode = ASScrollNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.scrollNode)
                        
        self.dataDisposable = (profileGifts.state
        |> deliverOnMainQueue).startStrict(next: { [weak self] state in
            guard let self else {
                return
            }
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            self.statusPromise.set(.single(PeerInfoStatusData(text: presentationData.strings.SharedMedia_GiftCount(state.count ?? 0), isActivity: true, key: .gifts)))
            self.starsProducts = state.gifts
            
            if !self.didSetReady {
                self.didSetReady = true
                self.ready.set(.single(true))
            }
            
            self.updateScrolling()
        })
    }
    
    deinit {
        self.dataDisposable?.dispose()
    }
    
    public override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.delegate = self
    }
    
    public func ensureMessageIsVisible(id: MessageId) {
    }
    
    public func scrollToTop() -> Bool {
        self.scrollNode.view.setContentOffset(.zero, animated: true)
        return true
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateScrolling()
    }
    
    func updateScrolling() {
        if let starsProducts = self.starsProducts, let params = self.currentParams {
            let optionSpacing: CGFloat = 10.0
            let sideInset = params.sideInset + 16.0
            
            let itemsInRow = min(starsProducts.count, 3)
            let optionWidth = (params.size.width - sideInset * 2.0 - optionSpacing * CGFloat(itemsInRow - 1)) / CGFloat(itemsInRow)
            
            let starsOptionSize = CGSize(width: optionWidth, height: 154.0)
            
            let visibleBounds = self.scrollNode.bounds.insetBy(dx: 0.0, dy: -10.0)
            
            var validIds: [AnyHashable] = []
            var itemFrame = CGRect(origin: CGPoint(x: sideInset, y: 60.0), size: starsOptionSize)
            for product in starsProducts {
                let itemId = AnyHashable(product.date)
                validIds.append(itemId)
                
                let itemTransition = ComponentTransition.immediate
                let visibleItem: ComponentView<Empty>
                if let current = self.starsItems[itemId] {
                    visibleItem = current
                } else {
                    visibleItem = ComponentView()
                    self.starsItems[itemId] = visibleItem
                }
                
                var isVisible = false
                if visibleBounds.intersects(itemFrame) {
                    isVisible = true
                }
                
                if isVisible {
                    let ribbonText: String?
                    if let availability = product.gift.availability {
                        //TODO:localize
                        ribbonText = "1 of \(compactNumericCountString(Int(availability.total)))"
                    } else {
                        ribbonText = nil
                    }
                    let _ = visibleItem.update(
                        transition: itemTransition,
                        component: AnyComponent(
                            PlainButtonComponent(
                                content: AnyComponent(
                                    GiftItemComponent(
                                        context: self.context,
                                        theme: params.presentationData.theme,
                                        peer: product.fromPeer.flatMap { .peer($0) } ?? .anonymous,
                                        subject: .starGift(product.gift.id, product.gift.file),
                                        price: "⭐️ \(product.gift.price)",
                                        ribbon: ribbonText.flatMap { GiftItemComponent.Ribbon(text: $0, color: .blue) },
                                        isHidden: !product.savedToProfile
                                    )
                                ),
                                effectAlignment: .center,
                                action: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    let controller = GiftViewScreen(
                                        context: self.context,
                                        subject: .profileGift(self.peerId, product),
                                        updateSavedToProfile: { [weak self] added in
                                            guard let self, let messageId = product.messageId else {
                                                return
                                            }
                                            self.profileGifts.updateStarGiftAddedToProfile(messageId: messageId, added: added)
                                        },
                                        convertToStars: { [weak self] in
                                            guard let self, let messageId = product.messageId else {
                                                return
                                            }
                                            self.profileGifts.convertStarGift(messageId: messageId)
                                        }
                                    )
                                    self.parentController?.push(controller)
                                    
                                },
                                animateAlpha: false
                            )
                        ),
                        environment: {},
                        containerSize: starsOptionSize
                    )
                    if let itemView = visibleItem.view {
                        if itemView.superview == nil {
                            self.scrollNode.view.addSubview(itemView)
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }
                }
                itemFrame.origin.x += itemFrame.width + optionSpacing
                if itemFrame.maxX > params.size.width {
                    itemFrame.origin.x = sideInset
                    itemFrame.origin.y += starsOptionSize.height + optionSpacing
                }
            }
            
            var contentHeight = ceil(CGFloat(starsProducts.count) / 3.0) * starsOptionSize.height + 60.0 + 16.0
            
            if self.peerId == self.context.account.peerId {
                let transition = ComponentTransition.immediate
                
                let size = params.size
                let sideInset = params.sideInset
                let bottomInset = params.bottomInset
                let presentationData = params.presentationData
              
                let themeUpdated = self.theme !== presentationData.theme
                self.theme = presentationData.theme
                
                let unlockText: ComponentView<Empty>
                let unlockBackground: UIImageView
                let unlockButton: SolidRoundedButtonNode
                if let current = self.unlockText {
                    unlockText = current
                } else {
                    unlockText = ComponentView<Empty>()
                    self.unlockText = unlockText
                }
                
                if let current = self.unlockBackground {
                    unlockBackground = current
                } else {
                    unlockBackground = UIImageView()
                    unlockBackground.contentMode = .scaleToFill
                    self.view.addSubview(unlockBackground)
                    self.unlockBackground = unlockBackground
                }
                                        
                if let current = self.unlockButton {
                    unlockButton = current
                } else {
                    unlockButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: presentationData.theme), height: 50.0, cornerRadius: 10.0)
                    self.view.addSubview(unlockButton.view)
                    self.unlockButton = unlockButton
                
                    //TODO:localize
                    unlockButton.title = "Send Gifts to Friends"
                    
                    unlockButton.pressed = { [weak self] in
                        self?.buttonPressed()
                    }
                }
            
                if themeUpdated {
                    let topColor = presentationData.theme.list.plainBackgroundColor.withAlphaComponent(0.0)
                    let bottomColor = presentationData.theme.list.plainBackgroundColor
                    unlockBackground.image = generateGradientImage(size: CGSize(width: 1.0, height: 170.0), colors: [topColor, bottomColor, bottomColor], locations: [0.0, 0.3, 1.0])
                    unlockButton.updateTheme(SolidRoundedButtonTheme(theme: presentationData.theme))
                }
                
                let textFont = Font.regular(13.0)
                let boldTextFont = Font.semibold(13.0)
                let textColor = presentationData.theme.list.itemSecondaryTextColor
                let linkColor = presentationData.theme.list.itemAccentColor
                let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: boldTextFont, textColor: linkColor), linkAttribute: { _ in
                    return nil
                })
                
                let scrollOffset: CGFloat = min(0.0, self.scrollNode.view.contentOffset.y + bottomInset + 80.0)
                 
                transition.setFrame(view: unlockBackground, frame: CGRect(x: 0.0, y: size.height - bottomInset - 170.0 + scrollOffset, width: size.width, height: bottomInset + 170.0))
                
                let buttonSideInset = sideInset + 16.0
                let buttonSize = CGSize(width: size.width - buttonSideInset * 2.0, height: 50.0)
                transition.setFrame(view: unlockButton.view, frame: CGRect(origin: CGPoint(x: buttonSideInset, y: size.height - bottomInset - buttonSize.height - 26.0), size: buttonSize))
                let _ = unlockButton.updateLayout(width: buttonSize.width, transition: .immediate)
                
                let unlockSize = unlockText.update(
                    transition: .immediate,
                    component: AnyComponent(
                        BalancedTextComponent(
                            text: .markdown(text: "These gifts were sent to you by other users. Tap on a gift to exchange it for Stars or change its privacy settings.", attributes: markdownAttributes),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.2
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: size.width - 32.0, height: 200.0)
                )
                if let view = unlockText.view {
                    if view.superview == nil {
                        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.buttonPressed)))
                        self.scrollNode.view.addSubview(view)
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: floor((size.width - unlockSize.width) / 2.0), y: contentHeight), size: unlockSize))
                }
                contentHeight += unlockSize.height
            }
            contentHeight += params.bottomInset
            
            let contentSize = CGSize(width: params.size.width, height: contentHeight)
            if self.scrollNode.view.contentSize != contentSize {
                self.scrollNode.view.contentSize = contentSize
            }
        }
        
        let bottomOffset = max(0.0, self.scrollNode.view.contentSize.height - self.scrollNode.view.contentOffset.y - self.scrollNode.view.frame.height)
        if bottomOffset < 100.0 {
            self.profileGifts.loadMore()
        }
    }
        
    @objc private func buttonPressed() {
        let _ = (self.context.account.stateManager.contactBirthdays
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] birthdays in
            guard let self else {
                return
            }
            let controller = self.context.sharedContext.makePremiumGiftController(context: self.context, source: .settings(birthdays), completion: nil)
            controller.navigationPresentation = .modal
            self.chatControllerInteraction.navigationController()?.pushViewController(controller)
        })
    }
    
    public func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, navigationHeight: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, sideInset, bottomInset, isScrollingLockedAtTop, presentationData)
        self.presentationDataPromise.set(.single(presentationData))
        
        self.backgroundNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 48.0), size: size))
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))

        if isScrollingLockedAtTop {
            self.scrollNode.view.contentOffset = .zero
        }
        self.scrollNode.view.isScrollEnabled = !isScrollingLockedAtTop
        
        self.updateScrolling()
    }
    
    public func findLoadedMessage(id: MessageId) -> Message? {
        return nil
    }
    
    public func updateHiddenMedia() {
    }
    
    public func transferVelocity(_ velocity: CGFloat) {
        if velocity > 0.0 {
//            self.scrollNode.transferVelocity(velocity)
        }
    }
    
    public func cancelPreviewGestures() {
    }
    
    public func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    public func addToTransitionSurface(view: UIView) {
    }
    
    public func updateSelectedMessages(animated: Bool) {
    }
}

private struct StarsGiftProduct: Equatable {
    let emoji: String
    let price: Int64
    let isLimited: Bool
}