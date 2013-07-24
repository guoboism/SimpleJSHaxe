package sjs;
import sjs.data.Token;

  // tokens.js
  // 2007-08-05
  // Can't beat Douglas Crockford's js lexer, so what follows is an almost-unmodified copy of it:
  

  // (c) 2006 Douglas Crockford

  // Produce an array of simple token objects from a string.
  // A simple token object contains these members:
  //      type: 'name', 'string', 'number', 'operator'
  //      value: string value of the token
  //      from: index of first character of the token
  //      to: index of the last character + 1

  // Comments of the // type are ignored.

  // Operators are by default single characters. Multicharacter
  // operators can be made by supplying a string of prefix and
  // suffix characters.
  // characters. For example,
  //      '<>+-&', '=>&:'
  // will match any of these:
  //      <=  >>  >>>  <>  >=  +: -: &: &&: &&

class Lexer {

	private static var from:Int = 0;// The index of the start of the token.
	private static var i:Int = 0;// The index of the current character.

	public static function tokenize(src:String, prefix:String='=<>!+-*&|/%^', suffix:String='=<>&|+-'):Array<Token> {
		
		var c:Dynamic;                      // The current character.
		var length:Int = src.length;
		var n:Dynamic;                      // The number value.
		var q:String;                      // The quote character.
		var str:String;                    // The string value.
		var result:Array<Token> = [];            // An array to hold the results.

		// Begin tokenization. If the source string is empty, return nothing.

		if (src == null || src.length == 0) {
			return null;
		}

		// Loop through src text, one character at a time.

		c = src.charAt(i);
		while (c) {
			from = i;

			//whitespace,  ignore
			if (c <= ' ') {
				i += 1;
				c = src.charAt(i);

				
			// name.
			} else if (c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c == '_') {
				str = c;
				i += 1;
				while(true) {
					c = src.charAt(i);
					if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
							(c >= '0' && c <= '9') || c == '_') {
						str += c;
						i += 1;
					} else {
						break;
					}
				}
				result.push(make(TName, str));

				
			// number.
			// A number cannot start with a decimal point. It must start with a digit,
			// possibly '0'.
			} else if (c >= '0' && c <= '9') {
				str = c;
				i += 1;
				
				// Look for more digits.
				// hex number?
				if(src.charAt(i) == 'x') {
					str = '';
					i += 1;

					while(true) {
						c = src.charAt(i);
						if ((c < '0' || c > '9') && (c < 'a' || c > 'f') && (c < 'A' || c > 'F')) {
							break;
						}
						i += 1;
						str += c;
					}
					
					n = Std.parseInt(str);//GB: orignal code forces parse into hex
					if (Math.isFinite(n)) {
						result.push(make(TNumber, n));
					} else {
						make(TNumber, str).error("Bad hex number");
					}
					
				//regular number
				} else {
					
					while(true){
						c = src.charAt(i);
						if (c < '0' || c > '9') {
							break;
						}
						i += 1;
						str += c;
					}

				// Look for a decimal fraction part.
				if (c == '.') {
					i += 1;
					str += c;
					while(true) {
						c = src.charAt(i);                        
						if (c < '0' || c > '9') {
							break;
						}
						i += 1;
						str += c;
					}
				}

				// Look for an exponent part.
				if (c == 'e' || c == 'E') {
					i += 1;
					str += c;
					c = src.charAt(i);
					if (c == '-' || c == '+') {
						i += 1;
						str += c;
					}
					if (c < '0' || c > '9') {
						make(TNumber, str).error("Bad exponent");
					}
					do {
						i += 1;
						str += c;
						c = src.charAt(i);
					} while (c >= '0' && c <= '9');
				}

				// Make sure the next character is not a letter.
				if (c >= 'a' && c <= 'z') {
					str += c;
					i += 1;
					make(TNumber, str).error("Bad number");
				}

				// Convert the string value to a number. If it is finite, then it is a good
				// token.

				n = Std.parseFloat(str);  // was +str
				if (Math.isFinite(n)) {
					result.push(make(TNumber, n));
				} else {
					make(TNumber, str).error("Bad number");
				}
				
			} // hex / regular number

		// string
		} else if (c == '\'' || c == '"') {
			str = '';
			q = c;
			i += 1;
			while(true) {
				c = src.charAt(i);
				if (c < ' ') {
					//GB old //make('string', str).error(c == '\n' || c == '\r' || c == '' ?"Unterminated string." : "Control character in string.", make('', str));
					make(TString, str).error(c == '\n' || c == '\r' || c == '' ? "Unterminated string." : "Control character in string.");
				}

				// Look for the closing quote.

				if (c == q) {
					break;
				}

				// Look for escapement.

					if (c == '\\') {
						i += 1;
						if (i >= length) {
							make(TString, str).error("Unterminated string");
						}
						c = src.charAt(i);
						switch (c) {
						case 'b':
							c = '\\b';
							break;
						case 'f':
							c = '\\f';
							break;
						case 'n':
							c = '\\n';
							break;
						case 'r':
							c = '\\r';
							break;
						case 't':
							c = '\\t';
							break;
						case 'u':
							if (i >= length) {
								make(TString, str).error("Unterminated string");
							}
							c = Std.parseInt(src.substr(i + 1, 4));//GB original force to hex
							if (!Math.isFinite(c) || c < 0) {
								make(TString, str).error("Unterminated string");
							}
							c = String.fromCharCode(c);
							i += 4;
							break;
						}
					}
					str += c;
					i += 1;
				}
				i += 1;
				result.push(make(TString, str));
				c = src.charAt(i);

			// comment.

			} else if (c == '/' && src.charAt(i + 1) == '/') {
				i += 1;
				while(true) {
					c = src.charAt(i);
					if (c == '\\n' || c == '\\r' || c == '') {
						break;
					}
					i += 1;
				}

			// combining

			} else if (prefix.indexOf(c) >= 0) {
				str = c;
				i += 1;
				while (i < length) {
					c = src.charAt(i);
					if (suffix.indexOf(c) < 0) {
						break;
					}
					str += c;
					i += 1;
				}
				result.push(make(TOperator, str));

			// single-character operator

			} else {
				i += 1;
				result.push(make(TOperator, c));
				c = src.charAt(i);
			}
		}
		return result;
	}
	
	static function make(type:TokenType, value:Dynamic):Token {

		// Make a token object.
		if(type == TNumber) value = Std.parseFloat(value);
		
		return new Token(type, value, from, i);
	}

}

