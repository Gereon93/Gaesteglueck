#if canImport(SwiftUI)
import SwiftUI

struct TableRowView: View {
    let table: GuestTable

    var body: some View {
        HStack {
            Image(systemName: table.shape.icon)
                .foregroundStyle(.secondary)
                .frame(width: 30)
            VStack(alignment: .leading) {
                Text(table.name)
                    .font(.body)
                Text(table.shape.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(table.guests.count)/\(table.capacity)")
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(table.isFull ? .red : .secondary)
        }
    }
}
#endif
