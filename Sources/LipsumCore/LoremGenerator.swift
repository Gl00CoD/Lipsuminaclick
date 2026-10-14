/// Generates random lorem ipsum sentences and paragraphs.
public enum LoremGenerator {
    public static let words: [String] = [
        "lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing", "elit",
        "sed", "do", "eiusmod", "tempor", "incididunt", "ut", "labore", "et", "dolore",
        "magna", "aliqua", "enim", "ad", "minim", "veniam", "quis", "nostrud",
        "exercitation", "ullamco", "laboris", "nisi", "aliquip", "ex", "ea", "commodo",
        "consequat", "duis", "aute", "irure", "in", "reprehenderit", "voluptate",
        "velit", "esse", "cillum", "fugiat", "nulla", "pariatur", "excepteur", "sint",
        "occaecat", "cupidatat", "non", "proident", "sunt", "culpa", "qui", "officia",
        "deserunt", "mollit", "anim", "id", "est", "laborum", "praesent", "vitae",
        "mauris", "vel", "nunc", "facilisis", "pellentesque", "habitant", "morbi",
        "tristique", "senectus", "netus", "malesuada", "fames", "ac", "turpis",
        "egestas", "integer", "feugiat", "scelerisque", "varius", "quam", "viverra",
        "orci", "sagittis", "eu", "volutpat", "odio", "aenean", "pharetra", "massa",
        "ultricies", "mi", "posuere", "lacus", "vestibulum", "rhoncus", "urna",
        "neque", "gravida", "dictum", "fusce", "placerat", "purus", "semper", "auctor"
    ]

    public static let sentenceWordRange = 8...16
    public static let paragraphSentenceRange = 4...7

    // MARK: Convenience (system randomness)

    public static func sentence() -> String {
        var rng = SystemRandomNumberGenerator()
        return sentence(using: &rng)
    }

    public static func paragraph() -> String {
        var rng = SystemRandomNumberGenerator()
        return paragraph(using: &rng)
    }

    // MARK: Generation with an injectable generator

    public static func sentence<G: RandomNumberGenerator>(using rng: inout G) -> String {
        let count = Int.random(in: sentenceWordRange, using: &rng)
        // Longer sentences sometimes get a comma somewhere in the middle.
        let commaIndex: Int? = (count >= 10 && Bool.random(using: &rng))
            ? Int.random(in: 3...(count - 4), using: &rng)
            : nil

        var result: [String] = []
        result.reserveCapacity(count)
        var previous = ""
        for index in 0..<count {
            var word = words.randomElement(using: &rng)!
            while word == previous {
                word = words.randomElement(using: &rng)!
            }
            previous = word
            if index == 0 {
                word = word.prefix(1).uppercased() + word.dropFirst()
            }
            if index == commaIndex {
                word += ","
            }
            result.append(word)
        }
        return result.joined(separator: " ") + "."
    }

    public static func paragraph<G: RandomNumberGenerator>(using rng: inout G) -> String {
        let count = Int.random(in: paragraphSentenceRange, using: &rng)
        return (0..<count).map { _ in sentence(using: &rng) }.joined(separator: " ")
    }
}
