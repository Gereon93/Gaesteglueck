import Testing
import Foundation
@testable import Gaesteglueck

@Suite("GoogleSheetsURL")
struct GoogleSheetsURLTests {
    @Test("Edit URL becomes CSV export URL")
    func editURLToExport() throws {
        let edit = "https://docs.google.com/spreadsheets/d/1abcXYZ_123/edit#gid=0"
        let exportURL = try #require(GoogleSheetsURL.csvExportURL(from: edit))
        #expect(exportURL.absoluteString == "https://docs.google.com/spreadsheets/d/1abcXYZ_123/export?format=csv&gid=0")
    }

    @Test("Sharing URL without gid omits gid")
    func sharingURLWithoutGid() throws {
        let share = "https://docs.google.com/spreadsheets/d/abc123/edit?usp=sharing"
        let exportURL = try #require(GoogleSheetsURL.csvExportURL(from: share))
        #expect(exportURL.absoluteString == "https://docs.google.com/spreadsheets/d/abc123/export?format=csv")
    }

    @Test("Specific tab gid in query is preserved")
    func gidInQueryPreserved() throws {
        let url = "https://docs.google.com/spreadsheets/d/abc123/edit?gid=987654#gid=987654"
        let exportURL = try #require(GoogleSheetsURL.csvExportURL(from: url))
        #expect(exportURL.absoluteString == "https://docs.google.com/spreadsheets/d/abc123/export?format=csv&gid=987654")
    }

    @Test("Already-export URL still produces valid export URL")
    func alreadyExportURL() throws {
        let url = "https://docs.google.com/spreadsheets/d/xyz789/export?format=csv"
        let exportURL = try #require(GoogleSheetsURL.csvExportURL(from: url))
        #expect(exportURL.absoluteString == "https://docs.google.com/spreadsheets/d/xyz789/export?format=csv")
    }

    @Test("Whitespace is trimmed")
    func whitespaceTrimmed() throws {
        let url = "  https://docs.google.com/spreadsheets/d/abc/edit  \n"
        let exportURL = try #require(GoogleSheetsURL.csvExportURL(from: url))
        #expect(exportURL.absoluteString == "https://docs.google.com/spreadsheets/d/abc/export?format=csv")
    }

    @Test("Non-Sheets URL returns nil")
    func nonSheetsURL() {
        #expect(GoogleSheetsURL.csvExportURL(from: "https://example.com/foo") == nil)
    }

    @Test("Empty input returns nil")
    func emptyInput() {
        #expect(GoogleSheetsURL.csvExportURL(from: "") == nil)
        #expect(GoogleSheetsURL.csvExportURL(from: "   ") == nil)
    }

    @Test("Garbage string returns nil")
    func garbageString() {
        #expect(GoogleSheetsURL.csvExportURL(from: "lol nope") == nil)
    }
}
