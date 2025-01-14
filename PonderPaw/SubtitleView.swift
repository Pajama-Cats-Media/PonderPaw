import UIKit
import Combine

class SubtitleView: UIView {
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private var cancellables: Set<AnyCancellable> = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        addSubview(subtitleLabel)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            subtitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            subtitleLabel.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.9)
        ])
    }

    func bind(to viewModel: SubtitleViewModel) {
        viewModel.$currentSubtitle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] subtitle in
                self?.subtitleLabel.text = subtitle
            }
            .store(in: &cancellables)
    }
}
