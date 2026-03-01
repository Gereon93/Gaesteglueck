import Foundation

enum FamilyGrouper {
    static func group(_ guests: [Guest]) -> [[Guest]] {
        var familyGroups: [UUID: [Guest]] = [:]
        var individuals: [[Guest]] = []

        for guest in guests {
            if let fid = guest.familyID {
                familyGroups[fid, default: []].append(guest)
            } else {
                individuals.append([guest])
            }
        }

        return Array(familyGroups.values) + individuals
    }

    static func findSeparatedFamilies(tables: [GuestTable], guests: [Guest]) -> [SeparatedFamily] {
        var guestToTable: [UUID: UUID] = [:]
        for table in tables {
            for guest in table.guests {
                guestToTable[guest.id] = table.id
            }
        }

        let families = Dictionary(grouping: guests.filter { $0.familyID != nil }, by: { $0.familyID! })

        var separated: [SeparatedFamily] = []
        for (familyID, members) in families {
            let tableIDs = Set(members.compactMap { guestToTable[$0.id] })
            if tableIDs.count > 1 {
                separated.append(SeparatedFamily(
                    familyID: familyID,
                    memberNames: members.map(\.name),
                    tableCount: tableIDs.count
                ))
            }
        }

        return separated
    }
}

struct SeparatedFamily: Identifiable {
    let id = UUID()
    let familyID: UUID
    let memberNames: [String]
    let tableCount: Int
}
