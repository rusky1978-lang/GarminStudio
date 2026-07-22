import SwiftUI

@main
struct Garmin_Screen_Studio_v1_1App: App {

    var body: some Scene {

        WindowGroup {

            ContentView()

        }

        Settings {

            VStack(spacing: 20) {

                Text("Garmin Screen Studio")
                    .font(.title)
                    .bold()

                Text("Settings coming soon…")
                    .foregroundStyle(.secondary)

            }
            .padding(40)
            .frame(width: 350)

        }

    }

}
