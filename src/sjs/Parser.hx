/*  Parser

  The class takes the unconventional (for AS3) step of defining a bunch of
  "symbol" objects like untyped __this__:
  
    { bpow:an_int, nud: function() { ... }, led:function(){ ... }, std:function() { ... } }
  
  Some symbols have only nud, some have only led, some have both, and some have only std. 

  (These are abbreviations for Null Denotation, Left Denotation, and Statement Denotation,
  in the terminology of Pratt parsing.
  
    Let's take the example of:
      y = [1,2,3];
      z = 1;
      x = y[z];
      
    Null Denotation: we call the NUD of '[' on the first line; the resulting token doesn't reference anything to the left of it:
                      { first:[1,2,3] }

    Left Denotation: we call the LED of '[' on the last line; the resulting '[' token slurps in 'y':
                      { first:y, second:z }

    Statement Denotation: a special case for statements like return and var, which don't have a value, as opposed to expressions which do
    
   )
  
  The symbols are all conceptually similar, but there's a lot of variability in the
  nud and led functions, and I didn't want to define 20-odd different classes for
  what's basically a data structure.



      pseudo-types:
        token:    {type, value, from, to}
        symbol:   {nud, led, std, bpow, codegen} associated with an id
    
        parsenode: token + symbol + id
          - could set the prototype of each token to the symbol with the matching id
          - could make a ParseNode class per symbol and construct one instance around each token read
        the id of a parseNode references
  
*/

package sjs;

  import sjs.data.Symbol;
  import sjs.util.ANSI;
  import sjs.data.Token;
  import sjs.VM;
    
  class Parser {

	public var symtab:Map<String,Symbol>;
	public var scopes:Array<Array<String>>; // just names //GB was = [[]]
	public var tokens:Array<Token>;
	public var token:Symbol = null;//GB is it a type token and symbol at different time? 
	public var token_idx:Int = 0;
	public var source_code:String;
	public var generated_code:Array<Dynamic>;

	public var ID_END    :String = '(end)';
	public var ID_LITERAL:String = '(literal)';
	public var ID_NAME   :String = '(name)'; // we attach IDs to lexer tokens
	//GB deleted as we have enum//public var TName    :String = 'name';  // tokens from the lexer have type, value, from, and to

    // public inline static var END_TOKEN :Dynamic = 
    public static function getEndToken():Dynamic {
		var tp:Symbol = new Symbol();
		tp.id = '(end)';
		tp.toString = function():String{return "*END*";}
		return tp;
	}
	  
    public var ast:Dynamic;

    // debug cruft
    public var xd:Int = 0 ;
    public var tracing:Bool = false;



    /***********************************************************
    *
    *    PUBLIC API
    *
    *     opcode = (new Parser()).parse(src).codegen();
    *     opcode = (new Parser()).codegen(src);
    *
    ***********************************************************/
	
    public function new() {
		scopes = new Array<Array<String>>();
		scopes.push(new Array<String>());
        init_symbols();
    }
      
    // usage:  VM.load ( parser.parse(js_code).codegen()).run();
    // or: interp.load(js); interp.run();
    // or: new Interpreter(js});
	public function parse (src:String):Parser {
		tokens = [];
		token = null;
		token_idx = 0;
		source_code = src;
		
		tokens = Lexer.tokenize(src);
		
		next();
		ast = statements();
		return this;
	}

	public function codegen(?src:String):Array<Dynamic>{
		if(src != null && src.length > 0) { parse(src);}
	  
		//log("##### CODE GENERATION ####\n", JSON.stringify(ast));
	  
		generated_code = [];
		C(ast);
		log(['## GENERATED:', generated_code.join(" ")]);
		
		
		//trace('Generated Code-------------');
		//for (i in 0...generated_code.length) {
		//	trace(i + " : " +generated_code[i]);
		//}
		//trace('-------------');
		
		
		return generated_code;
	}
    
	/***********************************************************
	*
	*    DEBUG 
	*
	***********************************************************/

    public function dump_node(tree:Dynamic) : String {
        var ret:Array<Dynamic> = [];
           
        function p(s:String) :Void {
            ret.push(s);
        }
           
        function pval(v:Dynamic) : Void {
            //p(v.value + ':' + typeof v.value);
            p(v.value);
        }
           

        function dnr(n:Dynamic) : Void {
            if(!n) return;

            if(Std.is(n, Array)) {
				p('[');                     // '[' and ']' for arrays, such as argument arrays
				var i:Int = 0;
				
				var na:Array<Dynamic> = cast(n,Array<Dynamic>);
				for(v in na) {
					dnr(v);
					if(++i < na.length) { p(','); }
				}
				p(']');
			} else if( n.hasOwnProperty('first')){               // '(' and ')' around node children
				p('(');
				if(n.value == '(') p('CALL'); else if(n.value == '[') p("ARRAY"); else pval(n);
				dnr(n.first);
				dnr(n.second);
				dnr(n.third);
				p(')');
			} else {
				pval(n);
				return;
			}
		}
           
        dnr(tree);
        return ret.join(' ');
	}        
       
	public function dump_ast():String{
	  return dump_node(ast);
	}
    
    
	public function codegen_string():String {
	  this.codegen();
	  return generated_code.join(' ');
	}

	private function _annotateVarsWithType(e:Dynamic, i:Int, a:Array<Dynamic>) : String {          
	  if(i == 0 || a[i-1] != LIT) {
		return e;  // don't annotate non-literals with type
	  }
	  
	  if(Std.is(e,Array)) {
		return "[ " + e.map(_annotateVarsWithType).join(' ') + ' ]';
	  }
	  
	  return Type.typeof(e) + ':' + e;          
	  /*return ':' + e;*/
	}
	
	/* GB ref not found
	public function dbg_codegen_string():String {
		this.codegen();
		return generated_code.map(_annotateVarsWithType()).join(' '); //map a function as key?
	}*/


	public function log(msg:Array<Dynamic>) : Void { //GB this is a varing pramater function; use Reflect.makeVarArgs(log)(1, 2, 3);
		if(tracing) {
			var indent:String = '                                    '.substring(0, xd * 4);
			
			trace(indent, '[Parser]', msg.join(' '));
		}
	}
      
  
	public function formattedSyntaxError(t:Dynamic) : String {
		
		var nlCharTable:Map<String,Bool> = new Map<String,Bool>();
		nlCharTable["\n"] = true;
		nlCharTable["\r"] = true;
		
		
		function line_start(pos:Int):Int {
			while(pos > 0 && !nlCharTable[source_code.charAt(pos)]) pos--;
			return 0 > pos?0:pos;//GB max
		}
		  
		function line_end(pos:Int):Int {
			var z:Int = source_code.length - 1;
			while(pos < z && !nlCharTable[source_code.charAt(pos)]) pos++;
			return z < pos?z:pos;//min
		}
		  
		var a:Int = line_start(line_start(t.from) - 1);
		var z:Int = line_end(line_end(t.to) + 1);
		  
		var ansi_escape:String = ANSI.RED_TEXT + ANSI.INVERT_BACKGROUND;//GB was a const
		var dupe:String = source_code.substring(0, t.from) + ansi_escape + source_code.substring(t.from, t.to) + ANSI.NORMAL_BACKGROUND + source_code.substring(t.to);
				
		return dupe.substring(a, z + (ansi_escape + ANSI.NORMAL_BACKGROUND).length);
		
	}
      


    /***********************************************************
    *
    *    PARSER CORE
    *
    ***********************************************************/
	
	//GB used to "extend" a token to symbol, not useless
    // reserved words stay reserved -- operators
	/*
    public function _extend(a:Dynamic, b:Dynamic) : Dynamic {
		var fields:Array<String> = Reflect.fields(b);
        for (k in fields) {
			Reflect.field(object, "foo")
          a[k] = b[k];
        }
        return a;
    }*/

    public function next(id:String=null) : Symbol {         
        if(id != null && token.id != id) {
            log(['Parser::next expected to be on "' + id + '" but was on "' + dump_node(token) + '"']);
            if(id == ';') throw 'missing a semicolon near ' + offending_line(token.from);
            throw 'unexpected token, id: `' + token.id + ' value: `' + token.value + "' in next()";
        }
          
        //var pt:Dynamic = token; //GB commented as unesed
        token = new Symbol();
		token.extendFromToken(tokens[token_idx++]);
        
        if(token_idx > tokens.length) return token  = getEndToken();

        if(token.type == TName) {
            if(symtab.exists(token.value)) {
                token.id = token.value;
            } else {
                token.id = ID_NAME;
            }
        }else if(token.type == TString || token.type == TNumber) {
            token.id = ID_LITERAL;
            // lexer transforms numbers to floats
        } else /*operator*/ {
            token.id = token.value;
        }
        
		if (token.id == ";") {
			var n = "1";
		}
		
		//create 
        //return _extend(token, symtab[token.id]); // clone FTW.  So what if it might be slow?   handles the this binding simply.

		
		token.extendFromSymbol(symtab[token.id]);
		return token;
	}

    public function infix_codegen(opcode:Dynamic):Void->Void { 
		return function():Void { 
			C(untyped __this__.first); 
			C(untyped __this__.second); 
			emit(opcode);
		};
    }


    public function infix_thunk_rhs_codegen(opcode:Dynamic):Void->Void { 
		return function():Void { 
			C(untyped __this__.first);
			// delay evaluation of second child by wrapping it in an array literal
			emit(LIT);
			emit(codegen_block(untyped __this__.second));
			emit(opcode);
			};
    }
    

    public function prefix_codegen(opcode:Dynamic):Void->Void  { 
		return function():Void { C(untyped __this__.first); emit(opcode); };
    }


    public function symbol(sym:String):Symbol {
		if (!symtab.exists(sym)) symtab[sym] = new Symbol();
		return symtab[sym];
    }


    public function infix(sym:String, bpow:Int, opcode:Dynamic) : Dynamic {
      
        function leftDenotation(lhs:Dynamic):Dynamic {
			untyped __this__.first = lhs;
			untyped __this__.second = expression(untyped __this__.bpow);
			return untyped __this__;
        }
        
        symtab[sym] = new Symbol();
		symtab[sym].led = leftDenotation;
		symtab[sym].codegen = infix_codegen(opcode);
		symtab[sym].bpow = bpow;
		
		return symtab[sym];
    }


    public function infix_thunk_rhs(sym:String, bpow:Int, opcode:Dynamic) : Dynamic {
		
		symtab[sym] = new Symbol();
		symtab[sym].led = function(lhs:Dynamic):Dynamic {
										untyped __this__.first = lhs;
										untyped __this__.second = expression(untyped __this__.bpow);
										return untyped __this__;
									}
									
		symtab[sym].codegen = infix_thunk_rhs_codegen(opcode);
		symtab[sym].bpow = bpow;
		
		
		return symtab[sym];
    }


    public function prefix(sym:String, bpow:Int, opcode:Dynamic) : Void { 
        var s:Dynamic = symbol(sym);
        s.bpow = s.bpow !=0 ? s.bpow:140;  // don't want infix - to get a higher precedence than *, for example.
        s.nud = function():Dynamic {
            untyped __this__.first = expression(0);
            return untyped __this__;
        };
        s.codegen = prefix_codegen(opcode);
    }


	//GB public function assignment(id:String, bpow:Int, operation:String=null) : Void {
    public function assignment(id:String, bpow:Int, operation:OPCode=null) : Void {
		var sym:Symbol = symbol(id);
        sym.bpow = bpow;
      
      
        var mutate:Bool = operation != null ? true : false;    // operation is "+" for +=, "-" for -=, etc; and null for "=". 
      
        sym.led = function(lhs:Dynamic):Dynamic {
                                    untyped __this__.first = lhs;
                                    untyped __this__.second = expression(untyped __this__.bpow - 1 );  /* drop the bpow by one to be right-associative */
                                    untyped __this__.assignment = true;
                                    return untyped __this__;
                                };

        sym.codegen = function():Void {
            if(mutate) {                                    
                // do the operation     // if it's "x += 3", then...
                C(untyped __this__.first);          // LIT x
                C(untyped __this__.second);         // VAL 3
                emit(operation);        // ADD
            } else {
                // just emit the value   // if it's "x = 3", then:  LIT 3
                C(untyped __this__.second);
            }

            //assign it to the lhs
            C(untyped __this__.first, true);        // LIT x 

            if(untyped __this__.first.id=='.') {
                // e.g. for "point.x += 3", change the opcode from:
                //    VAL point LIT x GETINDEX LIT 3 ADD    VAL point LIT x GETINDEX
                // to:                                                      ^^^
                //    VAL point LIT x GETINDEX LIT 3 ADD    VAL point LIT x PUTINDEX
                remit(PUTINDEX); // PUTINDEX consumes the stack (val obj key)  and does obj[key] = val;
            } else {
                emit(PUT);
            }
            // PUT leaves the value onstack for multiple assignment, DROP it as we come out of the nested assignments
            // need_drop();
        };

    }


    public function affix(id:String, bpow:Int, opcode:OPCode) : Void {
		symtab[id] = new Symbol();
		symtab[id].bpow = bpow;
		symtab[id].isPrefix = false;
		symtab[id].led = function(lhs:Dynamic) : Dynamic {
			untyped __this__.first = lhs;
			return untyped __this__;
		};
			  
			  
        symtab[id].nud = function():Dynamic {
			// next must be variable name
			if(token.id == ID_NAME) {
				untyped __this__.first = token;
				untyped __this__.isPrefix = true;
				next();
				return untyped __this__;
			} else {
				throw "Expected ID_NAME after ++ operator";
			}
			return null;
		};
			  
        symtab[id].codegen = function() : Void {
			// increment the variable, leaving a copy of its previous value on the stack.
			if(untyped __this__.isPrefix) {
				C(untyped __this__.first);
				emitMulti([LIT, 1, opcode]); 
				emit(DUP);
				C(untyped __this__.first, true);
				emit(PUT);
			} else /* postfix */ {
				C(untyped __this__.first);
				emit(DUP);
				emitMulti([LIT, 1, opcode]); 
				C(untyped __this__.first, true);
				emit(PUT);
			}
		};
             
    }

       

  
    public function constant(id:String, v:Dynamic) : Dynamic {
		symtab[id] = new Symbol(null,
			function():Dynamic{ 
				untyped __this__.value = v;
				return untyped __this__;
			},
			null, 0);
		
		symtab[id].codegen = function():Void {
            emit_lit(untyped __this__.value);
        }
	  
		return symtab[id];
    }


    public function expression(rbp:Float):Dynamic {
        xd++;
        // grab first token and call its nud
        var t:Dynamic = token;
        next();
        if(t.nud == null) {
			trace(formattedSyntaxError(t));
			throw  "Unexpected " + t.id + " token:  ``" + t.value + "''" + " at char:" + t.from + "-" + t.to + " || line: " + offending_line(t.from);
        }
		  
        var lhs:Dynamic = t.nud();
        // shovel left hand side into higher-precedence tokens' methods
        while (rbp < token.bpow){
            t = token;
            next();              
            if(!t.led) { 
				throw t + 'has no led in ' + source_code;
            }
			lhs = t.led(lhs);
        } 
        xd--;
        return lhs;
    }
                     
    public function block():Dynamic {
		var t:Dynamic = token;
		next("{");
		return t.std();
    };

      
    public function statement():Dynamic{
        var ret:Dynamic, t:Dynamic = token;
        if(t.std) {
            next();
            ret = t.std();
            return ret;
        }

        var xstmt:Dynamic = expression(0);
    
        if(!(xstmt.assignment || xstmt.id == '(')) { 
            throw('invalid expression statement :' +  offending_line(t.from) );
        } // neither assignment nor function call
        next(';');
        return xstmt;
    }
          

      public function statements():Array<Dynamic>{
          var stmts:Array<Dynamic> = [];
          while(true) {
              if(token.id == '}' || token.id == ID_END) break;
              stmts.push(statement());
          }
          return stmts;
      }     

    /***********************************************************
    *
    *    CODEGEN
    *
    ***********************************************************/

	//GB not used, to be del
    //public function emit1(opcodes:Array<Dynamic>): Void {//GB prameter was like (opcode:*, ...ignore)
    //  emit([opcodes[0]]);
    //}
    
    public function emit(opcode:Dynamic): Void {
        generated_code.push(opcode);
    }
	
	public function emitMulti(opcodes:Array<Dynamic>): Void {
		for(i in 0...opcodes.length){
			generated_code.push(opcodes[i]);
		}
    }

    public function remit(token:Dynamic):Void {
		generated_code.pop();
		emit(token);
    }

    public function emit_lit(v:Dynamic):Void {
		emit('LIT');
		emit(v);
    }

    public function emit_prefix(node:Dynamic, op:Dynamic):Void {
		C(node); 
		emit(op);
    }
    public function emit_infix(n1:Dynamic, n2:Dynamic, op:Dynamic):Void {
		C(n1); 
		C(n2); 
		emit(op);
    }

    // usage = j = emit_jump_returning_patcher(JUMPFALSE); ... emit a bunch of stuff ... j();
    // opcodes are:  JUMP|JUMPFALSE <offset>
    // The offset is from the address of JUMPFALSE, not of <offset>
	public function emit_jump_returning_patcher(opcode:Dynamic):Void->Void {
		emit(opcode);
		var here:Int = generated_code.length;
		function patcher():Void { 
			generated_code[here] = generated_code.length - here - 1; // decrement to factor in the <offset> literal
		}
		emit('@patch'); // placeholder @here
		return patcher;
	}
          
          
	public function backjumper(opcode:Dynamic):Void->Void {
		// opcodes emitted:  JUMP|JUMPFALSE <offset>
		// currently uses only JUMP, but will need JUMPFALSE to support "do { ... } while(test)" semantics    (TBD)
		var here:Int = generated_code.length;
		return function():Void { 
			emit(opcode);
			var offset:Int = here - generated_code.length - 1; // decrement to factor in the <offset> literal
			emit(offset);
		}
	}
          
    // public var drops_needed:Int = 0;                 // fixme: this seems really incorrect.  take multiple assignment out?
    // public function need_drop():Void { drops_needed++; }  // see assignment()  ^^^... no, make codegen return and concat arrays recursively
    
    public function C(node:Dynamic, is_lhs:Bool=false):Void {  
		if(!node) {
			trace('empty node reached');
			return;
		}
 
		// TODO: if multiple assignment: MARK .. C ... CLEARTOMARK
      
		if(Std.is(node, Array)) { // statements or argument lists
			for(i in 0...node.length) {
				C(node[i], is_lhs);
				/*emit(DROPALL);*/
				// we might need to drop some leftover values from a multiple assignment
				// while(drops_needed > 0) { 
				//   log('emitting drop after multiple assignment,', drops_needed, 'remaining');
				//   emit(DROP);
				//   drops_needed--;
				// }
			}
		} else {
			if(!node.hasOwnProperty('codegen')) { 
				throw 'No Codegen for '+node.name+'#'+node.id+'='+node.value;
			} else {
				node.codegen(is_lhs);
			}
		}
    }
    
    
    // for code like " a { b c } d  ", return [a, [b, c], d]
    public function codegen_block(node:Dynamic):Dynamic{
		var orig_code:Array<Dynamic> = generated_code;
		generated_code = [];
		C(node);
		var block_code:Array<Dynamic> = generated_code;
		generated_code = orig_code;
		return block_code;
    }
    

    public function C_hash(o:Dynamic):Void {
		
		var fields = Reflect.fields (o);
		for (propertyName in fields) {
			emitMulti(['LIT', propertyName]);
			C(Reflect.field(o, propertyName));
		}
		
		/* GB
		for(k in o) {
			emitMulti(['LIT', k]);
			C(o[k]);
		}*/
    }


	// scope handling stuff at present only exists to prevent name collisions at parse time.
    public function scope_define(name:String):Void {
        // used by: function, var
		/*log('scope_define', name);*/
		// allow redefinition so we can say function x() {...} repeatedly during dev
        // for each(var existing_name:String in scopes[0]) {
        //   if(existing_name == name) {
        //     throw new Error('tried to redefine variable ' + existing_name + ' in line "' + offending_line() + '"');
        //   }
        // }
        scopes[0].push(name); // FIXME, throw an error if it's already defined 
    }
	  
    public  function scope_push():Void {
        scopes.unshift([]);
    }
	  
    public function scope_pop():Void {
		scopes.shift();
    }
      

    public function parse_argument_list():Array<Dynamic> {
        var args:Array<Dynamic> = [];
        
        if(token.id == ')') return args;  // bail if args list is empty; caller is responsible for consuming )
        
        while(true) {
            args.push(expression(0));
            if(token.id != ',') { // this would be the closing )
                break;
            }
            next(',');
        }
        return args;
    }    
    
    public var getAnonFuncName_id:Int = 0;
    public function getAnonFuncName():String {
		return 'anon' + getAnonFuncName_id++;
    }
      
    public function init_symbols():Void {

		symtab = new Map<String,Symbol>();
		
		//constants
		constant('true', true);
		constant('false', false);
		
		//primitives
		symtab[ID_NAME] = new Symbol(null,function():Dynamic {return untyped __this__;},null);
		symtab[ID_NAME].toString = function():String { return untyped __this__.value; };
        symtab[ID_NAME].codegen = function(am_lhs:Bool):Void {  emitMulti([am_lhs ? 'LIT' : 'VAL', untyped __this__.value]); };  // need a reference if we're assigning to the var; the value otherwise.
      
		symtab[ID_LITERAL] = new Symbol(null, function():Dynamic {return untyped __this__;}, null,0);
		symtab[ID_LITERAL].toString = function():String { return untyped __this__.value; };
		symtab[ID_LITERAL].codegen = function():Void { emit_lit(untyped __this__.value); };
  
		//assignment
		// fixme: and here we see why V K SWAP SET is more consistent than V K PUT
		assignment('=', 20);
		assignment('+=', 130, ADD);
		assignment('-=', 130, SUB);
		assignment('*=', 130, MUL);
		assignment('/=', 130, DIV);
		assignment('%=', 130, MOD);

		affix('++', 140, ADD);
		affix('--', 140, SUB);
            

		prefix('!', 140, NOT);
		infix('+', 120, ADD);
		infix('-', 120, '*minus*');
		prefix('-', 120, '*unary minus*');

		// tbd: different codegens by arity?
		symtab['-'].codegen = function():Void { 
			if(untyped __this__.second) 
				emit_infix(untyped __this__.first, untyped __this__.second, SUB);
			else {
				emit_prefix(untyped __this__.first, NEG);
			}
		};
        

		infix('*', 130, MUL);
		infix('/', 130, DIV);
		infix('%', 130, MOD);


            // comparison
		infix('<', 100, LT);
		infix('<=',100, LTE);
		infix('>', 100, GT);
		infix('>=',100, GTE);
		infix('==', 90, EQL);

  
		infix_thunk_rhs('&&', 50, AND);
		infix_thunk_rhs('||', 40, OR);

      
		infix('.', 160, GETINDEX); // a.b.c indexing operator
		//indexing
		// RHS [k(1) dot... k(n-1) dot] dict k(n) put
		// where dot has stack effect ( o k -- o[k] )
		// a.b.c.d = e -- $ e $a # b dot # c dot # d dot dict 
		symtab['.'].codegen = function(is_lhs:Bool /* assignment? */):Void {
			if(untyped __this__.first.id != '.') {
				C(untyped __this__.first, false); // use VAL
			} else {
				C(untyped __this__.first, true);  // use LIT
			}
			C(untyped __this__.second, true); // treat as LHS until the last item in the dot-chain
			emit(GETINDEX);
		};
            
            
		symbol('new');
		symbol('new').bpow = 160;
		symbol('new').nud = function():Dynamic {
			if(token.type != TName) throw("Expected name after new operator, got " + token.value + " in: " + offending_line());
			untyped __this__.first = token;
			next(/*constructor*/);
			next('(');
			untyped __this__.second = token.id == ')' ? [] : parse_argument_list();
			next(')');
			return untyped __this__;
		};
		
		symbol('new').codegen = function():Void {
			emit_lit(untyped __this__.first.value);
			emit(MARK);
			C(untyped __this__.second);
			emit(ARRAY);
			emit(NATIVE_NEW);   // ( constructor [args] -- instance )
		};
            
		symtab['('] = new Symbol();
		symtab['('].bpow = 160;
		symtab['('].isFunctionCall=false;
		symtab['('].nud = function():Dynamic{
			var expr:Dynamic = expression(0);
			next(')');
			return expr;
        };
		symtab['('].led = function(lhs:Dynamic):Dynamic{
			untyped __this__.first = lhs;
			// will be on '('
			untyped __this__.second = parse_argument_list();
			next(')');
			untyped __this__.isFunctionCall = true;
			return untyped __this__;
        };
        symtab['('].codegen = function():Void {
			/*// recurse and find "..." async in argument list?
			//whatabout f(..., f2(...))
			// : translates to await f(resumeLastAwait, await f2(resumeLastAwait))
			//
			function isEllipsis(arg:Object, i:Int, a:Array):Bool {
				return arg.id == '...';
			}*/
		  
			/*var isAsync:Bool = this.second.some(isEllipsis);*/

			C(untyped __this__.first);
			emit(MARK);
			C(untyped __this__.second);
			emit(ARRAY);
			emit(CALL);

			/*if(this.second.some(isEllipsis)) {
				emit(AWAIT);
			}*/
        };
      
        
		symtab[')'] = new Symbol(null, null, null, -1);// ?? fixme

		symtab['function'] = new Symbol(null, 
			function():Dynamic {
				var args:Array<Dynamic> = [];
				// we need to create a fake function-name token for this anonymous function
				var fn_name:Dynamic = {
					id: ID_NAME,
					type: TName,
					value: getAnonFuncName(),
					isAnonymous:true
				};

				scope_push();
				untyped __this__.scope = scopes[0];
				next('(');
				if(token.id != ')') {
					args = parse_argument_list();
				}
  
				next(')');
				next('{');
				var body:Array<Dynamic> = statements();
				//trace('function nud:', Inspector.inspect(body));
				next('}');

				scope_pop();

				untyped __this__.first = fn_name;
				untyped __this__.second = args;
				untyped __this__.third = body;

				return untyped __this__;
			},
			
			function():Dynamic {
				var fn_name:Dynamic = token;
				var args:Array<Dynamic> = [];
				next(/* skip the function name */);
      
				if(fn_name.type != TName) { throw("Invalid function name '" + fn_name.value + "' on line: " + offending_line()); }
            
				scope_define(fn_name.value);
				scope_push();
				untyped __this__.scope = scopes[0];
				next('(');
				if(token.id != ')') {
					args = parse_argument_list();
				}
				next(')');
				next('{');
				var body:Array<Dynamic> = statements();
				next('}');
  
				scope_pop();
       
				untyped __this__.first = fn_name;
				untyped __this__.second = args;
				untyped __this__.third = body;
      
      
				return untyped __this__;
			},
		0);
			
        symtab['function'].codegen = function():Void {
          /* generates: 
            LIT "function_name"               
            MARK   
              LIT arg1..
              LIT argN
            ARRAY
            -- array of opcodes
            LIT
            [
              LIT local1 LOCAL, ... 
              LIT localN LOCAL 
              ... opcodes ...
            ]
            CLOSURE
            
			*/
          
			// currently:
			// function f(a) { var v; trace(v); }  -->  LIT f MARK LIT a LIT v LOCAL ARRAY [ LIT trace MARK LIT v ARRAY CALL ] DEF
			// desired:
			// function f(a) { var v; trace(v); }  -->   <MARKER> LIT f MARK LIT a LIT v LOCAL ARRAY LIT trace MARK LIT v ARRAY CALL ] <CLOSURE>
          
			// function name literal
			emit_lit(untyped __this__.first.value);
          
			// arguments
			emit(MARK);
			C(untyped __this__.second, true);
			emit(ARRAY);
          
			// tbd: fix this hack to create locals at the beginning of a function's code block
			var body:Array<Dynamic> = codegen_block(untyped __this__.third);
			
			var tpScope:Array<String> = untyped __this__.scope;
			for(v in tpScope) { body.unshift(LOCAL); body.unshift(v); body.unshift(LIT); }

			emit(LIT);
          
			emit(body);
          
			//emit(MARK); emit(EVAL_OFF); body.forEach(emit1); emit(EVAL_ON); emit(ARRAY);  // not the greatest idea
			emit(CLOSURE);
			if(!untyped __this__.first.isAnonymous) {
				/*trace('emitting drop for named function codegen');*/
				emit(DROP); // anon function will presumably be assigned to something... although, wait, this kills the module pattern: (function(){...})()
			}
        };

		
		
		symtab['return'] = new Symbol();
		symtab['return'].bpow = 0;
		symtab['return'].std = function():Dynamic {            
			// peek at next token to see if this is "return;" as opposed to "return someValue;"
			if(token.id != ';') {
				untyped __this__.first = expression(0);
			}
			next(';');
			return untyped __this__;
		};
		
		symtab['return'].codegen=function():Void {
				C(untyped __this__.first);
				emit(RETURN);
        };
		

		symtab['['] = new Symbol();
		symtab['['].nud = function():Dynamic {
			var a:Array<Dynamic> = [];
		  
			if(token.id != ']') {
				while(true){
					a.push(expression(0));
					if(token.id != ',') break;
					next(',');
				}
			}
			next(']');
			untyped __this__.first = a;
		  
			untyped __this__.subscripting = false;
			return untyped __this__;
		};
		
		symtab['['].led = function(lhs:Dynamic):Dynamic{
			untyped __this__.first = lhs;  // "y"
			// will be on '['
				untyped __this__.second = expression(0); // "z"
			next(']');

			untyped __this__.subscripting = true;
			return untyped __this__;
        };
		
		symtab['['].toString = function():String { return "(array " + untyped __this__.first + ")"; };
		symtab['['].bpow = 160;
		symtab['['].codegen = function(is_lhs:Bool = false):Void { 
            if(untyped __this__.subscripting) {
              //untyped __this__.first could be a variable name or a literal array, e.g.  [1,2,3][0];  getArray()[0]
              //we want to throw whatever it is on the stack, then getIndex it.
              C(untyped __this__.first, false); // use VAL, in "x = y[z]", we want the value of y on the stack
              C(untyped __this__.second, false); // treat as RHS...      // FIXME: a[i] = n fails by using PUTINDEX
              emit(is_lhs ? PUTINDEX : GETINDEX);
            } else {
              emit('MARK'); C(untyped __this__.first); emit('ARRAY');
            }
        };

		symtab['{'] = new Symbol();
		symtab['{'].std = function():Dynamic { 
				var a:Array<Dynamic> = statements();
				next('}');
				return a;
			};
        symtab['{'].nud = function():Dynamic {
            var key:Dynamic, value:Dynamic, obj:Dynamic = {};
            while(true) {
              key = token;
              next();
              next(':');
              value = expression(0);
              obj[key] = value;
              //next(); // --> , or }
              if(token.id != ',') break;
              next();
            }
            next('}');
            untyped __this__.first = obj;
            return untyped __this__;
         };
		 
         symtab['{'].codegen = function():Void { emit('MARK'); C_hash(untyped __this__.first);  emit('HASH'); };
		

		/***********************************************************
		*
		*    CONTROL STRUCTURES
		*
		***********************************************************/


		symtab['if'] = new Symbol();
		symtab['if'].std = function():Dynamic {
              next('(');
              var cond:Dynamic = expression(0);
              next(')');
              next('{');
              var then_block:Array<Dynamic> = statements();
              next('}');
              untyped __this__.first = cond;
              untyped __this__.second = then_block;
        
              // trace(token);
              if(token.id == ID_NAME && token.value == 'else') {
                next(); // skip else
                var t:Dynamic = token;
                untyped __this__.third = t.value == 'if' ? statement() : block( /* eats  { and } */);
                // what if the next statement's another if?
              }
              return untyped __this__;
        };
        symtab['if'].bpow = 0;

        symtab['if'].codegen=function():Void {
			C(untyped __this__.first); // test
	  
			var patch_if:Void->Void = emit_jump_returning_patcher(JUMPFALSE);
			C(untyped __this__.second);
			patch_if();
	  
			if(untyped __this__.third) {
				var patch_else:Void->Void = emit_jump_returning_patcher(JUMP);
				patch_if();
				C(untyped __this__.third);
				patch_else();  // rewrite @else to point after "if{...}else{...}" instructions.
			}
        };        
      

		symtab['while'] = new Symbol();
		symtab['while'].std = function():Dynamic {
			next('(');
			var cond:Dynamic = expression(0);
			next(')');
			next('{');
			var block:Array<Dynamic> = statements();
			next('}');
			untyped __this__.first = cond;
			untyped __this__.second = block;
			return untyped __this__;
		};
			
		symtab['while'].bpow = 0;
		symtab['while'].codegen = function():Void {
		  var emit_backjump_to_test:Void->Void = backjumper(JUMP);
		  C(untyped __this__.first);
		  var patch_jump_over_body:Void->Void = emit_jump_returning_patcher(JUMPFALSE);
		  C(untyped __this__.second);
		  emit_backjump_to_test();
		  patch_jump_over_body();
		};          
      


		symtab['for'] = new Symbol();
		symtab['for'].std = function():Dynamic {
			// for (initial-expr ; test-expr ; final-expr ) { body }
			next('(');
			var init:Dynamic = expression(0);
			next(';');
			var test:Dynamic = expression(0);
			next(';');
			var modify:Dynamic = expression(0);
			next(')');
			next('{');
			var block:Array<Dynamic> = statements();
			next('}');
			untyped __this__.first = [init,test,modify];
			untyped __this__.second = block;
	   
			return untyped __this__; // UNTESTED
		};
		symtab['for'].bpow = 0;
                                                        // "for(i = 0; i < 10; i++) { trace(i); }"
		symtab['for'].codegen = function():Void{
		  C(untyped __this__.first[0]);                         // i = 0
		  var backjump_to_test:Void->Void = backjumper(JUMP);
		  C(untyped __this__.first[1]);                         // i < 10
		  var jumpfalse_to_here:Void->Void = emit_jump_returning_patcher(JUMPFALSE);
		  C(untyped __this__.second);                           // trace(i);
		  C(untyped __this__.first[2]);                         // i ++
		  backjump_to_test();                       // } --> JUMP to i < 10
		  jumpfalse_to_here();                      // patch the JUMPFALSE after "i<10" 
		};
			
		
		symtab['var'] = new Symbol();
		symtab['var'].std = function():Dynamic {
/*            trace('* var statement');*/
			var e:Dynamic, names:Array<Dynamic> = [];
			while(true){
				e = expression(0);
				if(e.id != '=' && e.id != ID_NAME) { 
					throw('Unexpected intializer ' + e + ' in var statement :' + offending_line(untyped __this__.from));
				}
				names.push(e);
				// here's one place where static typing would have saved me trouble:
/*                  scope_define(e.id == 'NAME' ? e.id : e.first.id)*/
				scope_define(e.type == TName ? e.value : e.first.value);

				if(token.id != ',') break;
				next(',');
			}
			next(';');
			untyped __this__.first = names;
				/*trace('* --- end var statement');*/
			return untyped __this__;
		};
		symtab['var'].bpow = 0;
		symtab['var'].toString = function():String {
		  return '(var '+ untyped __this__.first + ')';
		};
		symtab['var'].codegen = function():Void{            
			/*            trace("var codegen doesn't do anything; it's just a marker.");*/
			/* TODO: codegen should prefix locals with LOCAL opcode(TBD) */
			C(untyped __this__.first, true);
		};
		
      
		/*
        await fn();
        doSomething(x(), await y());      
		*/
        
		symtab['await'] = new Symbol();
        // isStatement flag exists so we can clear the stack after statements like
        // "await promiseReturnsSomeValues();"
        // but not in expressions like 
        // "myArray = promiseReturnsSomeValues();"
        
		symtab['await'].isStatement = false;
        
        symtab['await'].expectFunctionCall = function():Void {
            if(!untyped __this__.first.isFunctionCall) throw "Expected function call after await";
        };
        
        symtab['await'].std = function():Dynamic {
			untyped __this__.isStatement = true;
			untyped __this__.first = statement();
			untyped __this__.expectFunctionCall();
			return untyped __this__;
        };
        
        symtab['await'].nud=function():Dynamic {
			untyped __this__.first = expression(0);
			untyped __this__.expectFunctionCall();
			return untyped __this__;
        };
        
        symtab['await'].codegen=function():Void {
			if (untyped __this__.isStatement) emit(MARK);
			C(untyped __this__.first);  // There should be an async method call somewhere in this subtree, 
                          // which will leave a Promise on the stack.
                         
			emit(AWAIT); // AWAIT will then consume the Promise; its fulfillment will resume the VM
                          // with one value on the stack.
                          // if (this.first) consumed it, fine; in case it hasn't, clear to the mark:
                          
			if(untyped __this__.isStatement) emit(CLEARTOMARK);
        };
    }
    

     // return the text of the source-code line containing a given character offset (which offset we originally got from the lexer)
     public function offending_line(near:Int=-1):String {
       var line_start:Int, line_end:Int;
	   
       var nlCharTable:Map<String,Bool> = new Map<String,Bool>();
	   nlCharTable["\n"] = true;
	   nlCharTable["\r"] = true;
       
	   if(near<0) near = token.from;
       // back up to the start of the line
	   
       //for(line_start = near; line_start >= 0 && !nlChar[source_code.charAt(line_start)]; line_start--)
       //   /* ok */ true;
	   
	   line_start = near;
	   while (line_start >= 0 && !nlCharTable[source_code.charAt(line_start)]) {
			line_start--;
		}
	   
       // walk forward to the end of the line
       //for(line_end = near; line_end < source_code.length && !nlChar[source_code.charAt(line_end)]; line_end++)
       //   /* ok */ true;
	   
	   line_end = near;
	   while (line_end < source_code.length && !nlCharTable[source_code.charAt(line_end)]) {
			line_end++;
		}
	   
	   
       return source_code.substring(line_start,line_end);
    }
	
} // class        