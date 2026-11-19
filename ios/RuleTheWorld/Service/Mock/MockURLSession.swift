import ASKCore
import Foundation

final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    private let mocksDirectory: URL?

    init(directory: URL?) {
        mocksDirectory = directory
    }

    convenience init(bundle: Bundle = .main, subdirectory: String = "Mocks") {
        self.init(directory: bundle.bundleURL.appendingPathComponent(subdirectory, isDirectory: true))
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let fileURL = mockFileURL(for: request),
              let data = try? Data(contentsOf: fileURL) else {
            return (Data(), Self.response(for: request, status: 404))
        }
        return (data, Self.response(for: request, status: 200))
    }

    private func mockFileURL(for request: URLRequest) -> URL? {
        guard let mocksDirectory,
              let path = request.url?.path else { return nil }
        let components = path.split(separator: "/").map(String.init)
        guard !components.isEmpty, !components.contains("..") else { return nil }
        var url = mocksDirectory
        for component in components {
            url.appendPathComponent(component)
        }
        url.appendPathExtension("json")
        return url
    }

    private static func response(for request: URLRequest, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url ?? URL(fileURLWithPath: "/"),
            statusCode: status,
            httpVersion: nil,
            headerFields: status == 200 ? ["Content-Type": "application/json"] : nil
        )!
    }
}
