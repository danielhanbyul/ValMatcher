//
//  test.swift
//  ValMatcher
//
//  Created by Daniel Han on 12/24/24.
//

import SwiftUI

struct MatchNotificationPreview: View {
    @State private var showNotification = true
    @State private var notificationMessage = "You matched with Alex!"

    var body: some View {
        ZStack {
            // Dim background to mimic a modal overlay
            Color.black.opacity(showNotification ? 0.5 : 0)
                .edgesIgnoringSafeArea(.all)
                .animation(.easeInOut(duration: 0.3), value: showNotification)

            if showNotification {
                GeometryReader { geometry in
                    // Center the modal within the available space
                    VStack {
                        Spacer()

                        VStack(spacing: 16) {
                            // Top Row: Icon + Text
                            HStack(spacing: 12) {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 40))
                                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("It's a Match!")
                                        .font(.headline)
                                        .bold()
                                        .foregroundColor(.white)
                                    Text(notificationMessage)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.3))
                            
                            // Dismiss Button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showNotification = false
                                }
                            }) {
                                Text("Dismiss")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 50)
                                    .background(Color.green.opacity(0.8)) // Slightly transparent green
                                    .cornerRadius(10)
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                        }
                        .padding(20)
                        .background(
                            // Transparent gradient for the card
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.02, green: 0.18, blue: 0.15).opacity(0.7),
                                    Color(red: 0.21, green: 0.29, blue: 0.40).opacity(0.7)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 30)

                        Spacer()
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .transition(.scale) // Smooth pop-in/out
                    .animation(.easeInOut(duration: 0.3), value: showNotification)
                }
            }
        }
    }
}

struct MatchNotificationPreview_Previews: PreviewProvider {
    static var previews: some View {
        MatchNotificationPreview()
    }
}
