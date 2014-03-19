/*  VM
  Execute the compiled bytecode.  Inspired heavily by JonesFORTH, to a lesser degree by Postscript and HotRuby.

See:
  http://replay.waybackmachine.org/20090209211708/http://www.annexia.org/forth

Notes to self:
  The Array class is one of the few core classes that is not final, which
  means that you can create your own subclass of Array. Hmmm.... probably a bad idea.

*/

package sjs;

	//import sjs.Inspector;
	//import Promise;
	import sjs.data.Token;
	import sjs.util.ANSI;
	import sjs.data.StackFrame;
	import sjs.data.Symbol;
	import sjs.data.VmFunc;
  
	//import flash.utils.getDefinitionByName;
	//import flash.utils.getQualifiedClassName;
	//import flash.geom.*;
	//import flash.display.*;
	import flash.events.Event;
	import flash.events.EventDispatcher;
  
	//GB
	//validate these imports
	//registry to map
	//change const
  
	
	/***********************************************************
	*
	*    OPCODE IDs
	*
	***********************************************************/
	
	
	enum OPCode {
		NOP;
		DUP;
		DROP;
		SWAP;
		INDEX;
		LIT;
		VAL;
		ADD;
		SUB;
		MUL;
		DIV;
		MOD;
		NEG;
		EQL;
		GT;
		LT;
		GTE;
		LTE;
		AND;
		OR;
		NOT;
		CLOSURE;
		MARK;
		CLEARTOMARK;
		ARRAY;
		HASH;
		JUMP;
		JUMPFALSE;
		CALL;
		RETURN;
		PUT;
		PUTINDEX;
		GETINDEX;
		GET;
		LOCAL;
		NATIVE_NEW;
		AWAIT;
		PUSH_RESUME_PROMISE;
		//TRACE;
		//HALT;
		//DROPALL;
	}
  
  
	class VM extends EventDispatcher {

		public static var _VM_ID:Int;// (0);
		public static var registry:Map <String,Dynamic>; //; = { 'Math' => Math, 'Date' => Date, 'null' => null }; // TweenLite, etc goes here

		public static function register(key:String, value:Dynamic): Void {
			VM.registry[key] = value;
		}


		public static var MAX_RECURSION_DEPTH : Int = 64;
       
      
		/***********************************************************
		*
		*    EVENTS
		*
		***********************************************************/
		public static var EXECUTION_COMPLETE:String = 'VM.EXECUTION_COMPLETE';
     
         
		/***********************************************************
		*
		*    VM STATE
		*
		***********************************************************/
		public function _vm_id():String { return "" + _VM_ID++; }
		
		
		public var running:Bool;
		public var tracing:Bool = false;
     
		public var call_stack:Array<StackFrame>; // function call stack    
		public var os:Array<Dynamic>;         // operand stack //GB to detect
		public var marks:Array<Dynamic>;      // stack indices for array / hash construction //GB to detect
     
		public var system_dicts:Array<Map<String, Dynamic>>;  // context; e.g. add a movie clip and script "x += 10"
		public var vm_globals:Map<String, Dynamic>;  // global scope, like you're used to in browser JavaScript:
		
        
		/************************************************************
		**
		**        PRIVATE API
		**
		************************************************************/    
		
		
		private function log(args:Array<Dynamic>) : Void {
			if(tracing) {
				_vmTrace(['| ' + args.join(' ')]);
			}
		}

		private function _vmTrace(args:Array<Dynamic>) : Void {
			trace('[VM#'+_vm_id+']', args.join(' '));
		}
    
		private function _vmUserTrace(args:Array<Dynamic>) : Void {
			//_vmTrace(ANSI.cyan(args.join(' ')));
			_vmTrace([args.join(' ')]);
		}
		
		/* GB commnet as I do not understand
		private function _osAsString() : String {//GB getter
			return os.map(function(e:*, ...args:Array<Dynamic>):String { 
			if (e is Function) { return '*fn*'; } return e; 
			}).join(' ');
		}
		*/
    
		private function next_word() : Dynamic {
			return call_stack[0].next_word();
		}
	
		/* GB choose to not use this
		private function current_call():StackFrame {//GB getter
			return call_stack[0]; 
		}*/
    
 
		/***********************************************************
		*
		*   PUBLIC API
		*
		***********************************************************/

		public function new() {
			super();
			
			registry = new Map<String,Dynamic>();//GB
			vm_globals = new Map<String,Dynamic>();//GB
			system_dicts = new Array < Map < String, Dynamic >> ();
			call_stack = new Array<StackFrame>(); // function call stack    
			os = new Array<Dynamic>();    // operand stack //GB to detect
			marks = new Array<Dynamic>();
			
			
			//setGlobal('trace', _vmUserTrace);//GB comment for now
			setGlobal('halt', halt);
		}

		// for hotloading -- define a "clone me" function externally
		// but make it a noop in the clone so you don't get
		// infinite recursion
		/*    public function clone() : VM {
				var ret:VM = new VM;
			ret.load(call_stack[0].code);
			return ret;
		}
		*/
		
		public function setGlobal(k:String, v:Dynamic) : Void {
			vm_globals[k] = v;
		}
		
		public function setGlobals(o:Map<String, Dynamic>) : Void {
			for(k in o) vm_globals[k] = o[k];
		}
		

		public function pushDict(dict:Map<String, Dynamic>) : Void {
			system_dicts.unshift(dict);
		}

		// can say vm.load(one_liner).run() with no trouble
		// prebind the ops for speed?
		public function load(tokens:Array<Dynamic>): VM {
			call_stack = [ new StackFrame(tokens) ];
			return this;
		}
		
		/*GB As load has changed to strict synature of Array(Token) so this interface is close
		public function loadString(code:String): VM {
			load(code.split(' '));
			return this;
		}*/
      
		public function halt() : Void {
			running = false;
		}

		// == run ==
		// some notes:
		// Opcodes can only legally be of type String, although we Interleave other types of data with them.
		// we loop until reaching the end of the last stack frame, or until halted (running = false).
		// we wrap (op) in extra parentheses to quiet Flash's "function where object expected" warning.
		// we stash the callframe at the top of the inner loop in case next_word exhausts the StackFrame, causing it to be popped at the end of the loop

		// have to do checks in loop in case we:
		//    - popped a frame last time through
		//    - exhausted callframe during run loop -- probably if/else jumping to end
		

		//trace('VM.run; call_stack depth:', cs.length, 'pc @', cs[0].pc, '/', cs[0].code.length, '(', cs[0].code.join(' '), ')');
		//trace('... bailing at end of cycle, call_stack depth:', cs.length, 'pc @', cs[0].pc, '/', cs[0].code.length, '(', cs[0].code.join(' '), ')');
		// log('    VM Finished run. os: ', '[' + os.join(', ') + ']', ' dicts: ', Inspector.inspect(system_dicts), 'traces:', Inspector.inspect(dbg_traces), "\n");
		//log(w, ANSI.wrap(ANSI.BLUE, ' ( ' + _osAsString + ' ) '));
			
		
		public function run() : Void {
			var cs:Array<StackFrame> = call_stack;//GB note this!
			var op:Dynamic;//GB was Function
      
			running = true;

			while(cs.length > 0) {
				while (cs.length > 0 && !call_stack[0].exhausted && running) {
					
					//op = this[call_stack[0].next_word()];
					op = call_stack[0].next_word();
					var opFunc:Dynamic = Reflect.field(this, op);
					
					if(opFunc == null) {
						if(call_stack[0].exhausted) continue;
						else throw 'VM got unknown operator ' + call_stack[0].prev_word() + '';
					}
					
					
					Reflect.callMethod(this, opFunc, []);//gb was 'op();'
					
					if(!running)  return; // bail from AWAIT instruction
				}
				cpop();// automatically return at end of function even if no return statement
			}
			
			running = false;
			dispatchEvent(new Event(EXECUTION_COMPLETE));
		}
		
		/* GB ref not found
		public function onComplete(fn:Dynamic) : Void {
			addEventListener(EXECUTION_COMPLETE, function _doOnComplete(Dynamic) : Void {//GB edited signature
				removeEventListener(EXECUTION_COMPLETE, _doOnComplete);
				fn();
			});
		}*/

		
        
        
		/**************************************************
		**
		**              INTERNALS
		**
		***************************************************/
        
		// call_stack manipulation.  We prefer unshift/shift to push/pop because it's convenient that top-of-stack is always stack[0]
		private function cpush(code:Array<Dynamic>,vars:Dynamic) : Void { 
			call_stack.unshift(new StackFrame(code, vars, call_stack[0])); 
		}


		private function cpop() : Void { 
			call_stack.shift(); 
		}


		private function fcall(fn:VmFunc, args:Array<Dynamic>) : Void {
		  if(call_stack.length > VM.MAX_RECURSION_DEPTH) { 
			throw('org.sixsided.scripting.SJS.VM: too much recursion in' + fn.name);
		  }

		  call_stack.unshift(new StackFrame(fn.body,
											conformArgumentListToVmFuncArgumentHash(args, fn),
											fn.parentScope));
		}

		// stack manipulation
		private function opush(op:Dynamic):Void {
			os.unshift(op);
			//log([op, '->', '(', _osAsString, ')']); 
		};
		private function opop():Dynamic {
			//log([os[0], '<-', '(', _osAsString, ')']);
			return os.shift(); 
		};
		private function numpop():Float { return Std.parseFloat(opop()); };
		private function bin_ops():Array<Dynamic> {
			var tp:Array<Dynamic> = new Array<Dynamic>();
			tp.push(opop());
			tp.push(opop());
			tp.reverse();
			return tp;
		};
		
		private function pushmark():Void { marks.unshift(os.length); };
		private function yanktomark():Array<Dynamic> {
			var tp:Array<Dynamic> = os.splice(0, os.length - Std.parseInt(marks.shift()));
			tp.reverse();
			return tp;
		}; // fixme: hack, ditch shift-stacks for push-stacks
		
		// var manipulation


		/*    find_var/set_var
		*  VM has four tiers of variables.
		*  1) the chain of StackFrame vars as defined by lexical scope
		*  2) the VM's globals, vm_globals
		*  3) the system dicts, in the order they were added -- READ ONLY; set_var does not even look at these
		*  4) the VM's static registry, VM.registry
		*  
		*  *** The only writable vars are the current callframe's and the vm globals
		*  *** ... that is, locals and globals for a given VM.  Just like Javascript.
		*  ....... Could add a 'register' function for adding things to the registry.
		*/

		// so running in the root scope, the 'var' keyword indicates a temporary variable tha won't persist after
		// the call_stack is exhausted, i.e. the code runs through to its end and the vm exits.
		// simply setting a variable with x = n, however, will create a persistent global x.
       
		private function frameWithVar(key:String) : StackFrame {
			var sf:StackFrame = call_stack[0];
			var safety:Int = MAX_RECURSION_DEPTH;
			while(sf != null && safety-- > 0) {          
				if(sf.vars.exists(key)) {
					return sf;
				}
				sf = sf.parent;
			}
			return null;                  
		}
      
      
		public function set_var(key:String, value:Dynamic) : Void {
			var sf:StackFrame = frameWithVar(key);
			if(sf != null) {
				sf.vars[key] = value;
				return;
			}
			vm_globals[key] = value;
		}
  
    
		public function findVar(key:String) : Dynamic {      
			var v:Dynamic = _find_var(key);
			return v;// (undefined == v) ? null : v;  // duhh why? //GB was ===
		}
  
  
		private function _find_var(key:String) : Dynamic {
			// locals?
			var sf:StackFrame = frameWithVar(key);
			if(sf != null) {
				return sf.vars[key];
			}
        
			// globals?
			if(vm_globals.exists(key)) {
				return vm_globals[key];        
			}

			// dicts?  (in LIFO order)
			//for (var i:Int = 0; i < system_dicts.length; i++) {//GB
			for (i in 0...system_dicts.length) {
				var g:Map<String, Dynamic> = system_dicts[i];
				if(g.exists(key)) {
					return g[key];
				}
			}
        
			// registry?
			if(VM.registry.exists(key)) {
				return VM.registry[key];
			}
        
			// not defined anywhere!
			return null;//GB to null from undefined
		}



		/***********************************************************
		*
		*    OPCODES
		*
		***********************************************************/
		
        public function callScriptFunction(fnName:String, args:Array<Dynamic> = null) : Void {
			_vmTrace(['callScriptFunction', fnName]);
			var fn:Dynamic = findVar(fnName);
			if(Reflect.isFunction(fn)){
				//fn.apply(null, args);
				Reflect.callMethod(null, fn, args);//GB
			} else if(Std.is(fn, VmFunc)) {
				fcall(fn, args);
				run();
			} else {
				throw "Tried to callScriptFunction on object "  + fn;
			}
        }


        // wrap VM functions in AS3 closures so we can pass them to AS3
        // as event listeners, etc, that will fire up the vm
		/* GB no ref found
		private function wrapVmFunc(fn:VmFunc):Function{
			var vm:VM = this;
			return function(...args):Void {
				vm.fcall(fn, args);
				vm.run(); // if called from within SJS code, recurses into VM::run(); if called from an AS callback, starts up the interpreter
			}
        }*/
        
        
        // fixme: replace for/in with for(i... //GB return was Dynamic
        private function conformArgumentListToVmFuncArgumentHash(func_args:Array<Dynamic>, fn:VmFunc):Map<String,Dynamic> {
			var ret:Map<String,Dynamic> = new Map<String,Dynamic>();
			//for (var i:String in fn.args) {
			for (i in 0...fn.args.length) {
				var k:String = fn.args[i];
				ret[k] = func_args.shift();
			}
			return ret;
        }
		
        private function NOP():Void { }

        //stack manipulation
        private function DUP()   :Void{ var p:Dynamic = opop(); opush(p); opush(p); }
        private function DROP()  :Void{ opop(); }
        private function CLEARTOMARK()  :Void{ yanktomark(); }
        private function SWAP()  :Void{ var a:Dynamic = opop(); var b  : Dynamic = opop(); opush(a); opush(b); }
        private function INDEX() :Void{ var index :Dynamic= opop(); opush(os[index]); }

        //values
        private function LIT():Void{   var v:Dynamic = next_word();  opush(v);  }
        private function VAL():Void{   opush(findVar(next_word())); }

        //arithmetic
        private function ADD():Void{      var o:Array<Dynamic> = bin_ops(); opush(o[0] + o[1]); }
        private function SUB():Void{      var o:Array<Dynamic> = bin_ops(); opush(o[0] - o[1]);}
        private function MUL():Void{      var o:Array<Dynamic> = bin_ops(); opush(o[0] * o[1]); }
        private function DIV():Void{      var o:Array<Dynamic> = bin_ops(); opush(o[0] / o[1]); }
        private function MOD():Void{      var modulus:Float = numpop(); opush(numpop() % modulus); } 
        private function NEG():Void{      opush(-opop()); }

        //relational
        private function EQL():Void{ opush(opop() == opop());                      }
        private function GT() :Void{ var o:Array<Dynamic> = bin_ops(); opush(o[0] > o[1]);  }
        private function LT() :Void{ var o:Array<Dynamic> = bin_ops(); opush(o[0] < o[1]);  }
        private function GTE():Void{ var o:Array<Dynamic> = bin_ops(); opush(o[0] >= o[1]); }
        private function LTE():Void{ var o:Array<Dynamic> = bin_ops(); opush(o[0] <= o[1]); }

        //short-circuit logic operators -- for a() && b(), don't evaluate b() if a is falsy
        // for a() || b(), don't evaluate b if a is truthy
        private function _short_circuit_if(value:Bool):Void {
			var right:Dynamic = opop();
			var left:Dynamic = opop(); 
			if(!!left == value) {
				opush(left);
			}else {
				cpush(right, {}); 
				// Creates a callframe/scope.  
				// "a && v = 3" will set v in global scope if not defined in the enclosing scope.
			}
        }
        
        private function AND():Void{ _short_circuit_if(false); }
        private function OR():Void { _short_circuit_if(true); }
        private function NOT():Void{ opush(!opop()); }


        //structures
        private function MARK():Void {  pushmark(); }
        private function ARRAY():Void { opush(yanktomark()); }
        private function HASH():Void {
			
			//GB note here
			
              var i:Int = 0, dict:Map<String,Dynamic> = new Map<String,Dynamic>(), a:Array<Dynamic> = yanktomark(); 
              //for(i=0; i < a.length; i+=2) {
              while(i < a.length){
				dict[a[i]] = a[i + 1];
				//
				i += 2;//must at end
              }
              opush(dict);
        }
      

        //flow control
        private function JUMP():Void{ 
            call_stack[0].pc += next_word();
        }
        private function JUMPFALSE():Void{ 
            var prevpc:Int = call_stack[0].pc;
            var offset:Int = next_word();
            if(!opop()) {
                call_stack[0].pc += offset;
            }
        }
		
        //functions
        private function CLOSURE():Void{ 
            //var closure:Function;
            //log(Inspector.inspect(os));//GB
            var body:Array<Dynamic> = cast(opop(),Array<Dynamic>);
            var args:Array<Dynamic> = cast(opop(),Array<Dynamic>);
            var name:String = opop();

            // used to wrap vm functions in AS3 functions here

            var vmf:VmFunc = new VmFunc(name, args, body, call_stack[0]);
            set_var(name, vmf);
            opush(vmf);
        }
        

          // TODO -- supply a "this" context for scripted functions?
          // FIXME -- How to distinguish between functions returning nothing and functions
          //          returning undefined? For now, we don't.
          // we allow both wrapped and unwrapped functions because they're both useful:
          //  wrapped functions for passing to AS3 as e.g. event listeners which retain
          //  a reference to this VM in their closures;
          // unwrapped functions so we can run code from another VM in our own context
         private function CALL():Void { // (closure args_array -- return_value 
            var func_args:Dynamic = opop();
            var fn:Dynamic = opop();
            var rslt:Dynamic;
            
            if(Reflect.isFunction(fn)) {
                rslt = Reflect.callMethod(null,fn,func_args);
                if(rslt != null) opush(rslt); //GB was !==
            } else if(Std.is(fn, VmFunc)){
                fcall(fn, func_args);              
            } else {
                trace('* * * * * VM.CALL tried to call nonfunction value "' + fn + '": ' + Type.typeof(fn) + ' * * * * * *');
            }
         }
     
     
         private function RETURN():Void{ 
			log(['return']);
			cpop();
         }


        // getting and setting values        
        private function GET ():Void {
			var key:String = opop();    
			opush(findVar(key));
        }


        // v k PUT
        private function PUT():Void{  // (value key -- value )
			var key:String = opop();
			var value:Dynamic = opop();
			log(['PUT', value, key]);
			set_var(key, value);
			// opush(value);
        }


        private function PUTLOCAL():Void{  // (value key -- value )
			// TODO: figure out scopes in parser/codegen
			//       or just generate PUTLOCAL anywhere you see "var x;" (gets null or undefined) or "var x = value":
			var key:String = opop();
			var value:Dynamic = opop();
			log(['PUTLOCAL', value, key]);
			call_stack[0].vars[key] = value;
          
          // opush(value);
        }


        // value object key PUTINDEX
        private function PUTINDEX():Void{  // ( value object key -- value )
			var key   :Dynamic = opop();
			var object:Dynamic = opop();
			var value :Dynamic = opop();
			object[key] = value;
          // opush(value);
        }


        private function GETINDEX():Void{  // aka "dot"  (o k -- o[k])
            var k:Dynamic = opop();
            var o:Dynamic = opop();
            // trace('GETINDEX', o, k);            
            opush(o[k]);
        }


        // LIT m LOCAL -- declares m as a var in current scope
        private function LOCAL():Void {
          var key:String = opop();    
          call_stack[0].vars[key] = null;
        }


        // NEW   ( constructor [args] -- instance )
        private function NATIVE_NEW():Void {            
            var args:Array<Dynamic> = opop();
            var classname:String = opop();
            var klass:Class<Dynamic> = findVar(classname);//GB may be null
            var instance:Dynamic;
			
			//GB start
			if (klass == null) {
				log(["GB: VM can not resolve class : " + classname]);
				return;
			}
			//GB end
			
			
            log(['++ new ', classname, '(' + args.join(', ') + ')  //', klass + ': ' + Type.getClassName(klass)]);
            
			
			instance = Type.createInstance(klass, args);//GB one place i like haxe
			
			/*
            switch(args.length) {
              case 0: instance = new klass(); break; 
              case 1: instance = new klass(args[0]); break; 
              case 2: instance = new klass(args[0], args[1]); break; 
              case 3: instance = new klass(args[0], args[1], args[2]); break; 
              case 4: instance = new klass(args[0], args[1], args[2], args[3]); break; 
              case 5: instance = new klass(args[0], args[1], args[2], args[3], args[4]); break; 
              case 6: instance = new klass(args[0], args[1], args[2], args[3], args[4], args[5]); break;
              case 7: instance = new klass(args[0], args[1], args[2], args[3], args[4], args[5], args[6]); break;
              case 8: instance = new klass(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]); break;
              case 9: instance = new klass(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]); break;
              default: throw "NATIVE_NEW was given too many arguments: " + args.length;
            }
			*/
            opush(instance);            
        }

		//GB no ref found
		/*
        private function _resumeFromPromise(...promiseFulfillArgs) : Void {
          	trace('_resumeFromPromise', promiseFulfillArgs);
          	// convert all cases to 1-arg.
          	//    0: null
          	//    1: pass through
          	//    N: pass as an array 

          	if(promiseFulfillArgs.length == 0) {
           	 opush(null);
          	} else if(promiseFulfillArgs.length == 1) {
          	  opush(promiseFulfillArgs[0]);
          	} else {
          	  opush(promiseFulfillArgs);
          	}

         	run();
        }*/
        
        private function AWAIT():Void {
          //var p:Promise = opop();
          //halt();
          //p.onFulfill(_resumeFromPromise);
        }
        
    } // VM
 
