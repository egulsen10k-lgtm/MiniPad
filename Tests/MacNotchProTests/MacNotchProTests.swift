import XCTest
import UniformTypeIdentifiers
@testable import MiniPad

final class MiniPadTests: XCTestCase {
    
    func testNSItemProviderLoadingOnDrop() throws {
        // Arrange
        let expectedId = "test-item-id"
        let itemProvider = NSItemProvider(object: expectedId as NSString)
        
        let expectation = self.expectation(description: "Loading plain text identifier from NSItemProvider")
        
        // Act & Assert
        // We'll simulate how the view loads the item using UTType.plainText.identifier
        XCTAssertTrue(itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier))
        
        itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { rawData, error in
            XCTAssertNil(error)
            
            var strId: String? = nil
            if let str = rawData as? String { strId = str }
            else if let ns = rawData as? NSString { strId = ns as String }
            else if let d = rawData as? Data { strId = String(data: d, encoding: .utf8) }
            
            XCTAssertEqual(strId, expectedId)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0, handler: nil)
    }
}
