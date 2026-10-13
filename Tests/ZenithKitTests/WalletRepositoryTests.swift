import XCTest

@testable import ZenithKit

final class WalletRepositoryTests: XCTestCase {
  func testNativeCoreRecoveryAndDurableBackupGate() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WalletRepository(directory: directory)
    let created = try await repository.create(password: "local password 123")
    XCTAssertTrue(created.unlocked)
    XCTAssertFalse(created.backupVerified)
    let file = try await repository.exportRecovery(password: "backup password 123")
    let verified = try await repository.verifyBackup(file: file, password: "backup password 123")
    XCTAssertTrue(verified.backupVerified)
    await repository.lock()
    let reopened = try WalletRepository(directory: directory)
    let locked = try await reopened.state()
    XCTAssertFalse(locked.unlocked)
    let unlocked = try await reopened.unlock(password: "local password 123")
    XCTAssertEqual(unlocked.publicKey, created.publicKey)
    XCTAssertTrue(unlocked.backupVerified)
  }
}
