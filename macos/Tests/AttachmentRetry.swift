import Foundation

@main
struct AttachmentRetryTests {
    static func main() {
        let start = Date(timeIntervalSince1970: 1_000)
        var retry = AttachmentRetryState()
        let first = retry.begin("avatar", now: start)!
        precondition(retry.begin("avatar", now: start) == nil, "Repeated drawing must not start parallel downloads")
        precondition(retry.failed("avatar", token: first, now: start))
        precondition(retry.begin("avatar", now: start.addingTimeInterval(0.9)) == nil)
        precondition(retry.takeDue(now: start.addingTimeInterval(1)) == ["avatar"])
        precondition(retry.nextRetry == nil, "Offscreen files must not keep waking the app")
        let second = retry.begin("avatar", now: start.addingTimeInterval(1))!
        precondition(second != first)
        precondition(retry.succeeded("avatar", token: second))
        print("PASS: Failed avatar downloads retry without parallel requests or restart")

        var now = start
        for _ in 0..<10 {
            let token = retry.begin("file", now: now)!
            precondition(retry.failed("file", token: token, now: now))
            let deadline = retry.nextRetry!
            precondition(deadline.timeIntervalSince(now) >= 1 && deadline.timeIntervalSince(now) <= 30)
            now = deadline
            precondition(retry.takeDue(now: now) == ["file"])
        }
        precondition(retry.nextRetry == nil)
        print("PASS: Repeated failures back off at most 30 seconds and idle offscreen")

        let stale = retry.begin("file", now: now)!
        retry.reset()
        let fresh = retry.begin("file", now: now)!
        precondition(!retry.failed("file", token: stale, now: now))
        precondition(!retry.succeeded("file", token: stale))
        precondition(retry.begin("file", now: now) == nil)
        precondition(retry.succeeded("file", token: fresh))
        print("PASS: Reconnection retries immediately and stale account completions are ignored")
    }
}
