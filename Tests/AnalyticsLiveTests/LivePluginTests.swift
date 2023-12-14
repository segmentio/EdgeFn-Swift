//
//  File.swift
//  
//
//  Created by Brandon Sneed on 5/5/22.
//

import Foundation
import XCTest
@testable import Segment
@testable import Substrata
@testable import AnalyticsLive

class LivePluginTests: XCTestCase {
    let downloadURL = URL(string: "http://segment.com/bundles/testbundle.js")!
    let errorURL = URL(string:"http://error.com/bundles/testbundle.js")
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // setup our mock network handling.
        Bundler.sessionConfig = URLSessionConfiguration.ephemeral
        Bundler.sessionConfig.protocolClasses = [URLProtocolMock.self]
        
        let dataFile = bundleTestFile(file: "testbundle.js")
        let bundleData = try Data(contentsOf: dataFile!)
        
        URLProtocolMock.testURLs = [
            downloadURL: .success(bundleData),
            errorURL: .failure(NetworkError.failed(URLError.cannotLoadFromNetwork))
        ]
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
        // set our network handling back to default.
        Bundler.sessionConfig = URLSessionConfiguration.default
    }
    
    func testEdgeFnMultipleLoad() throws {
        LivePlugins.clearCache()
        
        let analytics = Analytics(configuration: Configuration(writeKey: "1234"))
        analytics.add(plugin: LivePlugins(fallbackFileURL: bundleTestFile(file: "testbundle.js")))
        analytics.add(plugin: LivePlugins(fallbackFileURL: bundleTestFile(file: "testbundle.js")))
        analytics.add(plugin: LivePlugins(fallbackFileURL: bundleTestFile(file: "testbundle.js")))

        
        let v1 = analytics.find(pluginType: LivePlugins.self)
        analytics.remove(plugin: v1!)
        
        let v2 = analytics.find(pluginType: LivePlugins.self)
        XCTAssertNil(v2)
    }
    
    func testEdgeFnLoad() throws {
        LivePlugins.clearCache()
        
        let analytics = Analytics(configuration: Configuration(writeKey: "1234"))
        analytics.add(plugin: LivePlugins(fallbackFileURL: bundleTestFile(file: "testbundle.js")))
        
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)
        
        waitUntilStarted(analytics: analytics)
        
        analytics.track(name: "blah", properties: nil)
        
        var lastEvent: RawEvent? = nil
        while lastEvent == nil {
            RunLoop.main.run(until: Date.distantPast)
            lastEvent = outputReader.lastEvent
        }
        
        let msg: String? = lastEvent?.context?[keyPath: "livePluginMessage"]!
        XCTAssertEqual(msg, "This came from a LivePlugin")
    }
    
    func testEventMorphing() throws {
        LivePlugins.clearCache()
        
        let analytics = Analytics(configuration: Configuration(writeKey: "1234"))
        analytics.add(plugin: LivePlugins(fallbackFileURL: bundleTestFile(file: "testbundle.js")))
        
        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)
        
        waitUntilStarted(analytics: analytics)
        
        analytics.screen(title: "blah")
        
        while outputReader.events.count < 2 {
            RunLoop.main.run(until: Date.distantPast)
        }
        
        let trackEvent = outputReader.events[0] as? TrackEvent
        let screenEvent = outputReader.events[1] as? ScreenEvent
        XCTAssertNotNil(screenEvent)
        XCTAssertNotNil(trackEvent)
        XCTAssertEqual(trackEvent!.event, "trackScreen")
    }


    func testIdentifyWithTraits() throws {
        LivePlugins.clearCache()

        let analytics = Analytics(configuration: Configuration(writeKey: "1234"))

        analytics.add(plugin: LivePlugins(fallbackFileURL: bundleTestFile(file: "noopbundle.js")))

        let outputReader = OutputReaderPlugin()
        analytics.add(plugin: outputReader)

        waitUntilStarted(analytics: analytics)

        struct MyTraits: Codable {
            let email: String?,
            isBool: Bool?
        }

        analytics.identify(userId: "me@work.com", traits: MyTraits(email: "me@work.com", isBool: true))

        while outputReader.events.count < 1 {
            RunLoop.main.run(until: Date.distantPast)
        }

        let identifyEvent = outputReader.events[0] as? IdentifyEvent

        let actualType = type(of: identifyEvent?.traits?["isBool"])
        print("Actual type of 'isBool' is \(actualType)") // Optional<JSON>
    }
}
