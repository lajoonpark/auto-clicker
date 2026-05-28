#if canImport(AppKit)
import AppKit

@MainActor
final class MainViewController: NSViewController {
    private let tabBar = TabBarView()
    private let containerView = NSView()
    private let childControllers: [NSViewController]
    private let titles: [String]
    private var currentIndex = 0

    init(childControllers: [NSViewController], titles: [String]) {
        self.childControllers = childControllers
        self.titles = titles
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        tabBar.translatesAutoresizingMaskIntoConstraints = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBar)
        view.addSubview(containerView)
        tabBar.setTabs(titles)
        tabBar.onSelectionChanged = { [weak self] index in
            self?.selectTab(index)
        }

        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            containerView.topAnchor.constraint(equalTo: tabBar.bottomAnchor, constant: 16),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        if let first = childControllers.first {
            embed(first)
        }
    }

    private func selectTab(_ index: Int) {
        guard index != currentIndex, childControllers.indices.contains(index) else { return }
        removeCurrentChild()
        currentIndex = index
        tabBar.select(index: index)
        embed(childControllers[index])
    }

    private func embed(_ controller: NSViewController) {
        addChild(controller)
        let childView = controller.view
        childView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(childView)
        NSLayoutConstraint.activate([
            childView.topAnchor.constraint(equalTo: containerView.topAnchor),
            childView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            childView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            childView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }

    private func removeCurrentChild() {
        let controller = childControllers[currentIndex]
        controller.view.removeFromSuperview()
        controller.removeFromParent()
    }
}
#endif
