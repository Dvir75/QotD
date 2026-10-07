import Foundation

// Build from repo root:
//   swiftc -o /tmp/quote_paste_smoke Shared/QuotePastePipeline.swift Scripts/quote_paste_smoke_main.swift
//   /tmp/quote_paste_smoke

@main
struct QuotePasteSmokeMain {
    static func main() {
        var failures = 0

        func expect(
            _ name: String,
            _ raw: String,
            cleanup: Bool = true,
            autoCap: Bool = true,
            text: String,
            author: String
        ) {
            let result = QuotePastePipeline.process(
                raw,
                options: .init(cleanup: cleanup, autoCapitalize: autoCap)
            )
            if result.text != text || result.author != author {
                failures += 1
                fputs(
                    "FAIL \(name)\n  got: text=\(result.text.debugDescription) author=\(result.author.debugDescription)\n  exp: text=\(text.debugDescription) author=\(author.debugDescription)\n",
                    stderr
                )
            }
        }

        expect(
            "quoted dash",
            "\"not all who wander are lost\" - tolkien",
            text: "Not all who wander are lost",
            author: "Tolkien"
        )

        expect(
            "curly quoted em dash",
            "“hello world” — ada lovelace",
            text: "Hello world",
            author: "Ada Lovelace"
        )

        expect(
            "by separator",
            "\"ships are safe in harbor\" by john shedd",
            text: "Ships are safe in harbor",
            author: "John Shedd"
        )

        expect(
            "unquoted last dash",
            "to be or not to be - shakespeare",
            text: "To be or not to be",
            author: "Shakespeare"
        )

        expect(
            "multiline attribution",
            "line one\nline two\n- emily dickinson",
            text: "Line one\nline two",
            author: "Emily Dickinson"
        )

        expect(
            "hebrew maat",
            "\"שלום עולם\" מאת ביאליק",
            text: "שלום עולם",
            author: "ביאליק"
        )

        expect(
            "no split cleanup only",
            "\"just a quote\"",
            text: "Just a quote",
            author: ""
        )

        expect(
            "cleanup off",
            "\"hello\" - bob",
            cleanup: false,
            autoCap: false,
            text: "hello",
            author: "bob"
        )

        expect(
            "prefix by on author after split",
            "\"hi\" - by alice",
            text: "Hi",
            author: "Alice"
        )

        if failures == 0 {
            print("quote_paste_smoke: OK")
        } else {
            fputs("quote_paste_smoke: \(failures) failure(s)\n", stderr)
            exit(1)
        }
    }
}
