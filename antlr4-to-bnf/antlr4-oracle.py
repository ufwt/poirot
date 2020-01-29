from antlr4 import *
import importlib
import sys
from antlr4.error.ErrorListener import ErrorListener

# usage: grammar prefix suffix injection

class MyErrorListener(ErrorListener):

    def __init__(self):
        super(MyErrorListener, self).__init__()

    def syntaxError(self, recognizer, offendingSymbol, line, column, msg, e):
        raise Exception

    def reportAmbiguity(self, recognizer, dfa, startIndex, stopIndex, exact, ambigAlts, configs):
        raise Exception

    def reportAttemptingFullContext(self, recognizer, dfa, startIndex, stopIndex, conflictingAlts, configs):
        raise Exception

    def reportContextSensitivity(self, recognizer, dfa, startIndex, stopIndex, prediction, configs):
        raise Exception

def main():
    grammar = sys.argv[1]
    prefix = sys.argv[2]
    suffix = sys.argv[3]
    injection = sys.argv[4]

    lexer_name = sys.argv[1]+"Lexer"
    lexer_module = importlib.import_module(lexer_name)
    lexer = getattr(lexer_module, lexer_name)(InputStream(prefix+injection+suffix))

    stream = CommonTokenStream(lexer)

    parser_name = sys.argv[1]+"Parser"
    parser_module = importlib.import_module(parser_name)
    parser = getattr(parser_module, parser_name)(stream)
    parser.addErrorListener(MyErrorListener())

    try:
        parser.parse()
    except:
        exit(1)
    exit(0)

if __name__ == '__main__':
    main()
