import Foundation

// Self-test for parsing the `claude -p --output-format json` reply. Run with `./build.sh test`.

func json(_ s: String) -> Data { s.data(using: .utf8)! }

let structured = json(#"{"is_error":false,"result":"","structured_output":{"professional":"P","shorter":"S","casual":"C"}}"#)
assert(try! parseVariants(structured) == ["P", "S", "C"])

let fenced = json(#"{"is_error":false,"result":"```json\n{\"professional\":\"P\",\"shorter\":\"S\",\"casual\":\"C\"}\n```"}"#)
assert(try! parseVariants(fenced) == ["P", "S", "C"])

let failed = json(#"{"is_error":true,"result":"Failed to authenticate"}"#)
do { _ = try parseVariants(failed); assertionFailure("expected throw") }
catch { assert("\(error)".contains("Failed to authenticate"), "\(error)") }

let missing = json(#"{"is_error":false,"structured_output":{"professional":"P","shorter":"S"}}"#)
do { _ = try parseVariants(missing); assertionFailure("expected throw") } catch {}

// summaries: bullets inside JSON strings, fenced, and a reply missing the second language
// cspell:ignore Shrnutí -- deliberately Czech sample, checks diacritics survive
let summaries = json(#"{"is_error":false,"result":"```json\n{\"english\":\"Bottom line.\\n- point\",\"native\":\"Shrnutí.\\n- bod\"}\n```"}"#)
assert(try! parseFields(summaries, ["english", "native"]) == ["Bottom line.\n- point", "Shrnutí.\n- bod"])
assert(try! parseFields(summaries, ["english"]) == ["Bottom line.\n- point"])
do { _ = try parseFields(json(#"{"is_error":false,"result":"{\"english\":\"E\"}"}"#), ["english", "native"]); assertionFailure("expected throw") } catch {}

// DoubleTap: (only the watched key down, no key down, time) sequences
func taps(_ events: [(Bool, Bool, TimeInterval)], resetBefore: Int? = nil) -> Bool {
    var detector = DoubleTap()
    var fired = false
    for (i, e) in events.enumerated() {
        if i == resetBefore { detector.reset() }
        fired = detector.modifiersChanged(only: e.0, none: e.1, at: e.2) || fired
    }
    return fired
}
assert(taps([(true, false, 0), (false, true, 0.1), (true, false, 0.3)]), "quick double tap")
assert(!taps([(true, false, 0), (false, true, 0.1), (true, false, 0.6)]), "gap too long")
assert(!taps([(true, false, 0), (false, true, 0.5), (true, false, 0.6)]), "first press held too long")
assert(!taps([(true, false, 0), (false, true, 0.1), (true, false, 0.3)], resetBefore: 2), "key typed in between, e.g. ⌥V = @")
assert(!taps([(true, false, 0), (false, false, 0.05), (false, true, 0.1), (true, false, 0.2)]), "⌥⇧ is not a tap")

print("SelfTest OK")
