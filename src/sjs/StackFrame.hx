package sjs;
  
/* A function call frame, with its own program counter and local variables.
 Function calls are the only use of callframes in this VM.  (As opposed to org.sixsided.fith, which uses them for 
 loops.)
*/
/*import org.sixsided.scripting.SJS.Inspector;*/

import sjs.VM;

class StackFrame {
	
	public var code:Array<Dynamic>;
	public var pc:Int;
	public var exhausted:Bool;
	public var vars:Map<String, Dynamic>;// GB wasDynamic;

	public var parent:StackFrame;

	public function new(code:Array<Dynamic>, vars:Map<String, Dynamic>=null, parent:StackFrame=null) {
		this.code = code;
		this.pc = 0;
		this.exhausted = false;
		this.vars = vars == null ? new Map<String, Dynamic>() : vars; //GB was  'this.vars = vars || {};'
		this.parent = parent;
	}

	public function next_word():Dynamic{      
		// this check is here because we want to return control to run and let it finish out the current
		// iteration *before* we exhaust the call frame.  The last word might be a JUMP back to the start of the frame.
		if(pc >= this.code.length) {
			/*trace('[StackFrame] next_word exhausted StackFrame @', pc);*/
			this.exhausted = true;  
			return NOP;
		}

		// console.log('StackFrame.next_word', this.pc, this.code[this.pc]);
		return code[pc++];  
	}

	public function prev_word():Dynamic {
	  return code[pc-1];
	}

	public function toString():String{
		return '[StackFrame @' + pc + ']';
		/*var str:String = '';
		for(var k:String in vars) {
			str += k + ' : ' + Inspector.inspect(vars[k]) + "\n";
		}
		return str;*/
	}
}
