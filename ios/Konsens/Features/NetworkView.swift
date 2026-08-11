import SwiftUI

struct NetworkView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View { TransparencyNativeView().environmentObject(store) }
}
