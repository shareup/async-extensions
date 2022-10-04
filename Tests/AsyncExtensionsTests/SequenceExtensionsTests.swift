@testable import AsyncExtensions
import AsyncTestExtensions
import XCTest

final class MapFunctionsTests: XCTestCase {
    
    private let square: (Int) async throws -> Int = {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return $0 * $0
    }
    
    func testAsyncMapOnArray() async throws {
        var initialTime = Date()
        let _ = try await square(1)
        let _ = try await square(2)
        let _ = try await square(3)
        var finalTime = Date().timeIntervalSince(initialTime)
        await AssertTrueEventually(finalTime >= 3)
    
        initialTime = Date()
        async let asyncMapArray = [1, 2, 3].asyncMap(square)
        let _ = try await asyncMapArray
        finalTime = Date().timeIntervalSince(initialTime)
        await AssertTrueEventually(finalTime >= 3)
    }
    
    func testConcurrentMapOnArray() async throws {
        var initialTime = Date()
        async let one = square(1)
        async let four = square(2)
        async let nine = square(3)
        let _ = try await [one, four, nine]
        var finalTime = Date().timeIntervalSince(initialTime)
        await AssertTrueEventually(finalTime < 1.1)
        
        initialTime = Date()
        async let asyncMapArray = [1, 2, 3].concurrentMap(square)
        let _ = try await asyncMapArray
        finalTime = Date().timeIntervalSince(initialTime)
        await AssertTrueEventually(finalTime <= 1.1)
    }
 }
