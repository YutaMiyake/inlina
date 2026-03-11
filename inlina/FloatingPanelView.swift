import SwiftUI

struct FloatingPanelView: View {
    let selectedText: String?
    let onResult: (String) -> Void
    let onDismiss: () -> Void

    @State private var customPrompt: String = ""
    @State private var isLoading: Bool = false
    @State private var result: String?
    @State private var errorMessage: String?
    @State private var selectedAction: AIAction?
    @ObservedObject private var settings = SettingsStore.shared

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
                } else if !settings.customPrompts.isEmpty {
                    actionGridSection
                } else {
                    customPromptSection
                }
            }
            .padding(.top, 8)
        }
        .frame(width: 400, height: 160)
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
        HStack {
            if let text = selectedText {
                Image(systemName: "text.quote")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            } else {
                Image(systemName: "text.cursor")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Text("No text selected")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }

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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Action List

    private var actionGridSection: some View {
        VStack(spacing: 0) {
            // Saved prompts list
            if !settings.customPrompts.isEmpty {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(settings.customPrompts) { prompt in
                            Button {
                                performAction(.custom(prompt.prompt))
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14))
                                        .foregroundStyle(brandGradient)
                                        .frame(width: 20)
                                    
                                    Text(prompt.name.isEmpty ? "Untitled" : prompt.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
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
                }
                
                Divider()
                    .opacity(0.3)
            }
            
            // Inline custom prompt input
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(brandGradient)
                    .font(.system(size: 14))
                    .frame(width: 20)

                TextField("Or type a custom instruction...", text: $customPrompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        guard !customPrompt.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        performAction(.custom(customPrompt))
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))
        }
    }

    // MARK: - Custom Prompt

    private var customPromptSection: some View {
        VStack {
            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(brandGradient)
                    .font(.system(size: 14))

                TextField("Ask AI anything...", text: $customPrompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onSubmit {
                        guard !customPrompt.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        performAction(.custom(customPrompt))
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)

            Spacer()
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
                    onDismiss()
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

    private func performAction(_ action: AIAction) {
        guard let text = selectedText, !text.isEmpty else {
            errorMessage = "No text selected"
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
