import Foundation
import SwiftUI
import Testing
@testable import SaneClick

struct ExtensionStatusTests {
    @Test("pluginkit output parser detects enabled extension")
    func parsePluginkitEnabledOutput() {
        let output = """
        +    com.saneclick.SaneClick.FinderSync(1.1.0)\tUUID\t2026-03-16 23:01:17 +0000\t/Applications/SaneClick.app/Contents/PlugIns/SaneClickExtension.appex
         (1 plug-in)
        """

        #expect(ExtensionStatusService.parsePluginKitEnabled(output) == true)
    }

    @Test("pluginkit output parser rejects disabled extension")
    func parsePluginkitDisabledOutput() {
        let output = """
        -    com.saneclick.SaneClick.FinderSync(1.1.0)\tUUID\t2026-03-16 23:01:17 +0000\t/Applications/SaneClick.app/Contents/PlugIns/SaneClickExtension.appex
         (1 plug-in)
        """

        #expect(ExtensionStatusService.parsePluginKitEnabled(output) == false)
    }

    @Test("scene phase auto-refreshes when app becomes active again")
    func refreshOnSceneActivation() {
        #expect(
            ExtensionStatusService.shouldRefreshStatusOnScenePhaseChange(
                oldPhase: .inactive,
                newPhase: .active
            ) == true
        )
        #expect(
            ExtensionStatusService.shouldRefreshStatusOnScenePhaseChange(
                oldPhase: .background,
                newPhase: .active
            ) == true
        )
    }

    @Test("scene phase does not refresh for non-activation transitions")
    func noRefreshForNonActivationTransitions() {
        #expect(
            ExtensionStatusService.shouldRefreshStatusOnScenePhaseChange(
                oldPhase: .active,
                newPhase: .inactive
            ) == false
        )
        #expect(
            ExtensionStatusService.shouldRefreshStatusOnScenePhaseChange(
                oldPhase: .inactive,
                newPhase: .background
            ) == false
        )
    }

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
