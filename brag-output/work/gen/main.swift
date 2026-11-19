import Foundation

// Runs the app's real Rewriter on the video's sample texts and saves the answers as JSON.
// Usage: gen <output.json>

let message = "hele ten deploy včera rozbil přihlašování, už jsem to rollbacknul, ale potřebuju aby se na to někdo z backendu podíval dneska"
let thread = """
Petr: ahoj, tak jsme včera řešili s klientem tu migraci databáze. Chtějí to mít hotové do konce měsíce, ale upřímně si myslím že to nestihneme, protože ještě nemáme vyřešené ty indexy na tabulce orders.
Jana: souhlas, navíc Martin je příští týden na dovolené. Můžeme posunout termín?
Petr: zkusím to s nimi probrat ve čtvrtek na callu. Kdyby to nešlo, tak bychom museli vzít někoho z platform týmu.
Jana: ok, já mezitím připravím odhad, kolik ta migrace reálně zabere. Pošlu do středy.
Tomáš: jen připomínám, že rozpočet na Q4 je už skoro vyčerpaný, zbývá cca 12k EUR.
"""

var out: [String: Any] = ["message": message, "thread": thread, "nativeLanguage": Rewriter.nativeLanguage ?? ""]
var pending = 2
_ = Rewriter.run(message) { result in
    switch result {
    case .success(let list): out["variants"] = list
    case .failure(let error): print("rewrite failed:", error)
    }
    pending -= 1
}
_ = Rewriter.summarize(thread) { result in
    switch result {
    case .success(let list): out["summaries"] = list
    case .failure(let error): print("summary failed:", error)
    }
    pending -= 1
}
while pending > 0 { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
let data = try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys])
FileManager.default.createFile(atPath: CommandLine.arguments[1], contents: data)
print("wrote", CommandLine.arguments[1])
