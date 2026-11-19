import SwiftUI

/** 역 검색. 홈의 칸을 누르면 열리고, 고르거나 뒤로 가면 닫힌다. */
struct StationSearchView: View {
    @Bindable var vm: HomeViewModel
    @FocusState private var focused: Bool

    private var query: String { vm.query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Button { vm.closeSearch() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)).foregroundStyle(Color.ink)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("뒤로")
                Text(vm.target == .origin ? "타는 역" : "내릴 역").font(.system(size: 20, weight: .bold))
            }
            .padding(.leading, 4).padding(.top, 8)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.brand)
                TextField("역 이름", text: Binding(get: { vm.query }, set: { vm.queryChanged($0) }))
                    .focused($focused)
                    .font(.system(size: 17))
                    .autocorrectionDisabled()
                if !vm.query.isEmpty {
                    Button { vm.queryChanged("") } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color(hex: 0xC9D1E0))
                    }
                    .accessibilityLabel("지우기")
                }
            }
            .padding(.horizontal, 14).frame(height: 52)
            .background(Color.fieldFill, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(focused ? Color.brand : .clear, lineWidth: 2))
            .padding(.horizontal, 20).padding(.vertical, 8)

            if !query.isEmpty {
                Text("검색 결과 \(vm.results.count)").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.muted)
                    .padding(.horizontal, 24).padding(.vertical, 6)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.results, id: \.name) { station in
                        let chosen = station.name == (vm.target == .origin ? vm.origin : vm.destination)?.name
                        Button { vm.pick(station) } label: { StationRow(station: station, query: query, chosen: chosen) }
                    }
                }
                .padding(.horizontal, 12)
            }
            .scrollDismissesKeyboard(.immediately)

            if !vm.lines.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle").foregroundStyle(Color.muted)
                    Text("\(vm.lines.joined(separator: " · ")) 역을 찾을 수 있어요").font(.footnote).foregroundStyle(Color.muted)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ground, in: RoundedRectangle(cornerRadius: 14))
                .padding(20)
            }
        }
        .foregroundStyle(Color.ink)
        .background(.white)
        .preferredColorScheme(.light)
        .onAppear { focused = true }
    }
}

struct StationRow: View {
    let station: Station
    let query: String
    let chosen: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(chosen ? .white : Color.muted)
                .frame(width: 40, height: 40)
                .background(chosen ? Color.brand : Color.fieldFill, in: RoundedRectangle(cornerRadius: 12))
            highlighted.font(.system(size: 18)).foregroundStyle(Color.ink)
                .lineLimit(1).layoutPriority(1)
            Spacer(minLength: 8)
            LineBadges(lines: station.lines)
        }
        .padding(12)
        .background(chosen ? Color.brandTint : .clear, in: RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
    }

    /** 입력한 글자를 파랗게. */
    private var highlighted: Text {
        guard !query.isEmpty, let r = station.name.range(of: query) else { return Text(station.name) }
        return Text(station.name[..<r.lowerBound])
            + Text(station.name[r]).foregroundColor(.brand).fontWeight(.black)
            + Text(station.name[r.upperBound...])
    }
}
