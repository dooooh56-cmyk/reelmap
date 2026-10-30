import SwiftUI
import WebKit
import CoreLocation
import Observation

struct KakaoMapView: UIViewRepresentable {
    let places: [Place]
    var center: CLLocationCoordinate2D?
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView()
        web.navigationDelegate = context.coordinator
        web.load(URLRequest(url: API.base.appendingPathComponent("native-map")))
        web.accessibilityLabel = "저장한 식당 카카오 지도"
        return web
    }
    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.places = places
        context.coordinator.center = center
        context.coordinator.update(web)
    }
    final class Coordinator: NSObject, WKNavigationDelegate {
        var places: [Place] = []
        var center: CLLocationCoordinate2D?
        var ready = false
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { ready = true; update(webView) }
        func update(_ web: WKWebView) {
            guard ready, let data = try? JSONEncoder().encode(places), let json = String(data: data, encoding: .utf8) else { return }
            web.evaluateJavaScript("window.updatePlaces(\(json))")
            if let center { web.evaluateJavaScript("window.centerOn(\(center.latitude),\(center.longitude))") }
        }
    }
}

@MainActor @Observable final class Location: NSObject, @preconcurrency CLLocationManagerDelegate {
    var current: CLLocation?
    var status = "주변 보기 버튼을 누르면 위치 권한을 요청합니다."
    private let manager = CLLocationManager()
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyHundredMeters }
    func request() {
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        else if [.authorizedAlways, .authorizedWhenInUse].contains(manager.authorizationStatus) { status = "현재 위치 확인 중…"; manager.requestLocation() }
        else { status = "위치 권한이 꺼져 있습니다. iPhone 설정에서 허용할 수 있습니다." }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if [.authorizedAlways, .authorizedWhenInUse].contains(manager.authorizationStatus) { manager.requestLocation() }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { current = locations.last; status = "현재 위치 기준으로 가까운 식당부터 정렬합니다." }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { status = "현재 위치를 가져오지 못했습니다. 저장 목록은 계속 사용할 수 있습니다." }
    func distance(_ p: Place) -> Double { current?.distance(from: CLLocation(latitude: p.lat, longitude: p.lng)) ?? .infinity }
}
