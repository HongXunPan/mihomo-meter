import Foundation
import XCTest

@testable import MihomoMeter

final class QuotaTrendAxisPresentationTests: XCTestCase {
  private let locale = Locale(identifier: "en_US_POSIX")

  func testGigabyteAxisUsesConsistentPrecisionAcrossTen() {
    let axis = QuotaTrendAxisPresentation(domain: 6_000_000_000...14_000_000_000)

    XCTAssertEqual(axis.bytes(7_500_000_000, locale: locale), "7.5 GB")
    XCTAssertEqual(axis.bytes(10_000_000_000, locale: locale), "10.0 GB")
    XCTAssertEqual(axis.bytes(12_500_000_000, locale: locale), "12.5 GB")
  }

  func testAxisKeepsOneUnitAcrossUnitBoundary() {
    let axis = QuotaTrendAxisPresentation(domain: 900_000_000...1_200_000_000)

    XCTAssertEqual(axis.bytes(900_000_000, locale: locale), "0.90 GB")
    XCTAssertEqual(axis.bytes(1_000_000_000, locale: locale), "1.00 GB")
  }

  func testNarrowDomainRetainsDistinctLabels() {
    let axis = QuotaTrendAxisPresentation(domain: 7_500_000_000...7_504_000_000)

    XCTAssertEqual(axis.bytes(7_501_000_000, locale: locale), "7.501 GB")
    XCTAssertEqual(axis.bytes(7_502_000_000, locale: locale), "7.502 GB")
  }

  func testByteAxisUsesWholeNumbers() {
    let axis = QuotaTrendAxisPresentation(domain: 0...900)

    XCTAssertEqual(axis.bytes(0, locale: locale), "0 B")
    XCTAssertEqual(axis.bytes(250, locale: locale), "250 B")
  }

  func testDayTicksShowTimeAndWeekTicksOnlyShowDate() {
    let date = Date(timeIntervalSince1970: 1_789_872_000)
    let timeZone = TimeZone(secondsFromGMT: 0)!
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = timeZone
    formatter.setLocalizedDateFormatFromTemplate("HHmm")
    XCTAssertEqual(
      QuotaTrendAxisPresentation.compactDate(
        date, window: .day, locale: locale, timeZone: timeZone
      ),
      formatter.string(from: date)
    )

    formatter.setLocalizedDateFormatFromTemplate("Md")
    XCTAssertEqual(
      QuotaTrendAxisPresentation.compactDate(
        date, window: .week, locale: locale, timeZone: timeZone
      ),
      formatter.string(from: date)
    )
  }

  func testTrendMenuDoesNotGrowForCycleConfirmation() {
    XCTAssertEqual(StatusMenuLayout.quotaTrendSubmenuSize.width, 380)
    XCTAssertEqual(StatusMenuLayout.quotaTrendSubmenuSize.height, 496)
  }
}
