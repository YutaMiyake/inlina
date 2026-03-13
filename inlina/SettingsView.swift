import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ShortcutsSettingsTab()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            PromptsSettingsTab()
                .tabItem {
                    Label("Prompts", systemImage: "text.bubble")
                }

            AboutSettingsTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

// MARK: - General Tab

private struct GeneralSettingsTab: View {
    @ObservedObject private var settings = SettingsStore.shared

    @State private var connectionTestResult: ConnectionTestResult?
    @State private var isTesting = false

    private enum ConnectionTestResult {
        case success
        case failure(String)
    }

    var body: some View {
        Form {
            Section {
                Picker("AI Provider", selection: $settings.provider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                SecureField("API Key", text: $settings.apiKey)

                TextField("Model", text: $settings.model)
                    .disableAutocorrection(true)

                VStack(alignment: .leading, spacing: 4) {
                    TextField(
                        "Custom API Base URL",
                        text: $settings.baseURL,
                        prompt: Text(settings.provider.defaultBaseURL)
                    )
                    .disableAutocorrection(true)

                    Text("Leave empty to use default. Set custom URL for proxies, Azure OpenAI, local LLMs, etc.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    Button(action: testConnection) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 2)
                        }
                        Text(isTesting ? "Testing..." : "Test Connection")
                    }
                    .disabled(settings.apiKey.isEmpty || isTesting)

                    if let result = connectionTestResult {
                        switch result {
                        case .success:
                            Label("Connection successful", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        case .failure(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func testConnection() {
        isTesting = true
        connectionTestResult = nil

        let baseURL = settings.effectiveBaseURL
        let apiKey = settings.apiKey
        let provider = settings.provider
        let model = settings.model

        Task {
            do {
                let result = try await performConnectionTest(
                    provider: provider,
                    baseURL: baseURL,
                    apiKey: apiKey,
                    model: model
                )
                await MainActor.run {
                    connectionTestResult = result
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    connectionTestResult = .failure(error.localizedDescription)
                    isTesting = false
                }
            }
        }
    }

    private func performConnectionTest(
        provider: AIProvider,
        baseURL: String,
        apiKey: String,
        model: String
    ) async throws -> ConnectionTestResult {
        let url: URL
        let request: URLRequest

        switch provider {
        case .openai:
            guard let endpoint = URL(string: "\(baseURL)/chat/completions") else {
                return .failure("Invalid base URL")
            }
            url = endpoint
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            let body: [String: Any] = [
                "model": model,
                "messages": [["role": "user", "content": "Hi"]],
                "max_tokens": 1
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            request = req

        case .anthropic:
            guard let endpoint = URL(string: "\(baseURL)/messages") else {
                return .failure("Invalid base URL")
            }
            url = endpoint
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            let body: [String: Any] = [
                "model": model,
                "messages": [["role": "user", "content": "Hi"]],
                "max_tokens": 1
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            request = req

        case .gemini:
            let urlString = "\(baseURL)/models/\(model):generateContent?key=\(apiKey)"
            guard let endpoint = URL(string: urlString) else {
                return .failure("Invalid base URL")
            }
            url = endpoint
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "contents": [["parts": [["text": "Hi"]]]]
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            request = req
        }

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if (200...299).contains(httpResponse.statusCode) {
                return .success
            } else {
                return .failure("HTTP \(httpResponse.statusCode)")
            }
        }

        return .failure("Unexpected response")
    }
}

// MARK: - Shortcuts Tab

private struct ShortcutsSettingsTab: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Activate inlina:", name: .activateInlina)
            }

            Section {
                Text("Use this keyboard shortcut to activate inlina from any application. Select text first, then press the shortcut to bring up the action panel.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Prompts Tab

private struct PromptsSettingsTab: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var selectedPromptID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Prompt list
                VStack(spacing: 0) {
                    List(selection: $selectedPromptID) {
                        ForEach(settings.customPrompts) { prompt in
                            Text(prompt.name.isEmpty ? "Untitled" : prompt.name)
                                .tag(prompt.id)
                        }
                    }
                    .listStyle(.bordered)

                    HStack(spacing: 1) {
                        Button(action: addPrompt) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)

                        Button(action: removeSelectedPrompt) {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.borderless)
                        .disabled(selectedPromptID == nil)

                        Spacer()
                    }
                    .padding(6)
                }
                .frame(width: 160)

                Divider()

                // Prompt editor
                if let selectedID = selectedPromptID,
                   let index = settings.customPrompts.firstIndex(where: { $0.id == selectedID }) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Prompt Name", text: $settings.customPrompts[index].name)
                            .textFieldStyle(.roundedBorder)

                        Text("Prompt Instructions")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $settings.customPrompts[index].prompt)
                            .font(.body)
                            .border(Color.secondary.opacity(0.3))
                    }
                    .padding()
                } else {
                    VStack {
                        Spacer()
                        Text("Select a prompt or add a new one")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            Text("Custom prompts appear as additional actions in the inlina panel. The prompt text is sent as the system instruction to the AI.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
        }
    }

    private func addPrompt() {
        let newPrompt = CustomPrompt(name: "", prompt: "")
        settings.customPrompts.append(newPrompt)
        selectedPromptID = newPrompt.id
    }

    private func removeSelectedPrompt() {
        guard let selectedID = selectedPromptID else { return }
        settings.customPrompts.removeAll { $0.id == selectedID }
        selectedPromptID = settings.customPrompts.last?.id
    }
}

// MARK: - About Tab

private struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("inlina")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Version 1.0.0 Beta")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Intelligent AI assistance, right where you type.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Link("Visit Website", destination: URL(string: "https://inlina.app")!)
                .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
