import UIKit

final class MapLocationTableViewCell: UITableViewCell {
    static let reuseId = "mapLocationCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        textLabel?.font = .boldSystemFont(ofSize: 18)
        detailTextLabel?.font = .systemFont(ofSize: 16)
        textLabel?.textColor = .label
        detailTextLabel?.textColor = .secondaryLabel
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
