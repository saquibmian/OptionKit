
import Cocoa

public struct Options {
    public let extracted: [String:[String]]
    public let trailers: [String]
}

public protocol OptionExtractorType {
    func extractOptions(args: [String]) throws -> Options
}

public enum ExtractorError : ErrorType, CustomStringConvertible {
    case UnexpectedOption(option: String)
    case UnexpectedOperation(operation: String)
    case AmbiguousOption(option: String)
    
    public var description: String {
        switch(self){
        case .UnexpectedOperation(let operation):
            return "Unexpected operation found \(operation)"
        case .UnexpectedOption(let option):
            return "Unexpected option found \(option)"
        case .AmbiguousOption(let option):
            return "Ambiguous usage of option \(option)"
        }
    }
}

public struct OptionExtractor : OptionExtractorType {
    
    private enum OptionType : Hashable {
        case Flag
        case Value
    }
    
    private enum State {
        case JustStartedParsing
        case InTheMiddleOfParsing
        case ParsingDisabled
        case ParsingImplicitlyDisabled
        case Done
    }
    
    public func extractOptions(args: [String]) throws -> Options {
        var extracted = [String : [String]]()
        var trailers = [String]()
        
        var parsedOptions = [String:OptionType]()
        
        let numberOfArgs = args.count
        var processedArgs = 0
        
        var state = State.JustStartedParsing
        
        /// BUGFIX for count
        while state != .Done && args.count > 0  {
            let arg = args[processedArgs]
            
            switch(state) {
            case .ParsingImplicitlyDisabled:
                if arg.isParsingDisableKey() {
                    state = .ParsingDisabled
                    ++processedArgs
                    break
                }
                if arg.isOptionKey() {
                    throw ExtractorError.UnexpectedOption(option: arg)
                }
                fallthrough
                
            case .ParsingDisabled:
                trailers.append(arg)
                ++processedArgs
                
            case .JustStartedParsing:
                if !arg.isOptionKey() {
                    throw ExtractorError.UnexpectedOperation(operation: arg)
                }
                state = .InTheMiddleOfParsing
                
            case .InTheMiddleOfParsing:
                if arg.isParsingDisableKey() {
                    state = .ParsingDisabled
                    ++processedArgs
                    break
                }
                if !arg.isOptionKey() {
                    state = .ParsingImplicitlyDisabled
                    break
                }
                
                let option = arg
                
                // if we're at the last option or the value is an option, then we have a flag (unary) option
                if processedArgs == numberOfArgs - 1 || args[processedArgs + 1].isOptionKey() {
                    if let type = parsedOptions[option] where type == .Value {
                        throw ExtractorError.AmbiguousOption(option: option)
                    }
                    extracted[option] = ["true"]
                    parsedOptions[option] = .Flag
                    
                } else if extracted[option] == nil {
                    let value = args[processedArgs + 1]
                    extracted[option] = [value]
                    parsedOptions[option] = .Value
                    ++processedArgs
                    
                } else {
                    // if option was previously provided as a flag
                    if let type = parsedOptions[option] where type == .Flag {
                        throw ExtractorError.AmbiguousOption(option: option)
                    }
                    
                    let value = args[processedArgs + 1]
                    extracted[option]!.append(value)
                    ++processedArgs
                }
                ++processedArgs;
                
            case .Done:
                return Options(extracted: extracted, trailers: trailers);

            }
            
            if processedArgs == numberOfArgs {
                state = .Done
            }
        }

        return Options(extracted: extracted, trailers: trailers);
    }
    
    internal static let optionKeyPrefixes = ["--","-"]
    internal static let optionParsingDisableKey = "--"
    
}
extension String {
    func isOptionKey() -> Bool {
        return OptionExtractor
            .optionKeyPrefixes
            .filter({ prefix in self != prefix && self.hasPrefix(prefix)})
            .count > 0
    }
    
    func isParsingDisableKey() -> Bool {
        return self == OptionExtractor.optionParsingDisableKey
    }
}

var allArgs = NSProcessInfo.processInfo().arguments
allArgs.removeFirst()
let args = allArgs

let extractor = OptionExtractor()
do {
    let options = try extractor.extractOptions(args)
    
    let toSerialize = ["extracted":options.extracted, "trailing":options.trailers]
    let json = try NSString(data: NSJSONSerialization.dataWithJSONObject(toSerialize, options: [.PrettyPrinted]), encoding: NSUTF8StringEncoding)
    print(json!)
    exit(0)

} catch let error {
    print(error)
    exit(-1)
}

