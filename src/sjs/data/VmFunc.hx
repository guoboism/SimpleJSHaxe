package sjs.data;
  class VmFunc {
    public var name:String;
    public var body:Array<Dynamic>; // of *
    public var args:Array<Dynamic>; // of string //GB due to VM.hx line 583, has to fall to general Dynamic 
    public var parentScope:StackFrame;
    
    public function new(name:String, args:Array<Dynamic>, body:Array<Dynamic>, parentScope:StackFrame) {
        this.name = name;
        this.body = body;
        this.args = args;
        this.parentScope = parentScope;
    }   
  }
