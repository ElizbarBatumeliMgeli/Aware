//
//  TextSceneVM.swift
//  Girella
//
//  Created by Elizbar Kheladze on 23/02/26.
//

import SwiftUI

@Observable
@MainActor
final class TextSceneVM {
    
    var bubbles: [ChatBubble] = []
    var choices: [ActiveChoice] = []
    var isTyping = false
    var isPlayerTyping = false
    var choicesVisible = false
    var showTransitionButton = false
    
    // ─── NEW: Wait State ───
    var isWaiting = false
    var waitMessage: String? = nil
    var waitUnlockDate: Date? = nil
    
    private let scene: TextScene
    private let settings: SettingsManager
    private let onPoints: (Int) -> Void
    private let onTransition: () -> Void
    private weak var coordinator: GameCoordinator?
    
    private(set) var nodeIndex = 0
    @ObservationIgnored
    private var runTask: Task<Void, Never>?
    
    init(scene: TextScene,
         settings: SettingsManager,
         coordinator: GameCoordinator,
         onPoints: @escaping (Int) -> Void,
         onTransition: @escaping () -> Void) {
        self.scene = scene
        self.settings = settings
        self.coordinator = coordinator
        self.onPoints = onPoints
        self.onTransition = onTransition
    }
    
    deinit { runTask?.cancel() }
    
    // MARK: - Public
    
    func triggerTransition() {
        updateSaveState()
        onTransition()
    }
    
    func start() {
        nodeIndex = 0
        bubbles = []
        choices = []
        choicesVisible = false
        isTyping = false
        showTransitionButton = false
        isWaiting = false
        waitUnlockDate = nil
        driveFromCurrent()
    }
    
    func loadState(nodeIndex: Int, bubbles: [ChatBubble], unlockDate: Date? = nil) {
        // Clear any lingering notifications since the user is now in the app!
        NotificationManager.shared.cancelAll()
        
        self.nodeIndex = nodeIndex
        self.bubbles = bubbles
        self.choices = []
        self.choicesVisible = false
        self.isTyping = false
        self.showTransitionButton = false
        
        // Handle loading into an active wait timer
        self.waitUnlockDate = unlockDate
        if let unlock = unlockDate, Date() < unlock {
            self.isWaiting = true
            if nodeIndex < scene.nodes.count {
                self.waitMessage = scene.nodes[nodeIndex].waitMessage?.l(settings.language)
            }
        } else {
            self.isWaiting = false
            self.waitUnlockDate = nil
        }
        
        guard self.nodeIndex < scene.nodes.count else {
            showTransitionButton = true
            return
        }
        
        let currentNode = scene.nodes[self.nodeIndex]
        
        if currentNode.type == "player_choice" && !isWaiting {
            runTask = Task {
                await showChoices(currentNode)
            }
            return
        }
        
        if currentNode.type == "message_block", currentNode.systemEvent == "transition_to_encounter", !isWaiting {
            showTransitionButton = true
            return
        }
        
        driveFromCurrent()
    }
    
    private func updateSaveState() {
        coordinator?.savedTextSceneState = (nodeIndex, bubbles, waitUnlockDate)
    }
    
    func selectChoice(_ choice: ActiveChoice) {
        runTask?.cancel()
        
        withAnimation(G.appear) {
            choicesVisible = false
            choices = []
        }
        
        onPoints(choice.points)
        
        let currentNode = scene.nodes[nodeIndex]
        guard let option = currentNode.options?.first(where: { $0.optionId == choice.tag }) else {
            runTask = Task {
                let typingDelay = settings.pacing.typingDelayNs(charCount: choice.text.count)
                
                withAnimation(G.appear) { isPlayerTyping = true }
                try? await Task.sleep(nanoseconds: typingDelay)

                withAnimation(G.appear) {
                    isPlayerTyping = false
                    bubbles.append(ChatBubble(kind: .player, text: choice.text))
                }                
                try? await Task.sleep(nanoseconds: 300_000_000)
                nodeIndex += 1
                updateSaveState()
                await continueFromCurrent()
            }
            return
        }
        
        runTask = Task { @MainActor in
            let typingDelay = settings.pacing.typingDelayNs(charCount: choice.text.count)
            
            withAnimation(G.appear) { isPlayerTyping = true }
            try? await Task.sleep(nanoseconds: typingDelay)

            withAnimation(G.appear) {
                isPlayerTyping = false
                bubbles.append(ChatBubble(kind: .player, text: choice.text))
            }            
            try? await Task.sleep(nanoseconds: 400_000_000)
            
            nodeIndex += 1
            
            if let branchMsgs = option.branchMessages, !branchMsgs.isEmpty {
                try? await Task.sleep(nanoseconds: settings.pacing.responseDelayNs)
                
                for (i, msg) in branchMsgs.enumerated() {
                    let msgText = msg.l(settings.language)
                    let typingDelay = settings.pacing.typingDelayNs(charCount: msgText.count)
                    
                    withAnimation(G.appear) { isTyping = true }
                    try? await Task.sleep(nanoseconds: typingDelay)
                    withAnimation(G.appear) {
                        isTyping = false
                        bubbles.append(ChatBubble(kind: .npc, text: msgText))
                    }
                    updateSaveState()
                    
                    if i < branchMsgs.count - 1 {
                        try? await Task.sleep(nanoseconds: settings.pacing.interMessageDelayNs)
                    }
                }
            } else {
                updateSaveState()
            }
            
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            guard nodeIndex < scene.nodes.count else {
                showTransitionButton = true
                updateSaveState()
                return
            }
            
            let nextNode = scene.nodes[nodeIndex]
            if nextNode.type == "message_block", nextNode.systemEvent == "transition_to_encounter" {
                let wait = settings.pacing == .fast ? UInt64(100_000_000) : UInt64(800_000_000)
                try? await Task.sleep(nanoseconds: wait)
                showTransitionButton = true
                return
            }
            
            await continueFromCurrent()
        }
    }
    
    private func continueFromCurrent() async {
        while nodeIndex < scene.nodes.count {
            if Task.isCancelled {
                return
            }
            
            let node = scene.nodes[nodeIndex]
            let lang = settings.language
            
            // ─── WAIT TIMER INTERCEPT ───
            if let mins = node.waitTimeMinutes, mins > 0 {
                if waitUnlockDate == nil {
                    // start the timer
                    let seconds = settings.pacing.waitTimeSeconds(baseMinutes: mins)
                    let unlockDate = Date().addingTimeInterval(seconds)
                    waitUnlockDate = unlockDate
                    waitMessage = node.waitMessage?.l(lang) ?? "waiting..."
                    
                    // schedule notification
                    let notifText = node.notificationMessage?.l(lang) ?? "New message from Andreas."
                    NotificationManager.shared.scheduleWaitNotification(for: unlockDate, message: notifText)
                    
                    withAnimation(G.appear) { isWaiting = true }
                    updateSaveState()
                }
                
                while let unlock = waitUnlockDate, Date() < unlock {
                    if Task.isCancelled { return }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
                
                withAnimation(G.appear) { isWaiting = false }
                waitUnlockDate = nil
                waitMessage = nil
                updateSaveState()
            }
            
            switch node.type {
            case "message_block":
                await emitMessageBlock(node)
                updateSaveState()
                
                if node.systemEvent == "transition_to_encounter" {
                    let wait = settings.pacing == .fast ? UInt64(100_000_000) : UInt64(800_000_000)
                    try? await Task.sleep(nanoseconds: wait)
                    showTransitionButton = true
                    updateSaveState()
                    return
                }
                
                try? await Task.sleep(nanoseconds: 200_000_000)
                
                if nodeIndex + 1 < scene.nodes.count,
                   scene.nodes[nodeIndex + 1].type == "player_choice" {
                    nodeIndex += 1
                    updateSaveState()
                    await showChoices(scene.nodes[nodeIndex])
                    return
                }
                nodeIndex += 1
                updateSaveState()
                
            case "player_choice":
                updateSaveState()
                await showChoices(node)
                return
                
            case "system_event":
                if let lbl = node.label {
                    let text = lbl.l(settings.language)
                    try? await Task.sleep(nanoseconds: settings.pacing == .fast ? 200_000_000 : 800_000_000)
                    withAnimation(G.appear) {
                        bubbles.append(ChatBubble(kind: .system, text: text))
                    }
                    updateSaveState()
                    try? await Task.sleep(nanoseconds: settings.pacing == .fast ? 300_000_000 : 1_200_000_000)
                }
                nodeIndex += 1
                updateSaveState()
                
            default:
                nodeIndex += 1
                updateSaveState()
            }
        }
        
        showTransitionButton = true
        updateSaveState()
    }
    
    // MARK: - Processing
    
    private func driveFromCurrent() {
        runTask?.cancel()
        
        runTask = Task {
            await continueFromCurrent()
        }
    }
    
    private func emitMessageBlock(_ node: TextNode) async {
        guard let messages = node.messages else { return }
        let lang = settings.language
        let isPlayer = (node.sender ?? "Andreas") == "Player"
        let kind: BubbleKind = isPlayer ? .player : .npc
        
        if !isPlayer {
            try? await Task.sleep(nanoseconds: settings.pacing.responseDelayNs)
            
            for (i, msg) in messages.enumerated() {
                let msgText = msg.l(lang)
                let typingDelay = settings.pacing.typingDelayNs(charCount: msgText.count)
                
                withAnimation(G.appear) { isTyping = true }
                try? await Task.sleep(nanoseconds: typingDelay)

                withAnimation(G.appear) {
                    isTyping = false
                    bubbles.append(ChatBubble(kind: kind, text: msgText))
                }
                updateSaveState()
                
                if i < messages.count - 1 {
                    try? await Task.sleep(nanoseconds: settings.pacing.interMessageDelayNs)
                }
            }
        } else {
            try? await Task.sleep(nanoseconds: settings.pacing.responseDelayNs / 2) // Small delay before player starts typing
            for (i, msg) in messages.enumerated() {
                let msgText = msg.l(lang)
                let typingDelay = settings.pacing.typingDelayNs(charCount: msgText.count)
                
                withAnimation(G.appear) { isPlayerTyping = true }
                try? await Task.sleep(nanoseconds: typingDelay)

                withAnimation(G.appear) {
                    isPlayerTyping = false
                    bubbles.append(ChatBubble(kind: kind, text: msgText))
                }
                updateSaveState()
                if i < messages.count - 1 {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }
            }
        }
        
        if isPlayer, let delayMs = node.responseDelayMs {
            let scriptedDelay = settings.pacing.scriptedDelayNs(baseMs: delayMs)
            if scriptedDelay > 500_000_000 {
                withAnimation(G.appear) { isTyping = true }
                try? await Task.sleep(nanoseconds: scriptedDelay)
                withAnimation(G.appear) { isTyping = false }
            } else {
                try? await Task.sleep(nanoseconds: scriptedDelay)
            }
        }
    }
    
    private func showChoices(_ node: TextNode) async {
        guard let opts = node.options else { return }
        let lang = settings.language
        
        try? await Task.sleep(nanoseconds: 100_000_000)

        choices = opts.map { ActiveChoice(text: $0.text.l(lang), points: $0.points, tag: $0.optionId) }.shuffled()
        withAnimation(G.soft) { choicesVisible = true }
        }}
