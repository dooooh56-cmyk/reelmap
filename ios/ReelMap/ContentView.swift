import SwiftUI
import CoreLocation

struct ContentView: View {
    let library: Library
    @State private var location = Location()
    @State private var query = ""
    @State private var showAdd = false
    @State private var retryPost: PendingPost?
    @State private var linkPost: PendingPost?
    @State private var selected: Place?
    @State private var error = ""
    @Environment(\.scenePhase) private var scenePhase
    var places: [Place] {
        library.data.places.filter { query.isEmpty || ($0.name + $0.address).localizedCaseInsensitiveContains(query) }
            .sorted { location.current != nil ? location.distance($0) < location.distance($1) : ($0.savedAt ?? "") > ($1.savedAt ?? "") }
    }
    var body: some View {
        TabView {
            NavigationStack {
                VStack(spacing: 0) {
                    KakaoMapView(places: places, center: selected.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) } ?? location.current?.coordinate)
                        .frame(minHeight: 160, maxHeight: 280)
                    List {
                        Section {
                            Button { selected = nil; location.request() } label: { Label("내 주변에서 찾기", systemImage: "location") }
                            Text(location.status).font(.caption).foregroundStyle(.secondary)
                        }
                        if places.isEmpty { ContentUnavailableView("저장한 맛집을 모아보세요", systemImage: "mappin.and.ellipse", description: Text("상단 + 버튼이나 인스타 공유 메뉴에서 릴스를 추가하세요.")) }
                        ForEach(places) { p in
                            VStack(alignment: .leading, spacing: 8) {
                                Button { selected = p } label: { Label(p.name, systemImage: "mappin.circle.fill").font(.headline) }
                                Text(p.address).font(.subheadline).foregroundStyle(.secondary)
                                if location.current != nil { Text(String(format: "%.1f km", location.distance(p) / 1000)).font(.caption).monospacedDigit() }
                                HStack {
                                    if let url = URL(string: p.url), url.scheme == "https" { Link("카카오맵", destination: url) }
                                    if let source = p.source, let url = URL(string: source), url.scheme == "https" { Link("원본 릴스", destination: url) }
                                }.font(.caption)
                            }.padding(.vertical, 4)
                            .swipeActions { Button("삭제", role: .destructive) { do { try library.delete(p) } catch { self.error = error.localizedDescription } } }
                        }
                        Section { NavigationLink("식당 직접 검색") { SearchView(library: library) } }
                    }.listStyle(.insetGrouped)
                }
                .navigationTitle("내 맛집 지도")
                .searchable(text: $query, prompt: "식당명 또는 지역")
                .toolbar { ToolbarItem(placement: .primaryAction) { Button { showAdd = true } label: { Label("릴스 추가", systemImage: "plus") } } }
            }.tabItem { Label("내 지도", systemImage: "map") }
            NavigationStack {
                List {
                    if library.data.pending.isEmpty { ContentUnavailableView("확인할 게시물이 없습니다", systemImage: "checkmark.circle") }
                    ForEach(library.data.pending) { p in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("추가 확인이 필요한 게시물").font(.headline)
                            Text(p.reason).font(.caption).foregroundStyle(.secondary)
                            if let url = URL(string: p.url), url.scheme == "https" { Link("인스타그램에서 열기", destination: url) }
                            Button("자료 추가·재분석") { retryPost = p }
                            Button("식당 직접 연결") { linkPost = p }
                        }.swipeActions { Button("삭제", role: .destructive) { do { try library.removePending(p.id) } catch { self.error = error.localizedDescription } } }
                    }
                }.navigationTitle("확인 필요")
            }.tabItem { Label("확인 필요", systemImage: "tray") }.badge(library.data.pending.count)
            NavigationStack {
                Form {
                    Section("연결") {
                        LabeledContent("AI 분석", value: "Gemini")
                        LabeledContent("장소·지도", value: "카카오")
                        Text("API 비밀 키는 서버에만 보관합니다.").font(.footnote)
                    }
                    Section("공유 저장 공간") {
                        Text(library.sharedAvailable ? "App Group 연결됨" : "App Group 미연결: 현재 앱 안에서만 저장됩니다. 공유 확장과 연결하려면 두 타깃의 서명이 필요합니다.")
                    }
                    Section("데이터") {
                        Text("로그인 없이 이 기기에 저장합니다. 앱 삭제 시 데이터도 지워질 수 있습니다.")
                        ShareLink(item: backupText) { Label("저장 목록 JSON 백업", systemImage: "square.and.arrow.up") }
                    }
                    if !library.message.isEmpty { Section("저장 상태") { Text(library.message) } }
                }.navigationTitle("설정")
            }.tabItem { Label("설정", systemImage: "gearshape") }
        }
        .sheet(isPresented: $showAdd) { NavigationStack { AnalyzeView(library: library, onDone: { showAdd = false; selected = library.lastSaved }) }.presentationDetents([.medium, .large]) }
        .sheet(item: $retryPost) { p in NavigationStack { AnalyzeView(library: library, initialURL: p.url, initialText: p.text, resolving: p.id, onDone: { retryPost = nil; selected = library.lastSaved }) }.presentationDetents([.medium, .large]) }
        .sheet(item: $linkPost) { p in NavigationStack { SearchView(library: library, source: p.url, resolving: p.id) }.presentationDetents([.medium, .large]) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { library.reload() } }
        .alert("저장 오류", isPresented: Binding(get: { !error.isEmpty }, set: { if !$0 { error = "" } })) { Button("확인") { error = "" } } message: { Text(error) }
    }
    private var backupText: String { (try? String(data: JSONEncoder().encode(library.data), encoding: .utf8)) ?? "{}" }
}

struct SearchView: View {
    let library: Library
    var source = ""
    var resolving: String?
    @State private var query = ""
    @State private var places: [Place] = []
    @State private var status = "지역과 식당명을 함께 입력해 주세요."
    @State private var busy = false
    @AppStorage("demoCode") private var code = ""
    var body: some View {
        Form {
            Section("식당 검색") {
                TextField("예: 마포 산와쇼텐", text: $query).submitLabel(.search).onSubmit { Task { await search() } }
                Button("카카오에서 검색") { Task { await search() } }.disabled(busy || query.count < 2)
                Text(status).font(.caption)
            }
            ForEach(places) { p in
                Section(p.name) { Text(p.address); Button("이 식당 저장") {
                    do { try library.save([p], source: source, resolving: resolving); status = "\(p.name)을 저장했습니다." } catch { status = error.localizedDescription }
                } }
            }
        }.navigationTitle("식당 직접 연결")
    }
    @MainActor private func search() async {
        busy = true; defer { busy = false }; status = "검색 중…"
        do { let r: SearchResult = try await API.post("api/search", input: ["query": query], code: code); places = r.places; status = places.isEmpty ? "검색 결과가 없습니다." : "주소와 지점을 확인해 주세요." }
        catch { status = error.localizedDescription }
    }
}
