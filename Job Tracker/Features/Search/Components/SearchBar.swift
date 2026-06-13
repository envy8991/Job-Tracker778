import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var suggestions: [String]
    
    @State private var isFocused = false
    
    var body: some View {
        VStack {
            TextField("Search Jobs", text: $text, onEditingChanged: { editing in
                isFocused = editing
            })
            .padding(7)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray, lineWidth: isFocused ? 2 : 0)
            )
            
            if !suggestions.isEmpty && isFocused {
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(action: {
                                text = suggestion
                                isFocused = false
                            }) {
                                Text(suggestion)
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(8)
                .shadow(radius: 3)
            }
        }
        .padding(.horizontal)
    }
}

