import Foundation

// MARK: - Production-Ready RFC 4180 CSV Parser
public enum CSVParserError: LocalizedError {
    case emptyData
    case missingHeader(String)
    case malformedRow(Int, String)
    case fileNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .emptyData:
            return "Die CSV-Datei ist leer."
        case .missingHeader(let header):
            return "Erforderliche Spalte fehlt: '\(header)'."
        case .malformedRow(let index, let line):
            return "Fehlerhafte Zeile bei Index \(index): \(line)"
        case .fileNotFound(let path):
            return "CSV-Datei konnte unter '\(path)' nicht gefunden werden."
        }
    }
}

public final class CSVParser {
    
    public static let shared = CSVParser()
    
    private init() {}
    
    /// Parses a raw CSV string adhering to RFC 4180 rules
    /// (handles quoted fields, embedded commas, escaped quotes `""`, and line breaks)
    public func parse(csvString: String) throws -> [VocabularyWord] {
        let rows = parseCSVToRows(text: csvString)
        guard let headerRow = rows.first, !rows.isEmpty else {
            throw CSVParserError.emptyData
        }
        
        let headerMap = mapHeaders(headerRow)
        
        // Validate required columns
        guard let articleIndex = headerMap["article/type"] ?? headerMap["article"] ?? headerMap["type"] else {
            throw CSVParserError.missingHeader("Article/Type")
        }
        guard let wordIndex = headerMap["word"] ?? headerMap["wort"] else {
            throw CSVParserError.missingHeader("Word")
        }
        guard let englishIndex = headerMap["english definition"] ?? headerMap["english"] else {
            throw CSVParserError.missingHeader("English Definition")
        }
        guard let germanIndex = headerMap["german definition"] ?? headerMap["german"] else {
            throw CSVParserError.missingHeader("German Definition")
        }
        guard let b1Index = headerMap["b1 example"] ?? headerMap["b1"] else {
            throw CSVParserError.missingHeader("B1 Example")
        }
        guard let b2Index = headerMap["b2 example"] ?? headerMap["b2"] else {
            throw CSVParserError.missingHeader("B2 Example")
        }
        
        var words: [VocabularyWord] = []
        words.reserveCapacity(rows.count - 1)
        
        for (index, row) in rows.dropFirst().enumerated() {
            // Skip empty rows
            if row.isEmpty || (row.count == 1 && row[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                continue
            }
            
            func field(at idx: Int) -> String {
                if idx < row.count {
                    return row[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return ""
            }
            
            let articleOrType = field(at: articleIndex)
            let word = field(at: wordIndex)
            let englishDef = field(at: englishIndex)
            let germanDef = field(at: germanIndex)
            let b1Example = field(at: b1Index)
            let b2Example = field(at: b2Index)
            
            guard !word.isEmpty else {
                continue
            }
            
            let vocabWord = VocabularyWord(
                articleOrType: articleOrType,
                word: word,
                englishDefinition: englishDef,
                germanDefinition: germanDef,
                b1Example: b1Example,
                b2Example: b2Example
            )
            words.append(vocabWord)
        }
        
        return words
    }
    
    /// Parses a file directly from a file URL or App Bundle
    public func parse(fileURL: URL) throws -> [VocabularyWord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CSVParserError.fileNotFound(fileURL.path)
        }
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return try parse(csvString: content)
    }
    
    // MARK: - Low-Level RFC 4180 State Machine
    
    private func parseCSVToRows(text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        let characters = Array(text)
        var i = 0
        let count = characters.count
        
        while i < count {
            let char = characters[i]
            
            if insideQuotes {
                if char == "\"" {
                    // Check for escaped double quote ("")
                    if i + 1 < count && characters[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 1 // skip next quote
                    } else {
                        // End of quoted field
                        insideQuotes = false
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                if char == "\"" {
                    insideQuotes = true
                } else if char == "," {
                    currentRow.append(currentField)
                    currentField = ""
                } else if char == "\r" {
                    // Check for Windows \r\n
                    if i + 1 < count && characters[i + 1] == "\n" {
                        i += 1
                    }
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                } else if char == "\n" {
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                } else {
                    currentField.append(char)
                }
            }
            
            i += 1
        }
        
        // Append any trailing field and row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }
        
        return rows
    }
    
    private func mapHeaders(_ headerRow: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (index, col) in headerRow.enumerated() {
            let normalized = col.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            map[normalized] = index
        }
        return map
    }
}
