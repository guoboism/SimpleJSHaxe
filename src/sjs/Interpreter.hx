/*
Interpreter.as is a neat facade for the Simplified JavaScript classes.
*/
package sjs;

	class Interpreter{

		public var vm:VM;
		public var parser:Parser;  
		
		public function new(bootScript:String='') {
		  vm = new VM();
		  parser = new Parser();
		  if (bootScript != null && bootScript.length > 0) {
			load(bootScript);
			run();
		  }
		}
		
		public function doString(script:String) : Void {
		  load(script);
		  run();
		}

		public function verbose() : Void {
		  parser.tracing = true;
		  vm.tracing = true;
		}
		
		public function load(script:String):Interpreter {
		  parser.parse(script);
		  vm.load(parser.codegen());
		  return this;
		}
		
		public function run():Interpreter {
		  vm.run();
		  return this;
		}
		
		public function pushDict(d:Map<String, Dynamic>):Interpreter {
		  vm.pushDict(d);
		  return this;
		}
		
		public function setGlobal(key:String, value:Dynamic):Interpreter {
		  vm.setGlobal(key, value);// functions, variables, whatever
		  return this;
		}
		
		public function setGlobals(map:Map<String, Dynamic>):Interpreter {
		  vm.setGlobals(map);
		  return this;
		}
		
		
		// TODO: make this work
		// def('->', callback);
		// a -> b; // invokes callback(a, b)
		// e.g.  "EventName -> function(e) { ... };"  or even "EventName -> some statement;"
	/*    public function defineOperator(op:String, cb:Function) : void {
		  parser.defineOperator(op, cb);      
		}
	*/    // vm.set_global('def', defineOperator);
    
  }
