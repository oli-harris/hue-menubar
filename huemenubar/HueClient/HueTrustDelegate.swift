import Foundation
import Security

final class HueTrustDelegate: NSObject, URLSessionDelegate {

    private let roots: [SecCertificate]
    private let bridgeId: String

    init?(bridgeId: String) {
        self.bridgeId = bridgeId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // These must exist in your app bundle as DER .cer files
        let names = ["HueRootActive", "HueRootSecondary"]

        var certs: [SecCertificate] = []
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "cer"),
                  let data = try? Data(contentsOf: url),
                  let cert = SecCertificateCreateWithData(nil, data as CFData) else {
                return nil
            }
            certs.append(cert)
        }
        self.roots = certs
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        // Only handle server-trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // 1) Trust ONLY the Hue Bridge root CAs you bundled
        SecTrustSetAnchorCertificates(trust, roots as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust, true)

        // 2) Use Basic X.509 policy (avoids strict SSL/WebPKI “standards compliant” rules)
        SecTrustSetPolicies(trust, SecPolicyCreateBasicX509())

        // 3) Evaluate chain
        var error: CFError?
        guard SecTrustEvaluateWithError(trust, &error) else {
            // Uncomment for debugging:
            // print("❌ Hue trust chain failed:", error as Any)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // 4) Manual identity check: leaf certificate CN must match bridgeId
        guard let leaf = SecTrustGetCertificateAtIndex(trust, 0),
              let cn = Self.commonName(of: leaf),
              cn.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == bridgeId else {
            // Uncomment for debugging:
            // let got = SecTrustGetCertificateAtIndex(trust, 0).flatMap(Self.commonName) ?? "nil"
            // print("❌ Hue CN mismatch. Got:", got, "Expected:", bridgeId)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // 5) All good
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    private static func commonName(of cert: SecCertificate) -> String? {
        var commonName: CFString?
        guard SecCertificateCopyCommonName(cert, &commonName) == errSecSuccess else { return nil }
        return commonName as String?
    }
}
