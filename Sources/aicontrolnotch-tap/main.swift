import Foundation
import AIControlNotchCore

// Claude Code status line wrapper: records the plan limits, then prints the original line.

/// Last resort: whatever hangs below, the status line returns, empty, shortly after the command's timeout.
let watchdogDelay = StatusLineTap.commandTimeout + 2
DispatchQueue.global().asyncAfter(deadline: .now() + watchdogDelay) { exit(0) }

let input = FileHandle.standardInput.readDataToEndOfFile()
let output = await StatusLineTap(paths: Paths.current()).run(input: input)
try? FileHandle.standardOutput.write(contentsOf: output.stdout)
exit(output.exitCode)
