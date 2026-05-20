import SwiftUI

struct SecureFieldTestView: View {
    @State private var passphrase = ""
    @FocusState private var isPassphraseFieldFocused: Bool

    var body: some View {
        VStack {
            Text("Test SecureField")
                .font(.title)
                .padding()

            SecureField("Enter Passphrase", text: $passphrase)
                .textFieldStyle(.roundedBorder)
                .focused($isPassphraseFieldFocused)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isPassphraseFieldFocused = true
                    }
                }

            Text("Debug: \(passphrase)")
                .foregroundColor(.gray)
                .padding()
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}

struct SecureFieldTestView_Previews: PreviewProvider {
    static var previews: some View {
        SecureFieldTestView()
    }
}