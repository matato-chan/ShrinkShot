import SwiftUI

struct KeyRecorderView: View {
    @AppStorage(AppSettings.hotkeyKeyCode) private var keyCode = 0
    @AppStorage(AppSettings.hotkeyModifiers) private var modifiers = 0
    @State private var isRecording = false

    var body: some View {
        HStack {
            Text(String(localized: "hotkey"))

            Spacer()

            Button {
                isRecording.toggle()
            } label: {
                if isRecording {
                    Text(String(localized: "hotkey_recording"))
                        .foregroundColor(.red)
                        .frame(minWidth: 120)
                } else if keyCode != 0 || modifiers != 0 {
                    Text(HotkeyManager.displayString(keyCode: keyCode, modifiers: modifiers))
                        .frame(minWidth: 120)
                } else {
                    Text(String(localized: "hotkey_not_set"))
                        .foregroundColor(.secondary)
                        .frame(minWidth: 120)
                }
            }
            .background(
                KeyRecorderHelper(isRecording: $isRecording, keyCode: $keyCode, modifiers: $modifiers)
            )

            if keyCode != 0 || modifiers != 0 {
                Button(String(localized: "hotkey_clear")) {
                    keyCode = 0
                    modifiers = 0
                }
            }
        }
    }
}

struct KeyRecorderHelper: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onKeyDown = { event in
            guard isRecording else { return }

            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !mods.isEmpty else { return }

            keyCode = Int(event.keyCode)
            modifiers = Int(mods.rawValue)
            isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

class KeyCaptureView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }
}
