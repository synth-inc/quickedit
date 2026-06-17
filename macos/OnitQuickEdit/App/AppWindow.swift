//
//  AppWindow.swift
//  Onit
//
//  Created by Loyd Kim on 4/28/26.
//

final class AppWindow: CenteredWindow<AppWindowView> {
    init() {
        super.init(
            rootView: AppWindowView(),
            canResize: true,
            canCloseWithEsc: false,
            windowSize: (
                width: 750,
                height: 700
            ),
            titleBarButtonsOffset: (
                xOffset: 10,
                yOffset: 4
            )
        )
    }
}
