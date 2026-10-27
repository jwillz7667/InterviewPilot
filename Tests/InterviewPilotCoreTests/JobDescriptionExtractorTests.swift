import Foundation
import XCTest
@testable import InterviewPilotCore

final class JobDescriptionExtractorTests: XCTestCase {
    private let source = URL(string: "https://careers.acme.com/jobs/42")!
    private let fixtureDescription = """
    Responsibilities
    Build and maintain reliable software used by customers every day. Work with product managers and designers to understand requirements, review code, improve automated testing, investigate production issues, and document technical decisions.
    Qualifications
    Experience with Swift or another modern programming language, clear communication skills, curiosity, and the ability to collaborate with a team. Benefits include paid time off, training, and flexible working hours.
    """

    func testJSONLDGraphPrefersActualPostingAndDecodesDescription() throws {
        let posting: [String: Any] = [
            "@context": "https://schema.org",
            "@graph": [
                ["@type": "Organization", "name": "Unrelated navigation"],
                [
                    "@type": ["Thing", "JobPosting"],
                    "title": "Software Engineer &amp; Mentor",
                    "hiringOrganization": ["name": "Acme &amp; Co"],
                    "description": "<h2>Responsibilities</h2><p>\(fixtureDescription)</p><ul><li>R&amp;D projects</li></ul>"
                ]
            ]
        ]
        let json = String(decoding: try JSONSerialization.data(withJSONObject: posting), as: UTF8.self)
        let html = "<html><title>Careers portal</title><script data-test='x' type='application/ld+json'>\(json)</script><nav>Ignore me</nav></html>"
        let result = try JobDescriptionExtractor.extract(html: html, sourceURL: source)
        XCTAssertEqual(result.title, "Software Engineer & Mentor")
        XCTAssertEqual(result.company, "Acme & Co")
        XCTAssertTrue(result.text.contains("R&D projects"))
        XCTAssertFalse(result.text.contains("Ignore me"))
        XCTAssertEqual(result.url, source)
    }

    func testJSONLDTopLevelArrayAndMalformedBlockFallback() throws {
        let json: [[String: Any]] = [
            ["@type": "BreadcrumbList"],
            ["@type": "https://schema.org/JobPosting", "title": "Developer", "description": fixtureDescription]
        ]
        let body = String(decoding: try JSONSerialization.data(withJSONObject: json), as: UTF8.self)
        let html = "<script type=\"application/ld+json\">broken json</script><script type=\"application/ld+json\">\(body)</script>"
        let result = try JobDescriptionExtractor.extract(html: html, sourceURL: source)
        XCTAssertEqual(result.title, "Developer")
        XCTAssertEqual(result.company, "")
        XCTAssertTrue(result.text.contains("Qualifications"))
    }

    func testSemanticHTMLRemovesNavigationAndScripts() throws {
        let html = """
        <html><head><title>Acme Careers</title><style>.fake { content: "wrong"; }</style></head>
        <body><nav>Home Products Contact</nav><main><h1>Senior Engineer</h1>
        <p>\(fixtureDescription)</p><script>steal("SECRET SCRIPT");</script>
        <div aria-hidden="true">HIDDEN ADVERTISEMENT</div>
        <ul><li>Salary: &#36;100,000 &ndash; &#x24;130,000</li></ul></main>
        <footer>Legal newsletter unrelated jobs</footer></body></html>
        """
        let result = try JobDescriptionExtractor.extract(html: html, sourceURL: source)
        XCTAssertEqual(result.title, "Senior Engineer")
        XCTAssertTrue(result.text.contains("$100,000 – $130,000"))
        XCTAssertFalse(result.text.contains("SECRET SCRIPT"))
        XCTAssertFalse(result.text.contains("ADVERTISEMENT"))
        XCTAssertFalse(result.text.contains("Home Products"))
        XCTAssertFalse(result.text.contains("newsletter"))
    }

    func testEntitiesPreserveUnicodeAndUnknownEntities() {
        let text = JobDescriptionExtractor.decodeEntities("R&amp;D &#169; &#x1F680; &nbsp;&quot;résumé&quot; &unknown; &#0;")
        XCTAssertEqual(text, "R&D © 🚀  \"résumé\" &unknown; &#0;")
    }

    func testBlockedAndSignInPagesDoNotBecomeContext() {
        for html in [
            "<html><title>Just a moment...</title><body>Verify you are human. \(fixtureDescription)</body></html>",
            "<html><title>Sign in to LinkedIn</title><body>\(fixtureDescription)</body></html>",
            "<html><title>Careers</title><body>Please enable JavaScript to continue. \(fixtureDescription)</body></html>"
        ] {
            XCTAssertThrowsError(try JobDescriptionExtractor.extract(html: html, sourceURL: source)) {
                XCTAssertEqual($0 as? JobDescriptionImportError, .blockedPage)
            }
        }
    }

    func testShortDescriptionOrGenericMarketingPageRejected() throws {
        XCTAssertThrowsError(try JobDescriptionExtractor.extract(html: "<h1>Developer</h1><p>Apply now</p>", sourceURL: source)) {
            XCTAssertEqual($0 as? JobDescriptionImportError, .insufficientContent)
        }
        let generic = String(repeating: "Welcome to our website where we make wonderful things for people around the world. ", count: 10)
        XCTAssertThrowsError(try JobDescriptionExtractor.extract(html: "<main>\(generic)</main>", sourceURL: source))
        let briefJSON = #"<script type="application/ld+json">{"@type":"JobPosting","title":"Developer","description":"Apply now"}</script>"#
        XCTAssertThrowsError(try JobDescriptionExtractor.extract(html: briefJSON, sourceURL: source))
    }

    func testOversizedPageRejectedBeforeParsing() {
        XCTAssertThrowsError(try JobDescriptionExtractor.extract(
            html: String(repeating: "x", count: JobDescriptionExtractor.maximumPageBytes + 1), sourceURL: source
        )) {
            XCTAssertEqual($0 as? JobDescriptionImportError, .tooLarge)
        }
    }

    func testURLValidationNormalizesAndRemovesFragments() throws {
        let result = try JobDescriptionExtractor.validatedURL(from: "  HTTPS://Careers.Acme.com/jobs/42?ref=job#apply \n")
        XCTAssertEqual(result.absoluteString, "https://careers.acme.com/jobs/42?ref=job")
        XCTAssertNoThrow(try JobDescriptionExtractor.validatedURL(from: "http://careers.acme.com/jobs/42"))
    }

    func testUnsafeSchemesCredentialsPortsAndLocalAddressesRejected() {
        let rejected = [
            "file:///etc/passwd", "data:text/html,hello", "javascript:alert(1)",
            "https://user:pass@careers.acme.com/jobs", "https://careers.acme.com:8443/jobs",
            "http://localhost/jobs", "http://localhost./jobs", "http://127.0.0.1",
            "http://10.0.0.1/jobs", "http://192.168.0.1/jobs", "http://169.254.169.254/",
            "http://[::1]/", "http://[fd00::1]/", "http://2130706433/", "http://0x7f000001/",
            "http://0177.0.0.1/", "https://printer.local/", "https://server.internal/",
            "https://metadata.google.internal/", "https://private.lan/", "https://intranet/",
            "https://careers..acme.com/", "", "not a URL", "careers.acme.com/jobs"
        ]
        for url in rejected {
            XCTAssertThrowsError(try JobDescriptionExtractor.validatedURL(from: url), "Accepted unsafe URL: \(url)")
        }
    }

    func testUserFacingFailuresAlwaysOfferUsefulNextStep() {
        XCTAssertTrue(JobDescriptionImportError.blockedPage.localizedDescription.contains("paste"))
        XCTAssertTrue(JobDescriptionImportError.insufficientContent.localizedDescription.contains("paste"))
        XCTAssertTrue(JobDescriptionImportError.timedOut.localizedDescription.contains("15 seconds"))
    }
}

