import SwiftUI

struct FloatingPanelView: View {
    let selectedText: String?
    let onResult: (String) -> Void
    let onDismiss: () -> Void

    @State private var customPrompt: String = ""
    @State private var sourceText: String
    @State private var isLoading: Bool = false
    @State private var result: String?
    @State private var errorMessage: String?
    @State private var selectedAction: AIAction?
    @FocusState private var isInputFocused: Bool
    @FocusState private var isSourceFocused: Bool
    @ObservedObject private var settings = SettingsStore.shared
    @Environment(\.openSettings) private var openSettings

    init(selectedText: String?, onResult: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        self.selectedText = selectedText
        self.onResult = onResult
        self.onDismiss = onDismiss
        _sourceText = State(initialValue: selectedText ?? "")
    }

    private let brandGradient = LinearGradient(
        colors: [Color(hex: 0x667EEA), Color(hex: 0x764BA2)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with selected text
                headerSection

                Divider()
                    .opacity(0.3)

                if let result = result {
                    resultSection(result)
                } else if isLoading {
                    loadingSection
                } else {
                    actionGridSection
                }
            }
            .padding(.top, 8)
        }
        .frame(width: 520, height: 380)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .onExitCommand { onDismiss() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    openSettingsWindow()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open Settings")

                Image(systemName: "text.quote")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            // Editable source text (pre-filled with the captured selection)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $sourceText)
                    .font(.system(size: 12))
                    .focused($isSourceFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)

                if sourceText.isEmpty {
                    Text("Type or paste the text to process...")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    // MARK: - Search

    private var searchQuery: String {
        var query = customPrompt
        if query.hasPrefix("/") {
            query = String(query.dropFirst())
        }
        return query.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private var filteredPrompts: [CustomPrompt] {
        let query = searchQuery
        if query.isEmpty { return settings.customPrompts }
        return settings.customPrompts.filter {
            $0.name.lowercased().contains(query)
        }
    }

    // MARK: - Action List

    private var actionGridSection: some View {
        VStack(spacing: 0) {
            // Search field at top
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(brandGradient)
                    .font(.system(size: 14))
                    .frame(width: 20)

                TextField("Search prompts...", text: $customPrompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isInputFocused)
                    .onSubmit {
                        handleSubmit()
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))

            Divider()
                .opacity(0.3)

            // Prompts grid
            if !filteredPrompts.isEmpty {
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                        spacing: 8
                    ) {
                        ForEach(filteredPrompts) { prompt in
                            Button {
                                performAction(.custom(prompt.prompt))
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 16))
                                        .foregroundStyle(brandGradient)

                                    Text(prompt.name.isEmpty ? "Untitled" : prompt.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.primary.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
            } else if settings.customPrompts.isEmpty {
                VStack(spacing: 12) {
                    Spacer()

                    Text("No custom prompts yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Button {
                        openSettingsWindow()
                    } label: {
                        Label("Add prompts in Settings", systemImage: "gearshape")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 6) {
                    Spacer()
                    Text("No matching prompts")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSourceFocused = true
            }
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: 12) {
            Spacer()

            ProgressView()
                .controlSize(.regular)
                .scaleEffect(1.2)

            Text("Processing...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            if let action = selectedAction {
                Text(action.displayName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Result

    private func resultSection(_ text: String) -> some View {
        VStack(spacing: 0) {
            // Result label
            HStack {
                if let action = selectedAction {
                    Label(action.displayName, systemImage: action.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(brandGradient)
                }
                Spacer()

                Button {
                    resetState()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Back to actions")
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Scrollable result text
            ScrollView {
                Text(text)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }

            Divider().opacity(0.3)

            // Action buttons
            HStack(spacing: 10) {
                if let error = errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    onResult(text)
                } label: {
                    Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: 0x667EEA))
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    // MARK: - Actions

    private func handleSubmit() {
        if let match = filteredPrompts.first {
            performAction(.custom(match.prompt))
        }
    }

    private func openSettingsWindow() {
        onDismiss()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }

    private func performAction(_ action: AIAction) {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "No text to process"
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            selectedAction = action
            isLoading = true
            errorMessage = nil
            result = nil
        }

        Task {
            do {
                let output = try await AIService.shared.process(text: text, action: action)
                withAnimation(.easeInOut(duration: 0.25)) {
                    result = output
                    isLoading = false
                }
            } catch {
                withAnimation(.easeInOut(duration: 0.25)) {
                    errorMessage = error.localizedDescription
                    result = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func resetState() {
        withAnimation(.easeInOut(duration: 0.25)) {
            result = nil
            errorMessage = nil
            selectedAction = nil
            isLoading = false
        }
    }
}

// MARK: - Action Button

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
