// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//



#if DEPLOYMENT_RUNTIME_OBJC || os(Linux)
    import Foundation
    import XCTest
#else
    import SwiftFoundation
    import SwiftXCTest
#endif

class TestNSExpression: XCTestCase {
    
    static var allTests: [(String, (TestNSExpression) -> () throws -> Void)] {
        return [
            //("test_keyPathExpression", test_keyPathExpression),
            //("test_ConditionalExpression", test_ConditionalExpression),
            //("test_SubqueryExpression", test_SubqueryExpression),
            ("test_ConstantExpression", test_ConstantExpression),
            ("test_SelfExpression", test_SelfExpression),
            ("test_VariableExpression", test_VariableExpression),
            ("test_FunctionExpression", test_FunctionExpression),
            ("test_AggregateExpression", test_AggregateExpression),
            ("test_SetExpresssion", test_SetExpresssion),
            ("test_blockExpression", test_blockExpression)
        ]
    }

    override func setUp() {

        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {

        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func test_ConstantExpression() {
        let exp = NSExpression(forConstantValue: NSString(string:"a"))
        XCTAssertEqual(exp.expressionValue(with:nil, context: nil) as? NSString , NSString(string:"a"))
        XCTAssertEqual(exp.expressionValue(with:NSString(string:"o"), context: nil) as? NSString, NSString(string:"a"))

        let exp2 = NSExpression(forConstantValue: nil)
        XCTAssertNil(exp2.expressionValue(with:nil, context: nil))
        XCTAssertEqual(exp.description, "'a'", "Expected 'a', got \(exp.description)")
    }

    func test_SelfExpression() {
        let exp = NSExpression.expressionForEvaluatedObject()
        XCTAssertNil(exp.expressionValue(with:nil, context: nil))
        XCTAssertEqual(exp.expressionValue(with:NSString(string:"o"), context: nil) as? NSString, NSString(string:"o"))
        XCTAssertEqual(exp.expressionValue(with:1 as NSNumber, context: nil) as? NSNumber, 1 as NSNumber)
        XCTAssertEqual(exp.description, "SELF", "Expected SELF")
    }

    func test_keyPathExpression() {
        let value = NSString(string:"VALUE")
        let obj = NSDictionary(object: value, forKey: NSString(string:"prop"))

        let exp = NSExpression(forKeyPath: "prop")
        XCTAssertEqual(exp.expressionValue(with:obj, context: nil) as? NSString, value)
        XCTAssertNil(exp.expressionValue(with:nil, context: nil))
        XCTAssertEqual(exp.description, "Expected .prop, got \(exp.description)")
    }

    func test_VariableExpression() {
        let bindings = [NSString(string:"variable"):NSExpression(forConstantValue:NSString(string:"c"))] as NSMutableDictionary

        let exp = NSExpression(forVariable: "variable")
        XCTAssertEqual(exp.expressionValue(with:nil, context: bindings) as? NSString, NSString(string:"c"))
        XCTAssertEqual(exp.description, "$variable", "Expected $variable, got \(exp.description)")
    }

    func test_FunctionExpression() {
        let exp = NSExpression(forFunction: "sum:", arguments: [NSExpression(forConstantValue:1 as NSNumber), NSExpression(forConstantValue:2 as NSNumber)])
        let result = exp?.expressionValue(with:nil, context: nil) as? NSNumber
        XCTAssertEqual(result, 3 as NSNumber, "Result should be 3, was \(result)")
        XCTAssertEqual(exp?.description, "sum:(1, 2)", "Expected sum:(1, 2) was \(exp?.description)")

        let exp2 = NSExpression(forFunction: "sum:", arguments: [NSExpression(forConstantValue:NSString(string:"s"))])
        XCTAssertNil(exp2?.expressionValue(with:nil, context: nil), "Wrong arguments type, expression result should be nil")

        let exp3 = NSExpression(forFunction: "sum", arguments:[NSExpression(forConstantValue:1 as NSNumber)])
        XCTAssertNil(exp3, "Wrong function name, expression result should be nil")
    }

    func test_AggregateExpression() {
        let exp = NSExpression(forAggregate: [NSExpression(forConstantValue:1 as NSNumber), NSExpression(forConstantValue:NSString(string:"c"))])
        XCTAssertEqual(exp.expressionValue(with:nil, context: nil) as? NSArray , NSArray(array:[1 as NSNumber, NSString(string:"c")]))
        XCTAssertEqual(exp.description, "{1, 'c'}", "Expected {1, 'c'} was \(exp.description)")
    }

    func test_SetExpresssion() {
        let left:NSSet = NSSet(set:[1 as NSNumber,2 as NSNumber]),
            right:NSSet = NSSet(set:[2 as NSNumber,3 as NSNumber])

        let exp_intersect = NSExpression(forIntersectSet: NSExpression(forConstantValue:left), with: NSExpression(forConstantValue:right))
print(exp_intersect.expressionValue(with:nil, context: nil))
  /*      XCTAssertEqual(exp_intersect.expressionValue(with:nil, context: nil) as! NSSet , NSSet(set:[2 as NSNumber]))
        XCTAssertEqual(exp_intersect.description, "\(left.description) INTERSECT \(right.description)", "Expects \(left.description) ,was \(exp_intersect.description)")

        let exp_minus = NSExpression(forMinusSet: NSExpression(forConstantValue:left), with: NSExpression(forConstantValue:right))
        XCTAssertEqual(exp_minus.expressionValue(with:nil, context: nil) as! NSSet , NSSet(set:[1 as NSNumber]))
        XCTAssertEqual(exp_minus.description, "\(left.description) MINUS \(right.description)")

        let exp_union = NSExpression(forUnionSet: NSExpression(forConstantValue:left), with: NSExpression(forConstantValue:right))
        XCTAssertEqual(exp_union.expressionValue(with:nil, context: nil) as! NSSet , NSSet(set:[1,2,3]))
        XCTAssertEqual(exp_union.description, "\(left.description) UNION \(right.description)")*/
    }

    func test_blockExpression() {
        let obj = NSString(string:"o")
        let exp = NSExpression(forBlock: {obj,_,_ in return obj}, arguments: nil)
        XCTAssertEqual(exp.expressionValue(with:obj, context: nil) as? NSString, obj)

        let exp_with_args = NSExpression(forBlock: {_,args,_ in return args[0]}, arguments: [NSExpression(forConstantValue:1 as NSNumber), NSExpression(forConstantValue:NSString(string:"c"))])
        XCTAssertEqual(exp_with_args.expressionValue(with:nil, context: nil) as? NSNumber, 1 as NSNumber)

        let bindings = [NSString(string:"variable"):NSExpression(forConstantValue:obj)] as NSMutableDictionary
        let exp_with_args_and_bindings = NSExpression(forBlock: {_,args,_ in return args[0]}, arguments: [NSExpression(forVariable:"variable")])
        XCTAssertEqual(exp_with_args_and_bindings.expressionValue(with:nil, context: bindings) as? NSString, obj)
    }

    func test_ConditionalExpression() {
        let t = NSString(string: "true")
        let f = NSString(string: "false")
        let bindings = [NSString(string:"variable1"):NSExpression(forConstantValue:t),
                        NSString(string:"variable2"):NSExpression(forConstantValue:f)] as NSMutableDictionary
        let p = NSPredicate(value: true)

        let exp = NSExpression(forConditional: p, trueExpression: NSExpression(forVariable:"variable1") , falseExpression: NSExpression(forVariable:"variable2"))
        XCTAssertEqual(exp.expressionValue(with:nil, context: bindings) as? NSString, NSString(string: "true"))
        XCTAssertEqual(exp.description, "TERNARY(TRUEPREDICATE, $variable1, $variable2)")
    }

    func test_SubqueryExpression() {
        let object:Dictionary<String,Dictionary<String,Any>> =
            ["Record1":
                      ["Name":"John", "Age":34 as NSNumber, "Children":
                                                                      ["Kid1", "Kid2"]],
             "Record2":
                      ["Name":"Mary", "Age":30 as NSNumber, "Children":
                                                                      ["Kid1", "Girl1"]]]

        let collection = NSExpression(forKeyPath: "Record1.Children")
        let predicate = NSComparisonPredicate(leftExpression: NSExpression(forVariable:"x"), rightExpression: NSExpression(forVariable:"KidVariable"), modifier: .direct, type: .beginsWith, options: .caseInsensitive)
        let bindings = NSMutableDictionary(object: NSExpression(forConstantValue:NSString(string:"Kid")), forKey: NSString(string:"KidVariable"))
        let exp = NSExpression(forSubquery: collection, usingIteratorVariable: "x", predicate: predicate)
        let eval = exp.expressionValue(with:object, context: bindings)
        let expected = NSArray(array:["Kid1", "Kid2"])
        XCTAssertEqual(eval as? NSArray, expected, "\(exp.description) : result is \(eval), should be \(expected)")
    }
}
