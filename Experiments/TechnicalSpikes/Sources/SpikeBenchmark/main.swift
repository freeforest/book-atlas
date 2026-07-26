import Foundation
import SpikeCore

struct BenchmarkResult: Codable {
    let persistenceInsertCount: Int
    let persistenceSeconds: Double
    let persistenceResidentDeltaBytes: Int64
    let graphResults: [GraphResult]
}

struct GraphResult: Codable {
    let nodeCount: Int
    let generationSeconds: Double
    let residentDeltaBytes: Int64
    let hitNodeID: Int?
}

let beforePersistence = ProcessMemory.residentBytes()
let persistenceStart = ContinuousClock.now
let store = try SQLiteBookStore()
try store.insertBatch(count: 10_000)
let persistenceDuration = persistenceStart.duration(to: .now)
let afterPersistence = ProcessMemory.residentBytes()

let graphResults = [50, 100, 250].map { count in
    let before = ProcessMemory.residentBytes()
    let start = ContinuousClock.now
    let fixture = GraphFixture.fictional(count: count)
    let duration = start.duration(to: .now)
    let after = ProcessMemory.residentBytes()
    return GraphResult(
        nodeCount: count,
        generationSeconds: duration.seconds,
        residentDeltaBytes: Int64(after) - Int64(before),
        hitNodeID: fixture.hitTest(point: fixture.nodes[0].position)
    )
}

let result = BenchmarkResult(
    persistenceInsertCount: try store.bookCount(),
    persistenceSeconds: persistenceDuration.seconds,
    persistenceResidentDeltaBytes:
        Int64(afterPersistence) - Int64(beforePersistence),
    graphResults: graphResults
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let output = try encoder.encode(result)
FileHandle.standardOutput.write(output)
FileHandle.standardOutput.write(Data([0x0A]))

private extension Duration {
    var seconds: Double {
        let components = self.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
