import SwiftUI

/// قاب اصلی برنامه: نوار بالای ایندیگو، منوی همبرگری (کشویی از راست) و صفحهٔ فعال؛ مثل MainActivity اندروید
struct RootView: View {
    @StateObject private var model = AppModel()
    @StateObject private var settings = AppSettings()
    @StateObject private var store = Store()

    var body: some View {
        GeometryReader { geo in
            let drawerWidth = min(304, geo.size.width - 56)
            ZStack {
                VStack(spacing: 0) {
                    topBar
                    content
                }
                .background(Color.slate50.ignoresSafeArea())

                if model.drawerOpen {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { closeDrawer() }
                        .transition(.opacity)
                }

                // منو در فضای فیزیکی (چپ‌به‌راست) جای‌گذاری می‌شود تا همیشه از لبهٔ راست باز و بسته شود
                ZStack {
                    DrawerView(width: drawerWidth)
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(width: drawerWidth)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .offset(x: model.drawerOpen ? 0 : drawerWidth + 24)
                }
                .environment(\.layoutDirection, .leftToRight)
                .allowsHitTesting(model.drawerOpen)

                if let toast = model.toastText {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.vazir(14))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color(hex: 0x323232)))
                            .padding(.bottom, 40)
                            .padding(.horizontal, 24)
                    }
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { v in
                        // بازکردن با کشیدن از لبهٔ راست، بستن با کشیدن به سمت راست
                        if !model.drawerOpen, v.startLocation.x > geo.size.width - 36, v.translation.width < -50 {
                            withAnimation(.easeOut(duration: 0.22)) { model.drawerOpen = true }
                        } else if model.drawerOpen, v.translation.width > 60 {
                            closeDrawer()
                        }
                    }
            )
        }
        .environmentObject(model)
        .environmentObject(settings)
        .environmentObject(store)
        .preferredColorScheme(.light)
        .animation(.easeOut(duration: 0.2), value: model.toastText)
    }

    private func closeDrawer() {
        withAnimation(.easeOut(duration: 0.22)) { model.drawerOpen = false }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeOut(duration: 0.22)) { model.drawerOpen = true }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
            }
            .accessibilityLabel("باز کردن منو")

            Text(model.screen.title)
                .font(.vazir(20, bold: true))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 4)
        .frame(height: 56)
        .background(Color.indigo900.ignoresSafeArea(edges: .top))
    }

    @ViewBuilder private var content: some View {
        switch model.screen {
        case .studio: StudioView()
        case .texts: TextsView()
        case .dictionary: DictionaryView()
        case .history: HistoryView()
        case .help: HelpView()
        }
    }
}

/// منوی کشویی: هدر گرادیانی (nav_header) و پنج گزینه (drawer_menu)
struct DrawerView: View {
    @EnvironmentObject var model: AppModel
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 12)
                .padding(.horizontal, 12)

            VStack(spacing: 0) {
                ForEach(Screen.allCases) { screen in
                    Button {
                        model.screen = screen
                        withAnimation(.easeOut(duration: 0.22)) { model.drawerOpen = false }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: screen.icon)
                                .font(.system(size: 20))
                                .frame(width: 28)
                            Text(screen.title)
                                .font(.vazir(15, bold: model.screen == screen))
                            Spacer()
                        }
                        .foregroundColor(model.screen == screen ? .tonalFg : .onSurfaceVariant)
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(Capsule().fill(model.screen == screen ? Color.tonalBg : Color.clear))
                    }
                    .buttonStyle(.plain)
                }

                // گزینهٔ «به‌زودی»: صفحه‌ای باز نمی‌شود؛ فقط منو بسته می‌شود و پیام دوستانه نشان داده می‌شود
                Button {
                    withAnimation(.easeOut(duration: 0.22)) { model.drawerOpen = false }
                    model.toast("به‌زودی! 😉 گفتار به نوشتار 🎙️ به گویا اضافه می‌شه ❤️")
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "waveform")
                            .font(.system(size: 20))
                            .frame(width: 28)
                        Text("گفتار به نوشتار (به‌زودی)")
                            .font(.vazir(15))
                        Spacer()
                    }
                    .foregroundColor(.onSurfaceVariant)
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                }
                .buttonStyle(PressStateStyle(shape: Capsule(), layer: .slate400, pressedOpacity: 0.14))
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Spacer()
        }
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.surfaceLow)
                .padding(.trailing, -20)
                .ignoresSafeArea()
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 0)
        )
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image("Logo")
                .resizable()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("گویا")
                    .font(.vazir(22, bold: true))
                    .foregroundColor(.white)
                Text("نوشتار به گفتار فارسی")
                    .font(.vazir(12))
                    .foregroundColor(.navSubtitle)
            }
            Spacer()
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(playerGradient))
    }
}
