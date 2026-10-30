import SwiftUI
import UniformTypeIdentifiers

struct AnalyzeView: View {
    let library: Library
    var initialURL = ""
    var initialText = ""
    var resolving: String?
    var onDone: (() -> Void)?
    var autoStart = false
    @State private var url = ""
    @State private var text = ""
    @State private var media: MediaInput?
    @State private var analyzeMedia = false
    @State private var fileName = ""
    @State private var showImporter = false
    @State private var busy = false
    @State private var didInitialize = false
    @State private var status = ""
    @State private var result: Analysis?
    @State private var selection: [String: String] = [:]
    @AppStorage("demoCode") private var code = ""
    var body: some View {
        Form {
            Section("인스타그램 게시물") {
                TextField("게시물 또는 릴스 링크", text: $url).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("본문 또는 식당 정보 추가", text: $text, axis: .vertical).lineLimit(3...8)
                Button { showImporter = true } label: { Label(fileName.isEmpty ? "영상·캡처 첨부 (최대 12MB)" : fileName, systemImage: "paperclip") }
                if media != nil {
                    Toggle("첨부 파일까지 분석", isOn: $analyzeMedia)
                    Text("본문으로 확인되는 경우에도 파일을 분석하며 토큰이 더 사용될 수 있습니다.").font(.caption).foregroundStyle(.secondary)
                    Button("첨부 제거", role: .destructive) { media = nil; fileName = ""; analyzeMedia = false }
                }
            }
            Section {
                Button { Task { await analyze() } } label: {
                    HStack { Text("식당 분석하기"); Spacer(); if busy { ProgressView() } }
                }.disabled(busy || (url.isEmpty && text.isEmpty && media == nil))
            } footer: { Text("자료는 Gemini에 전송해 분석합니다. 서버에 보관하지 않습니다. 불확실한 지점은 자동 저장하지 않습니다.") }
            if !status.isEmpty { Section("진행 상태") { Text(status).font(.callout).accessibilityAddTraits(.updatesFrequently) } }
            if let result, result.status != "auto_save" {
                ForEach(result.groups) { group in
                    Section(group.entity.name) {
                        Text(group.entity.evidence).font(.footnote).foregroundStyle(.secondary)
                        Text(group.verified ? "이름·주소 일치" : "주소·지점 확인 필요").font(.caption).foregroundStyle(group.verified ? .green : .orange)
                        if group.places.isEmpty { Text("일치하는 장소가 없습니다. ‘확인 필요’에서 직접 검색해 주세요.") }
                        ForEach(group.places) { place in
                            Button {
                                if selection[group.id] == place.id { selection.removeValue(forKey: group.id) }
                                else { selection[group.id] = place.id }
                            } label: {
                                HStack(alignment: .top) {
                                    Image(systemName: selection[group.id] == place.id ? "checkmark.circle.fill" : "circle")
                                    VStack(alignment: .leading) { Text(place.name); Text(place.address).font(.caption).foregroundStyle(.secondary) }
                                }
                            }.accessibilityLabel("\(place.name), \(place.address)").accessibilityValue(selection[group.id] == place.id ? "선택됨" : "선택 안 됨")
                        }
                    }
                }
                if result.groups.contains(where: { !$0.places.isEmpty }) {
                    Section { Button("선택한 식당 저장") { saveSelected(result) }.disabled(selection.isEmpty || busy) }
                }
            }
            Section("연결 설정") { SecureField("체험 코드 (운영자가 설정한 경우)", text: $code) }
        }
        .navigationTitle("릴스 속 식당 찾기")
        .toolbar { if let onDone { ToolbarItem(placement: .confirmationAction) { Button("닫기", action: onDone) } } }
        .onAppear { guard !didInitialize else { return }; didInitialize = true; url = initialURL; text = initialText; if autoStart { Task { await analyze() } } }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.movie, .image]) { response in
            do { let file = try response.get(); let granted = file.startAccessingSecurityScopedResource(); defer { if granted { file.stopAccessingSecurityScopedResource() } }
                let values = try file.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
                guard (values.fileSize ?? Int.max) <= 12 * 1024 * 1024 else { throw UserError(message: "12MB 이하 파일을 첨부해 주세요.") }
                let mime = values.contentType?.preferredMIMEType ?? ""
                guard ["video/mp4", "video/quicktime", "video/webm", "image/jpeg", "image/png", "image/webp"].contains(mime) else { throw UserError(message: "MP4/MOV/WebM/JPG/PNG/WebP 형식으로 첨부해 주세요.") }
                media = MediaInput(mime: mime, data: try Data(contentsOf: file).base64EncodedString()); fileName = file.lastPathComponent
            } catch { status = error.localizedDescription }
        }
    }
    @MainActor private func analyze() async {
        guard !busy else { return }
        let submittedURL = url
        var submittedText = text
        let submittedMedia = media
        let includeMedia = analyzeMedia
        busy = true; defer { busy = false }; result = nil; selection = [:]; status = "본문·영상에서 식당을 찾고 위치를 확인하고 있습니다…"
        do {
            if submittedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && submittedMedia == nil && !submittedURL.isEmpty {
                status = "기기에서 공개 게시물 본문을 읽고 있습니다…"
                if let caption = try? await InstagramCaption.read(submittedURL) { submittedText = caption }
                status = "식당을 분석하고 주소를 확인하고 있습니다…"
            }
            let response: Analysis = try await API.post("api/analyze", input: AnalysisInput(url: submittedURL, text: submittedText, media: submittedMedia, analyzeMedia: includeMedia), code: code)
            result = response
            if response.status == "auto_save", let group = response.groups.first, let place = group.places.first(where: { $0.id == group.matchedID }) {
                try library.save([place], source: response.source, resolving: resolving, resolveSource: true)
                status = "\(place.name)을 지도에 저장했습니다."
                if !autoStart { onDone?() }
            } else if response.status == "choose" { status = "주소를 확인하고 저장할 식당을 선택해 주세요." }
            else { status = "추가 자료가 필요합니다." }
            status += "\n" + response.warnings.joined(separator: "\n")
            if let usage = response.usage { status += "\nAI 사용량 · 입력 \(usage.inputTokens) / 답변 \(usage.outputTokens) / 추론 \(usage.thinkingTokens) / 총 \(usage.totalTokens)토큰" }
            if response.status == "needs_input" || response.groups.contains(where: { $0.places.isEmpty }) {
                try library.addPending(url: submittedURL, text: submittedText, reason: response.warnings.joined(separator: " "))
            }
        } catch {
            status = error.localizedDescription
            if ![400,401,413].contains((error as? APIError)?.status ?? 0) {
                do { try library.addPending(url: submittedURL, text: submittedText, reason: status) } catch { status += "\n확인 필요 목록에도 기록하지 못했습니다: \(error.localizedDescription)" }
            }
        }
    }
    private func saveSelected(_ response: Analysis) {
        let selected = response.groups.compactMap { g in g.places.first { $0.id == selection[g.id] } }
        do { try library.save(selected, source: response.source, resolving: response.groups.allSatisfy { !$0.places.isEmpty } ? resolving : nil, resolveSource: response.groups.allSatisfy { !$0.places.isEmpty }); status = "\(selected.count)곳을 저장했습니다."; if !autoStart { onDone?() } } catch { status = error.localizedDescription }
    }
}
