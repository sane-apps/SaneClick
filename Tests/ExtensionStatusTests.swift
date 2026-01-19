import Foundation
import Testing
@testable import SaneScript

struct ExtensionStatusTests {

    // MARK: - ExtensionStatus Enum Tests

    @Test("ExtensionStatus.active is usable")
    func activeStatusIsUsable() {
        let status = ExtensionStatus.active
        #expect(status.isUsable == true)
        #expect(status.statusText == "Extension Active")
        #expect(status.icon == "checkmark.circle.fill")
        #expect(status.color == "green")
    }

    @Test("ExtensionStatus.enabledNotRunning is usable")
    func enabledNotRunningStatusIsUsable() {
        let status = ExtensionStatus.enabledNotRunning
        #expect(status.isUsable == true)
        #expect(status.statusText == "Extension Enabled (Restart Finder)")
        #expect(status.icon == "clock.fill")
        #expect(status.color == "orange")
    }

    @Test("ExtensionStatus.disabled is not usable")
    func disabledStatusIsNotUsable() {
        let status = ExtensionStatus.disabled
        #expect(status.isUsable == false)
        #expect(status.statusText == "Extension Disabled")
        #expect(status.icon == "exclamationmark.triangle.fill")
        #expect(status.color == "red")
    }

    @Test("ExtensionStatus equality works")
    func statusEquality() {
        #expect(ExtensionStatus.active == ExtensionStatus.active)
        #expect(ExtensionStatus.active != ExtensionStatus.disabled)
    }

    // MARK: - ScriptExecutionResult Tests

    @Test("ScriptExecutionResult success factory works")
    func successResultFactory() {
        let result = ScriptExecutionResult.success(scriptName: "Test", output: "Hello")

        #expect(result.scriptName == "Test")
        #expect(result.success == true)
        #expect(result.output == "Hello")
        #expect(result.error == nil)
    }

    @Test("ScriptExecutionResult failure factory works")
    func failureResultFactory() {
        let result = ScriptExecutionResult.failure(scriptName: "Test", error: "Something went wrong")

        #expect(result.scriptName == "Test")
        #expect(result.success == false)
        #expect(result.output == "")
        #expect(result.error == "Something went wrong")
    }

    // MARK: - ScriptError Tests

    @Test("ScriptError has correct descriptions")
    func scriptErrorDescriptions() {
        let launchError = ScriptError.launchFailed("Permission denied")
        #expect(launchError.errorDescription?.contains("Permission denied") == true)

        let execError = ScriptError.executionFailed("Exit code 1")
        #expect(execError.errorDescription?.contains("Exit code 1") == true)

        let workflowError = ScriptError.workflowNotFound("/path/to/workflow")
        #expect(workflowError.errorDescription?.contains("/path/to/workflow") == true)
    }
}
