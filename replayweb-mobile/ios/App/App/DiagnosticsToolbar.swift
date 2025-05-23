import UIKit

class DiagnosticsToolbar: UIView {
    // Buttons for testing each feature
    private let swButton = UIButton(type: .system)
    private let waczButton = UIButton(type: .system)
    private let offlineButton = UIButton(type: .system)
    private let hideButton = UIButton(type: .system)
    
    // Callbacks for button actions
    var onTestServiceWorker: (() -> Void)?
    var onTestWACZImport: (() -> Void)?
    var onTestOfflineMode: (() -> Void)?
    var onHide: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = UIColor.darkGray.withAlphaComponent(0.9)
        layer.cornerRadius = 10
        layer.masksToBounds = true
        
        // Setup buttons
        setupButton(swButton, title: "Test SW", selector: #selector(testServiceWorkerTapped))
        setupButton(waczButton, title: "Test WACZ", selector: #selector(testWACZImportTapped))
        setupButton(offlineButton, title: "Test Offline", selector: #selector(testOfflineModeTapped))
        setupButton(hideButton, title: "Hide", selector: #selector(hideTapped))
        
        // Add to stack view for horizontal layout
        let stackView = UIStackView(arrangedSubviews: [swButton, waczButton, offlineButton, hideButton])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 5
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }
    
    private func setupButton(_ button: UIButton, title: String, selector: Selector) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
        button.layer.cornerRadius = 5
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        button.addTarget(self, action: selector, for: .touchUpInside)
    }
    
    // Button actions
    @objc private func testServiceWorkerTapped() {
        onTestServiceWorker?()
    }
    
    @objc private func testWACZImportTapped() {
        onTestWACZImport?()
    }
    
    @objc private func testOfflineModeTapped() {
        onTestOfflineMode?()
    }
    
    @objc private func hideTapped() {
        onHide?()
    }
}
