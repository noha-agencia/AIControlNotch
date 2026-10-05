import CoreGraphics
import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct NotchLayoutTests {
    let layout = NotchLayout(notch: CGSize(width: 190, height: 32))

    @Test func mockupSizes() {
        // Each side holds logo, "100" and the dot clear of the camera: 13 + 12 + 6 + 22 + 6 + 7 + 4.
        #expect(layout.frame(for: .rest) == NotchFrame(width: 190 + 2 * 70, height: 32, radius: 10))
        #expect(layout.frame(for: .open(rows: 3, sections: 2)) == NotchFrame(width: 672, height: 226, radius: 26))
        #expect(layout.frame(for: .alert) == NotchFrame(width: 470, height: 90, radius: 24))
    }

    @Test func openGrowsWithRows() {
        let four = layout.frame(for: .open(rows: 4, sections: 2))
        #expect(four.height == 272, "one more 46 pt row")
    }

    @Test func followsATallerNotch() {
        let tall = NotchLayout(notch: CGSize(width: 200, height: 38))
        #expect(tall.frame(for: .rest) == NotchFrame(width: 340, height: 38, radius: 10))
        #expect(tall.frame(for: .alert).height == 96)
        #expect(tall.alertTopPadding == 42)
    }

    @Test func canvasFitsTheLargestState() {
        let canvas = layout.canvasSize(rows: 6, sections: 2)
        #expect(canvas.width >= 672 + 2 * NotchLayout.earRadius)
        #expect(canvas.height >= layout.frame(for: .open(rows: 6, sections: 2)).height)
    }

    @Test func canvasGrowsWithMoreModels() {
        let two = layout.canvasSize(rows: 6, sections: 2)
        let four = layout.canvasSize(rows: 8, sections: 4)
        #expect(four.height == two.height + 2 * NotchLayout.rowHeight + 2, "two more rows and two more dividers")
        #expect(four.width == two.width)
    }

    @Test func hitRectIsCenteredAtTheTop() {
        let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let rect = layout.hitRect(for: .rest, screenFrame: screen)
        #expect(rect == CGRect(x: 1728 / 2 - 165 - 9, y: 1117 - 32, width: 330 + 18, height: 32))
    }
}
