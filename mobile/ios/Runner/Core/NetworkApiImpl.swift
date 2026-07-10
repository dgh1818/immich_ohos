import Foundation
import UniformTypeIdentifiers
import native_video_player

enum ImportError: Error {
  case noFile
  case noViewController
  case keychainError(OSStatus)
  case cancelled
}

class NetworkApiImpl: NetworkApi {
  private var activeImporter: CertImporter?

  private var viewController: UIViewController? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .rootViewController
  }
  
  func selectCertificate(promptText _: ClientCertPrompt, completion: @escaping (Result<ClientCertData, any Error>) -> Void) {
    let importer = CertImporter(completion: { [weak self] result in
      self?.activeImporter = nil
      completion(result)
    }, viewController: viewController)
    activeImporter = importer
    importer.load()
  }

  func setCaBundle(pemData: FlutterStandardTypedData, completion: @escaping (Result<Void, any Error>) -> Void) {
    // On iOS the system trust store is sufficient for server certificate
    // verification.  Custom CA bundles are only needed on OHOS.
    completion(.success(()))
  }

  func hasCertificate() throws -> Bool {
    let query: [String: Any] = [
      kSecClass as String: kSecClassIdentity,
      kSecAttrLabel as String: CLIENT_CERT_LABEL,
      kSecReturnRef as String: true,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    return status == errSecSuccess
  }
  
  func removeCertificate(completion: @escaping (Result<Void, any Error>) -> Void) {
    let status = clearCerts()
    if status == errSecSuccess || status == errSecItemNotFound {
      return completion(.success(()))
    }
    completion(.failure(ImportError.keychainError(status)))
  }
  
  func addCertificate(clientData: ClientCertData, completion: @escaping (Result<Void, any Error>) -> Void) {
    let status = importCert(clientData: clientData.data.data, password: clientData.password)
    if status == errSecSuccess {
      return completion(.success(()))
    }
    completion(.failure(ImportError.keychainError(status)))
  }
  
  func getClientPointer() throws -> Int64 {
    let pointer = URLSessionManager.shared.sessionPointer
    return Int64(Int(bitPattern: pointer))
  }
  
  func getAppGroupId() throws -> String {
    return Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as! String
  }

  func setRequestHeaders(headers: [String : String], serverUrls: [String], token: String?) throws {
    URLSessionManager.setServerUrls(serverUrls)

    if let token = token {
      let expiry = Date().addingTimeInterval(COOKIE_EXPIRY_DAYS * 24 * 60 * 60)
      for serverUrl in serverUrls {
        guard let url = URL(string: serverUrl), let domain = url.host else { continue }
        let isSecure = serverUrl.hasPrefix("https")
        let values: [AuthCookie: String] = [
          .accessToken: token,
          .isAuthenticated: "true",
          .authType: "password",
        ]
        for (cookie, value) in values {
          var properties: [HTTPCookiePropertyKey: Any] = [
            .name: cookie.name,
            .value: value,
            .domain: domain,
            .path: "/",
            .expires: expiry,
          ]
          if isSecure { properties[.secure] = "TRUE" }
          if cookie.httpOnly { properties[.init("HttpOnly")] = "TRUE" }
          if let httpCookie = HTTPCookie(properties: properties) {
            URLSessionManager.cookieStorage.setCookie(httpCookie)
          }
        }
      }
    }

    if headers != UserDefaults.group.dictionary(forKey: HEADERS_KEY) as? [String: String] {
      UserDefaults.group.set(headers, forKey: HEADERS_KEY)
      URLSessionManager.shared.recreateSession()
    }
  }
}

private class CertImporter: NSObject, UIDocumentPickerDelegate {
  private var completion: ((Result<ClientCertData, Error>) -> Void)
  private weak var viewController: UIViewController?

  init(completion: (@escaping (Result<ClientCertData, Error>) -> Void), viewController: UIViewController?) {
    self.completion = completion
    self.viewController = viewController
  }
  
  func load() {
    guard let vc = viewController else { return completion(.failure(ImportError.noViewController)) }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
      UTType(filenameExtension: "p12")!,
      UTType(filenameExtension: "pfx")!,
    ])
    picker.delegate = self
    picker.allowsMultipleSelection = false
    vc.present(picker, animated: true)
  }
  
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let url = urls.first else {
      return completion(.failure(ImportError.noFile))
    }
    
    Task { @MainActor in
      do {
        let data = try readSecurityScoped(url: url)
        self.completion(.success(ClientCertData(data: FlutterStandardTypedData(bytes: data), password: "")))
      } catch {
        completion(.failure(error))
      }
    }
  }
  
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    completion(.failure(ImportError.cancelled))
  }

  private func readSecurityScoped(url: URL) throws -> Data {
    guard url.startAccessingSecurityScopedResource() else {
      throw ImportError.noFile
    }
    defer { url.stopAccessingSecurityScopedResource() }
    return try Data(contentsOf: url)
  }
}

private func importCert(clientData: Data, password: String) -> OSStatus {
  let options = [kSecImportExportPassphrase: password] as CFDictionary
  var items: CFArray?
  let status = SecPKCS12Import(clientData as CFData, options, &items)
  
  guard status == errSecSuccess,
        let array = items as? [[String: Any]],
        let first = array.first,
        let identity = first[kSecImportItemIdentity as String] else {
    return status
  }
  
  clearCerts()
  
  let addQuery: [String: Any] = [
    kSecClass as String: kSecClassIdentity,
    kSecValueRef as String: identity,
    kSecAttrLabel as String: CLIENT_CERT_LABEL,
    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
  ]
  return SecItemAdd(addQuery as CFDictionary, nil)
}

@discardableResult private func clearCerts() -> OSStatus {
  let deleteQuery: [String: Any] = [
    kSecClass as String: kSecClassIdentity,
    kSecAttrLabel as String: CLIENT_CERT_LABEL,
  ]
  return SecItemDelete(deleteQuery as CFDictionary)
}
