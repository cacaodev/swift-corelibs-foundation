// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


// Expressions are the core of the predicate implementation. When expressionValueWithObject: is called, the expression is evaluated, and a value returned which can then be handled by an operator. Expressions can be anything from constants to method invocations. Scalars should be wrapped in appropriate NSValue classes.
extension NSExpression {
    public enum ExpressionType : UInt {
        
        case constantValue // Expression that always returns the same value
        case evaluatedObject // Expression that always returns the parameter object itself
        case variable // Expression that always returns whatever is stored at 'variable' in the bindings dictionary
        case keyPath // Expression that returns something that can be used as a key path
        case function // Expression that returns the result of evaluating a symbol
        case unionSet // Expression that returns the result of doing a unionSet: on two expressions that evaluate to flat collections (arrays or sets)
        case intersectSet // Expression that returns the result of doing an intersectSet: on two expressions that evaluate to flat collections (arrays or sets)
        case minusSet // Expression that returns the result of doing a minusSet: on two expressions that evaluate to flat collections (arrays or sets)
        case subquery
        case aggregate
        case anyKey
        case block
        case conditional
    }
}

open class NSExpression : NSObject, NSSecureCoding, NSCopying {
    static var _expressionForEvaluatedObject = {
        NSExpression(expressionType:.evaluatedObject, evaluation:{o,_ in return o})
    }()
    
    public typealias ExpressionBlockType = (Any?, [Any], NSMutableDictionary?) -> Any?
    internal typealias EvaluateBlockType = (Any?, NSMutableDictionary?) -> Any?
    internal typealias SubstituteBlockType = (NSMutableDictionary) -> NSExpression
    
    internal var _evaluationBlock:EvaluateBlockType
    internal var _substitutionVariablesBlock:SubstituteBlockType?
    internal var _constantValue:AnyObject?
    internal var _keyPath: String?
    internal var _function: String?
    internal var _variable: String?
    internal var _operand: NSExpression?
    internal var _arguments: [NSExpression]?
    internal var _collection: [NSExpression]?
    internal var _predicate: NSPredicate?
    internal var _leftExpression: NSExpression?
    internal var _rightExpression: NSExpression?
    internal var _trueExpression: NSExpression?
    internal var _falseExpression: NSExpression?
    internal var _expressionBlock: ExpressionBlockType?

    public var expressionType:ExpressionType

    public static var supportsSecureCoding: Bool {
        return true
    }
    
    public required init?(coder aDecoder: NSCoder) {
        NSUnimplemented()
    }
    
    open func encode(with aCoder: NSCoder) {
        NSUnimplemented()
    }
    
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    open func copy(with zone: NSZone? = nil) -> Any {
        NSUnimplemented()
    }

    public /*not inherited*/ init(format expressionFormat: String, argumentArray arguments: [Any]) { NSUnimplemented() }
    public /*not inherited*/ init(format expressionFormat: String, arguments argList: CVaListPointer) { NSUnimplemented() }
    
    internal init(expressionType type:ExpressionType, evaluation:@escaping EvaluateBlockType, substitution:SubstituteBlockType?=nil) {
        expressionType = type
        _evaluationBlock = evaluation
        _substitutionVariablesBlock = substitution

        super.init()
    }

    public /*not inherited*/ init(forConstantValue value: AnyObject?) {
        self.init(type:.constantValueExpressionType, evaluation:{_,_ in return value})

        _constantValue = value
    } // Expression that returns a constant value


    open class func expressionForEvaluatedObject() -> NSExpression {
        return NSExpression._expressionForEvaluatedObject
    } // Expression that returns the object being evaluated

    public /*not inherited*/ init(forVariable string: String) {
        let evaluationBlock:EvaluateBlockType = {obj,bindings in
            guard let exp = bindings?.object(forKey: aVariable) as? NSExpression else {
                preconditionFailure("Cannot find variable \(aVariable) in \(bindings)")
            }

            return exp.expressionValue(with:obj, context: bindings)
        }

        let substitutionVariablesBlock:SubstituteBlockType = {bindings in
            guard let exp = bindings.object(forKey: aVariable) as? NSExpression else {
                preconditionFailure("Cannot find variable in \(bindings)")
            }

            return exp
        }

        self.init(expressionType:.variable, evaluation:evaluationBlock, substitution:substitutionVariablesBlock)

        self._variable = aVariable
    } // Expression that pulls a value from the variable bindings dictionary

    public /*not inherited*/ init(forKeyPath keyPath: String) {
        let evaluationBlock:EvaluateBlockType = {obj,_ in
            // TODO: Change NSObjectProtocol to whatever protocol -valueForKeyPath() belongs to.
            guard let keyValueObject = obj , keyValueObject is NSObjectProtocol else {
                return nil
            }

            // TODO: depends on NSObject -valueForKeyPath implementation
            //return o.valueForKeyPath(keyPath)
            NSUnimplemented()
        }

        self.init(expressionType:.keyPath, evaluation:evaluationBlock, substitution:nil)

        _keyPath = keyPath

    } // Expression that invokes valueForKeyPath with keyPath

    public /*not inherited*/ init(forFunction name: String, arguments parameters: [Any]) {

        guard let fn = _NSExpressionFunctions[name] else {
            // TODO: failable init. Decide if we should throw instead. (Apple Foundation throws an Exception)
            print("\(name) is not a supported method")
            return nil
        }

        let evaluationBlock:EvaluateBlockType = {obj, bindings in
            var result:AnyObject?
            let args = parameters.expressionValue(with:obj, context: bindings)

            do {
                 result = try _invokeFunction(fn, with:args)
            } catch let NSExpressionError.invalidArgumentType(expected: type){
                // TODO: Decide if we should throw instead. (Apple Foundation throws an Exception)
                print("InvalidArgumentType \(type(of: args)), function \(name) expects \(type)")
                result = nil
            } catch {

            }

            return result
        }

        let substitutionVariablesBlock:SubstituteBlockType = {bindings in
            let subst = parameters.map{$0.expressionWithSubstitutionVariables(bindings)}

            return NSExpression(forFunction: name, arguments: subst)!
        }

        self.init(expressionType:.function, evaluation:evaluationBlock, substitution:substitutionVariablesBlock)

        _function = name
        _arguments = parameters

    } // Expression that invokes one of the predefined functions. Will throw immediately if the selector is bad; will throw at runtime if the parameters are incorrect.
    // Predefined functions are:
    // name              parameter array contents				returns
    //-------------------------------------------------------------------------------------------------------------------------------------
    // sum:              NSExpression instances representing numbers		NSNumber 
    // count:            NSExpression instances representing numbers		NSNumber 
    // min:              NSExpression instances representing numbers		NSNumber  
    // max:              NSExpression instances representing numbers		NSNumber
    // average:          NSExpression instances representing numbers		NSNumber
    // median:           NSExpression instances representing numbers		NSNumber
    // mode:             NSExpression instances representing numbers		NSArray	    (returned array will contain all occurrences of the mode)
    // stddev:           NSExpression instances representing numbers		NSNumber
    // add:to:           NSExpression instances representing numbers		NSNumber
    // from:subtract:    two NSExpression instances representing numbers	NSNumber
    // multiply:by:      two NSExpression instances representing numbers	NSNumber
    // divide:by:        two NSExpression instances representing numbers	NSNumber
    // modulus:by:       two NSExpression instances representing numbers	NSNumber
    // sqrt:             one NSExpression instance representing numbers		NSNumber
    // log:              one NSExpression instance representing a number	NSNumber
    // ln:               one NSExpression instance representing a number	NSNumber
    // raise:toPower:    one NSExpression instance representing a number	NSNumber
    // exp:              one NSExpression instance representing a number	NSNumber
    // floor:            one NSExpression instance representing a number	NSNumber
    // ceiling:          one NSExpression instance representing a number	NSNumber
    // abs:              one NSExpression instance representing a number	NSNumber
    // trunc:            one NSExpression instance representing a number	NSNumber
    // uppercase:	 one NSExpression instance representing a string	NSString
    // lowercase:	 one NSExpression instance representing a string	NSString
    // random            none							NSNumber (integer) 
    // randomn:          one NSExpression instance representing a number	NSNumber (integer) such that 0 <= rand < param
    // now               none							[NSDate now]
    // bitwiseAnd:with:	 two NSExpression instances representing numbers	NSNumber    (numbers will be treated as NSInteger)
    // bitwiseOr:with:	 two NSExpression instances representing numbers	NSNumber    (numbers will be treated as NSInteger)
    // bitwiseXor:with:	 two NSExpression instances representing numbers	NSNumber    (numbers will be treated as NSInteger)
    // leftshift:by:	 two NSExpression instances representing numbers	NSNumber    (numbers will be treated as NSInteger)
    // rightshift:by:	 two NSExpression instances representing numbers	NSNumber    (numbers will be treated as NSInteger)
    // onesComplement:	 one NSExpression instance representing a numbers	NSNumber    (numbers will be treated as NSInteger)
    // noindex:		 an NSExpression					parameter   (used by CoreData to indicate that an index should be dropped)
    // distanceToLocation:fromLocation:
    //                   two NSExpression instances representing CLLocations    NSNumber
    // length:           an NSExpression instance representing a string         NSNumber
    
    public /*not inherited*/ init(forAggregate subexpressions: [Any]) {
        let evaluationBlock:EvaluateBlockType = {object, bindings in
            return subexpressions.expressionValue(with:object, context: bindings)
        }

        let substitutionVariablesBlock:SubstituteBlockType = {bindings in
            let subst = subexpressions.map{$0.expressionWithSubstitutionVariables(bindings)}
            return NSExpression(forAggregate: subst)
        }

        self.init(expressionType:.aggregate, evaluation:evaluationBlock, substitution:substitutionVariablesBlock)

        _collection = subexpressions
    } // Expression that returns a collection containing the results of other expressions

    internal typealias SetFunctionType = (Set<NSObject>) -> (Set<NSObject>) -> Set<NSObject>

    internal convenience init(forSet type: ExpressionType, left: NSExpression, with right: NSExpression, operation:String) {
        let evaluationBlock:EvaluateBlockType = {obj,bindings in

            guard let left_set = left.expressionValue(with:obj, context: bindings) else {
                return nil
            }

            guard let right_set = right.expressionValue(with:obj, context: bindings) else {
                // TODO: convert NSOrderedSet, NSDictionary, NSArray to (NS)Set
                return nil
            }

            guard left_set is NSSet else {
                return nil
            }

            guard right_set is NSSet else {
                return nil
            }

            let ml_set:NSMutableSet = (left_set as! NSSet).mutableCopy() as! NSMutableSet
            let mr_set:Set = (right_set as! NSSet)._bridgeToSwift()

            switch type {
            case .unionSet:
                return ml_set.union(mr_set)
            case .intersectSet:
                return ml_set.intersect(mr_set)
            case .minusSet:
                return ml_set.minus(mr_set)
            default:
                return NSSet()
            }
        }

        let substitutionVariablesBlock:SubstituteBlockType = {bindings in
            let l = left.expressionWithSubstitutionVariables(bindings),
                r = right.expressionWithSubstitutionVariables(bindings)

            return NSExpression(forSet: type, left: l, with: r, operation: operation)
        }

        self.init(expressionType:type, evaluation:evaluationBlock, substitution:substitutionVariablesBlock)

        _leftExpression = left
        _rightExpression = right
    }

    public convenience init(forUnionSet left: NSExpression, with right: NSExpression) {
        self.init(forSet:.unionSet, left:left, with:right, operation:"UNION")
    } // return an expression that will return the union of the collections expressed by left and right
    public convenience init(forIntersectSet left: NSExpression, with right: NSExpression) {
        self.init(forSet:.intersectSet, left:left, with:right, operation:"INTERSECT")
    } // return an expression that will return the intersection of the collections expressed by left and right
    public convenience init(forMinusSet left: NSExpression, with right: NSExpression) {
        self.init(forSet:.minusSet, left:left, with:right, operation:"MINUS")
    } // return an expression that will return the disjunction of the collections expressed by left and right

    // TODO: Subquery expression depends on NSPredicate implementation
    public /*not inherited*/ init(forSubquery expression: NSExpression, usingIteratorVariable variable: String, predicate: Any) {
        let evaluationBlock:EvaluateBlockType = {object, context in
            guard let collection = expression.expressionValue(with:object, context: context) as? Array<AnyObject> else {
                return nil
            }

            var substitutionVariables : Dictionary<String, Any>

            if let ns_substitutionVariables = context {
                ns_substitutionVariables.setObject(NSExpression._expressionForEvaluatedObject, forKey: variable._nsObject)
                substitutionVariables = ns_substitutionVariables._swiftObject as! [String : Any]
             }else {
                substitutionVariables = [variable : NSExpression._expressionForEvaluatedObject]
            }

            let result = collection.filter{predicate.evaluate(with:$0, substitutionVariables:substitutionVariables)}

            return result._nsObject
        }

        let substitutionVariablesBlock:SubstituteBlockType = {bindings in
            let exp = expression.expressionWithSubstitutionVariables(bindings)
            let p = predicate.withSubstitutionVariables(bindings._swiftObject as! [String : Any])

            return NSExpression(forSubquery: exp, usingIteratorVariable: variable, predicate: p)
        }

        self.init(expressionType:.subquery, evaluation:evaluationBlock, substitution:substitutionVariablesBlock)

        _variable = variable
        _predicate = predicate
        _collection = [expression]
    } // Expression that filters a collection by storing elements in the collection in the variable variable and keeping the elements for which qualifer returns true; variable is used as a local variable, and will shadow any instances of variable in the bindings dictionary, the variable is removed or the old value replaced once evaluation completes
    public /*not inherited*/ init(forFunction target: NSExpression, selectorName name: String, arguments parameters: [Any]?) {
        NSUnimplemented()
    } // Expression that invokes the selector on target with parameters. Will throw at runtime if target does not implement selector or if parameters are wrong.
    open class func expressionForAnyKey() -> NSExpression { NSUnimplemented() }
    
    public convenience init(forBlock block: @escaping (Any?, [Any], NSMutableDictionary?) -> Any, arguments: [NSExpression]?) {
        let evaluationBlock:EvaluateBlockType = {object, context in
            let args = arguments?.expressionValue(with:object, context: context) ?? []
            return block(object, args, context)
        }
    
        let substitutionVariablesBlock:SubstituteBlockType = {bindings in
            let subst = arguments?.map{$0.expressionWithSubstitutionVariables(bindings)}
            return NSExpression(forBlock:block, arguments:subst)
        }
    
        self.init(expressionType:.block, evaluation:evaluationBlock, substitution:substitutionVariablesBlock)
    
        _expressionBlock = block
        _arguments = arguments
    } // Expression that invokes the block with the parameters; note that block expressions are not encodable or representable as parseable strings.
    
    // TODO: Conditional Expression depends on NSPredicate implementation
    public /*not inherited*/ init(forConditional predicate: Any, trueExpression: NSExpression, falseExpression: NSExpression) {
        let evaluationBlock:EvaluateBlockType = {object, context in
            let eval:Bool = predicate.evaluate(with:object, substitutionVariables: context?._swiftObject as! [String : Any]?)
            let exp = eval ? trueExpression : falseExpression
            return exp.expressionValue(with:object, context: context)
        }
    
        let substitutionVariablesBlock:SubstituteBlockType = {bindings in
            let p = predicate.withSubstitutionVariables(bindings._swiftObject as! [String : Any]),
                te = trueExpression.expressionWithSubstitutionVariables(bindings),
                fe = falseExpression.expressionWithSubstitutionVariables(bindings)

            return NSExpression(forConditional: p, trueExpression: te, falseExpression: fe)
        }

        self.init(expressionType:.conditional, evaluation:evaluationBlock, substitution:substitutionVariablesBlock)

        _trueExpression = trueExpression
        _falseExpression = falseExpression
        _predicate = predicate
    } // Expression that will return the result of trueExpression or falseExpression depending on the value of predicate

    public init(expressionType type: ExpressionType) { NSUnimplemented() }

    open var expressionType:ExpressionType

    open var constantValue: Any? {
        guard self.expressionType == .constantValue else {
            preconditionFailure()
        }

        return self._constantValue
    }

    open var keyPath: String {
        guard expressionType == .keyPath else {
            preconditionFailure()
        }

        return _keyPath!
    }

    open var function: String {
        guard expressionType == .function else {
            preconditionFailure()
        }

        return self._function!
    }

    open var variable: String {
        guard expressionType == .variable else {
            preconditionFailure()
        }

        return self._variable!
    }

    open var operand: NSExpression? {
        NSUnimplemented()
    }
    // the object on which the selector will be invoked (the result of evaluating a key path or one of the defined functions)

    open var arguments: [NSExpression] {
        guard expressionType == .function || expressionType == .block else {
            preconditionFailure()
        }

        // BlockExpressionType accepts nil arguments, we return an empty array in this case.
        guard let args = self._arguments else {
            return []
        }

        return args
    } // array of expressions which will be passed as parameters during invocation of the selector on the operand of a function expression

    open var collection: [NSExpression] {
        guard expressionType == .aggregate else {
            preconditionFailure()
        }

        return self._collection!
    }

    open var predicate: NSPredicate {
        guard expressionType == .subquery || expressionType == .conditional else {
            preconditionFailure()
        }

        return self._predicate!
    }

    open var left: NSExpression {
        guard expressionType == .intersectSet || expressionType == .minusSet || expressionType == .unionSet else {
            preconditionFailure()
        }

        return self._leftExpression!
    }// expression which represents the left side of a set expression

    open var right: NSExpression {
        guard expressionType == .intersectSet || expressionType == .minusSet || expressionType == .unionSet else {
            preconditionFailure()
        }

        return self._rightExpression!
    }// expression which represents the right side of a set expression

    open var `true`: NSExpression? {
        guard expressionType == .conditional else {
            preconditionFailure()
        }

        return self._trueExpression
    }// expression which will be evaluated if a conditional expression's predicate evaluates to true

    open var `false`: NSExpression? {
        guard expressionType == .conditional else {
            preconditionFailure()
        }

        return self._falseExpression
    }// expression which will be evaluated if a conditional expression's predicate evaluates to false

    public var expressionBlock: ExpressionBlockType {
        guard expressionType == .block else {
            preconditionFailure()
        }

        return self._expressionBlock!
    }

    // evaluate the expression using the object and bindings- note that context is mutable here and can be used by expressions to store temporary state for one predicate evaluation
    open func expressionValue(with object: Any?, context: NSMutableDictionary?) -> Any? {
        return self._evaluationBlock(object, context)
    }
    
    open func allowEvaluation() { NSUnimplemented() } // Force an expression which was securely decoded to allow evaluation

    override open var description: String {
        return self.predicateFormat
}

    // Used by NSPredicate -predicateWithSubstitutionVariables
    private func expressionWithSubstitutionVariables(_ bindings:NSMutableDictionary?) -> NSExpression {
        // nil bindings -> crash ?
        guard let b = bindings, let block = self._substitutionVariablesBlock else {
            return self
        }

        return block(b)
    }

    internal var predicateFormat:String {
        switch expressionType {
        case .constantValue :
            if let string = self.constantValue as? NSString {
                return "'\(string)'"
            } else if let convertible = self.constantValue as? CustomStringConvertible{
                return "\(convertible.description)"
            } else if let non_nil = self.constantValue {
                return "\(non_nil)"
            } else {
                return "nil"
            }
        case .evaluatedObject : return "SELF"
        case .variable : return "$\(self.variable)"
        case .keyPath : return ".\(self.keyPath)"
        case .function : return "\(self.function)(\(self.arguments.predicateFormat))"
        case .intersectSet : return "\(self.left) INTERSECT \(self.right)"
        case .minusSet : return "\(self.left.predicateFormat) MINUS \(self.right.predicateFormat)"
        case .unionSet : return "\(self.left) UNION \(self.right)"
        case .subquery : return "SUBQUERY(\(self.collection.first), \(self.variable), \(self.predicate))"
        case .aggregate : return "{\(self.collection.predicateFormat)}"
        case .block : return "BLOCK(\(self.expressionBlock), \(self.arguments.predicateFormat))"
        case .conditional : return "TERNARY(\(self.predicate), \(self.true), \(self.false))"
        case .anyKey : return "UNIMPLEMENTED"
        }
    }
}

extension NSExpression {
    public convenience init(format expressionFormat: String, _ args: CVarArg...) { NSUnimplemented() }
}

internal extension Array where Element:NSExpression {
    internal func expressionValue(with object: Any?, context: NSMutableDictionary?) -> [Any] {
        return self.map{e in
            return e.expressionValue(with:object, context: context) ?? NSNull()
        }
    }

    internal var predicateFormat:String {
        return self.map{($0 as NSExpression).description}.joined(separator: ", ")
    }
}


//MARK - Predefined functions and function utilities
// TODO: implement all pre-defined functions which can have to following types :
//([NSNumber]) -> NSNumber
//(NSNumber) -> NSNumber
//(NSNumber) -> NSString
//(NSString) -> NSString
//() -> NSDate
//() -> NSNumber
//([CLLocation]) -> NSNumber

internal enum NSExpressionError : Error {
    case invalidArgumentType(expected:Any)
}

internal func _invokeFunction<T ,U, V>(_ function:(Array<T>) -> U, with arguments:Array<V>) throws -> U? {
    guard let args = arguments.map({ $0 as? T }) as? Array<T> else {
        throw NSExpressionError.invalidArgumentType(expected:Array<T>.self)
    }

    return function(args)
}

internal typealias NSExpressionFunctionType = ([NSNumber]) -> AnyObject
internal let _NSExpressionFunctions:[String:NSExpressionFunctionType] = [
    "sum:":sum,
    "now":now]

internal func sum(_ args:[NSNumber]) -> NSNumber {
    return args.reduce(0, {NSNumber(value:$0.doubleValue + $1.doubleValue)}) as NSNumber
}

internal func now(_:[NSNumber]) -> NSDate {
    return NSDate()
}
