#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

extension GuestListView {
    // MARK: - Guest Table

    var guestTable: some View {
        VStack(spacing: 0) {
            // Suche-Feld am oberen Rand der Tabelle, statt .searchable()
            // (das auf macOS ohne NavigationStack einen leeren Reservierungs-
            // Bereich erzeugt der den Spalten-Header runterdrueckt).
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Tokens.Colors.ink3)
                    .font(.system(size: 12))
                TextField("Gäste suchen", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .rounded))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Tokens.Colors.ink3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 3)
            .frame(height: 26)
            .background(Tokens.Colors.surface)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Tokens.Colors.line).frame(height: 1)
            }

            if filtering.filteredGuests.isEmpty {
                EmptyStateCard(
                    icon: "person.3.sequence",
                    title: searchText.isEmpty ? "Keine Gäste gefunden" : "Keine Treffer",
                    message: searchText.isEmpty
                        ? "Lade die ersten Anmeldungen rein — aus Google Sheets, Excel oder einzeln per Hand."
                        : "Versuch eine andere Suche oder pass die Filter an."
                )
                .padding(40)
            } else {
                guestTableHeader
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        ForEach(filtering.registrationSections) { section in
                            sectionHeader(section)
                            ForEach(section.guests) { guest in
                                guestRow(guest: guest)
                                Rectangle()
                                    .fill(Tokens.Colors.line)
                                    .frame(height: 1)
                            }
                            ForEach(section.dimmedGuests) { guest in
                                outOfFilterRow(guest: guest)
                                Rectangle()
                                    .fill(Tokens.Colors.line)
                                    .frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
        .background(Tokens.Colors.bg)
    }

    @ViewBuilder
    func outOfFilterRow(guest: Guest) -> some View {
        guestRow(guest: guest)
            .opacity(0.32)
            .saturation(0.4)
            .overlay(alignment: .trailing) {
                Text("nicht im Filter")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Tokens.Colors.bg2)
                    .clipShape(Capsule())
                    .padding(.trailing, 14)
            }
    }

    func sectionHeader(_ section: GuestListFiltering.RegistrationSection) -> some View {
        let total = section.guests.count + section.dimmedGuests.count
        let countText: String
        if section.dimmedGuests.isEmpty {
            countText = "\(total) \(total == 1 ? "Person" : "Personen")"
        } else {
            countText = "\(section.guests.count) von \(total) Personen (gefiltert)"
        }
        return HStack(spacing: 8) {
            if section.isBridal {
                Image(systemName: "heart.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.Colors.accent)
            }
            Text(section.label.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(section.isBridal ? Tokens.Colors.accent : Tokens.Colors.ink3)
                .tracking(0.6)
            Text("·")
                .foregroundStyle(Tokens.Colors.ink4)
            Text(countText)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background(section.isBridal ? Tokens.Colors.accentTint.opacity(0.5) : Tokens.Colors.bg2)
    }

    var guestTableHeader: some View {
        HStack(spacing: 0) {
            tableHeaderCell("Name", width: colNameWidth)
            ColumnResizeHandle(width: $colNameWidth, minWidth: 100, maxWidth: 400)

            if showFunFactColumn {
                tableHeaderCell("FunFact", width: nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showTagsColumn || showSeiteColumn || showTischColumn || showMenuColumn {
                    columnSeparator
                }
            }

            if showTagsColumn {
                tableHeaderCell("Tags", width: colTagsWidth)
                ColumnResizeHandle(width: $colTagsWidth, minWidth: 80, maxWidth: 400)
            }

            if showSeiteColumn {
                tableHeaderCell("Seite", width: colSeiteWidth)
                ColumnResizeHandle(width: $colSeiteWidth, minWidth: 50, maxWidth: 200)
            }

            if showTischColumn {
                tableHeaderCell("Tisch", width: colTischWidth)
                ColumnResizeHandle(width: $colTischWidth, minWidth: 50, maxWidth: 200)
            }

            if showMenuColumn {
                tableHeaderCell("Menü", width: colMenuWidth)
                ColumnResizeHandle(width: $colMenuWidth, minWidth: 60, maxWidth: 240)
            }

            // Wenn FunFact ausgeblendet: Spacer der den verbleibenden Platz frisst,
            // damit der Header rechtsbuendig nicht zerlaeuft.
            if !showFunFactColumn {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(height: 26)
        .background(Tokens.Colors.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tokens.Colors.line).frame(height: 1)
        }
    }

    var columnSeparator: some View {
        Rectangle()
            .fill(Tokens.Colors.line2)
            .frame(width: 1)
            .opacity(0.5)
            .padding(.horizontal, 2)
    }

    func tableHeaderCell(_ label: String, width: CGFloat?) -> some View {
        Text(label.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Tokens.Colors.ink3)
            .tracking(0.5)
            .frame(width: width, alignment: .leading)
    }

    /// Zelle mit FunFact + Status-Indikator. Zeigt den Text gekürzt auf
    /// 2 Zeilen plus ein farbiger Punkt links: grün = OK, gelb = unklar,
    /// orange = fehlt komplett.
    @ViewBuilder
    func funFactCell(for guest: Guest) -> some View {
        let trimmed = guest.funFactDisplay.trimmingCharacters(in: .whitespaces)
        let dotColor: Color = {
            if trimmed.isEmpty { return Color(hex: "#cc8a3a") } // fehlt
            if !guest.funFactApproved { return Color(hex: "#b0b0b0") } // unklar
            return Color(hex: "#5a8a4a") // ok
        }()
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            if trimmed.isEmpty {
                Text("—")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
            } else {
                Text(trimmed)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .help(trimmed)
            }
        }
        .padding(.trailing, 8)
    }

    func guestRow(guest: Guest) -> some View {
        let isSelected = selectedGuestIDs.contains(guest.id)
        let avatarTag = GuestDisplayFormatting.avatarKind(for: guest, tags: tags)

        return HStack(spacing: 0) {
            HStack(spacing: 10) {
                Avatar(name: guest.fullName, size: 28, tag: avatarTag,
                       diet: GuestDisplayFormatting.dietBadge(for: guest), pinned: guest.isPinned)
                VStack(alignment: .leading, spacing: 1) {
                    Text(guest.fullName)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(width: colNameWidth, alignment: .leading)
            Spacer().frame(width: 6)  // matches resize-handle width

            if showFunFactColumn {
                funFactCell(for: guest)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if showTagsColumn {
                ChipFlowLayout(spacing: 4) {
                    let guestTags = tags.filter { $0.guestIDs.contains(guest.id) }
                    ForEach(guestTags, id: \.id) { tag in
                        TagChip(label: tag.name, kind: GuestDisplayFormatting.chipKind(for: tag.category), size: .sm)
                    }
                }
                .frame(width: colTagsWidth, alignment: .leading)
                Spacer().frame(width: 6)
            }

            if showSeiteColumn {
                Text(guest.partnerAssignment.compactDisplayName(for: events.first))
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                    .lineLimit(1)
                    .frame(width: colSeiteWidth, alignment: .leading)
                Spacer().frame(width: 6)
            }

            if showTischColumn {
                Text(guest.table?.name ?? "—")
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(guest.table == nil ? Tokens.Colors.ink3 : Tokens.Colors.ink)
                    .frame(width: colTischWidth, alignment: .leading)
                Spacer().frame(width: 6)
            }

            if showMenuColumn {
                Text(GuestDisplayFormatting.menuLabel(for: guest))
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: colMenuWidth, alignment: .leading)
                Spacer().frame(width: 6)
            }

            if !showFunFactColumn {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? Tokens.Colors.accentTint : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            handleRowTap(guest: guest)
        }
        .contextMenu {
            Button("Bearbeiten") { editingGuest = guest }
            Button(guest.isPinned ? "Pin lösen" : "Anpinnen") { guest.isPinned.toggle() }
            // FunFact-Status quick-toggle — nur sichtbar wenn ein FunFact da ist
            if !guest.funFact.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(guest.funFactApproved ? "FunFact als unklar markieren" : "FunFact ist ok") {
                    guest.funFactApproved.toggle()
                }
            }
            Button(guest.phoneNumber.isEmpty ? "Telefonnummer aus Kontakten…" : "Telefonnummer ersetzen aus Kontakten…") {
                Task { await importPhoneFromContacts(for: guest) }
            }
            Divider()
            Button("Löschen", role: .destructive) {
                if selectedGuestIDs.contains(guest.id) && selectedGuestIDs.count > 1 {
                    showingDeleteAlert = true
                } else {
                    modelContext.delete(guest)
                    selectedGuestIDs.remove(guest.id)
                }
            }
        }
    }

    func handleRowTap(guest: Guest) {
        #if os(iOS)
        if selectedGuestIDs.contains(guest.id) {
            selectedGuestIDs.remove(guest.id)
        } else {
            selectedGuestIDs.insert(guest.id)
            anchorGuestID = guest.id
        }
        #else
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift), let anchor = anchorGuestID {
            // Range-Auswahl: alles zwischen anchor und guest in der aktuell sichtbaren
            // Liste markieren — folgt der Reihenfolge die der User sieht.
            let visible = filtering.filteredGuests
            if let aIdx = visible.firstIndex(where: { $0.id == anchor }),
               let bIdx = visible.firstIndex(where: { $0.id == guest.id }) {
                let lo = min(aIdx, bIdx)
                let hi = max(aIdx, bIdx)
                let range = visible[lo...hi].map(\.id)
                selectedGuestIDs.formUnion(range)
            } else {
                selectedGuestIDs.insert(guest.id)
            }
        } else if flags.contains(.command) {
            // Cmd+Klick: einzelnen Eintrag toggeln, Anker bleibt
            if selectedGuestIDs.contains(guest.id) {
                selectedGuestIDs.remove(guest.id)
            } else {
                selectedGuestIDs.insert(guest.id)
                anchorGuestID = guest.id
            }
        } else {
            // Normaler Klick: Single-Select
            selectedGuestIDs = [guest.id]
            anchorGuestID = guest.id
        }
        #endif
    }

    @MainActor
    func importPhoneFromContacts(for guest: Guest) async {
        do {
            let granted = try await ContactsService.requestAccess()
            guard granted else {
                contactErrorMessage = ContactsServiceError.accessDenied.errorDescription
                return
            }
            // Sheet immer oeffnen — auch bei 0 Treffern, damit der User
            // selbst weitersuchen kann (Spitzname, Mädchenname etc.).
            let matches = try ContactsService.search(firstName: guest.firstName, lastName: guest.lastName)
            contactPickerMatches = matches
            contactPickerGuest = guest
        } catch let error as ContactsServiceError {
            contactErrorMessage = error.errorDescription
        } catch {
            contactErrorMessage = error.localizedDescription
        }
    }
}
#endif
